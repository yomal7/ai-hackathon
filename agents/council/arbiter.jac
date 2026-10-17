# Guardian Arbiter (8): runs the Bank Council on a Request and writes the Ruling (A)
# Order: Coercion Sentinel reading -> PLACE_TIME -> ROUTINE -> MULE_RING -> PATTERN -> ADVOCATE -> rules R1-R6.
# Agents never call each other; each one writes a Proposal on the Request (the graph is the blackboard).
import time;
import from operator { attrgetter }
import from graph.nodes {
    Citizen, Account, Request, Ruling, Signal, Alert, Guardian, Proposal,
    Decision, Assurance, RequestStatus, SignalKind, AlertKind, AlertStatus, Lang
}
import from graph.edges { Owns, Decided, Emitted, Raised }
import from graph.queries {
    demo_state, citizen_of, payee_of, guardian_of, find_alert, add_timeline, now_s
}
import from rules.arbiter_rules { apply_rules }
import from ai.llm_calls { guardian_card }
import from agents.phone.coercion_sentinel { CoercionSentinel }
import from agents.council.place_time { PlaceTimeAgent }
import from agents.council.routine { RoutineAgent }
import from agents.council.mule_ring { MuleRingAgent }
import from agents.council.pattern { PatternAgent }
import from agents.council.advocate { AdvocateAgent }
import from agents.council.scam_breaker { ScamBreakerStart }
import from agents.network.network { RunNetwork }
import from agents.council.council_common {
    ms_since, rs, first_name, largest_usual_payment, proposals_of, proposal_dict, latest_pressure,
    risk_of, ACTION_WORDS
}

glob STATUS_FOR: dict[str, RequestStatus] = {
    "ALLOW": RequestStatus.ALLOWED, "STEP_UP": RequestStatus.STEP_UP, "HOLD": RequestStatus.HELD,
    "ASK_GUARDIAN": RequestStatus.HELD, "ASK_ANALYST": RequestStatus.HELD, "BLOCK": RequestStatus.BLOCKED
};

"""Latest Ruling on a request, or None."""
def ruling_of(req: Request) -> Ruling | None {
    found = sorted([req ->:Decided:->], key=attrgetter("at"));
    return found[-1] if found else None;
}

"""Ruling as a plain dict (the API shape of section 8)."""
def ruling_dict(r: Ruling) -> dict[str, any] {
    return {"decision": str(r.decision), "why": r.why, "rule": r.rule, "assurance": str(r.assurance),
            "ms": r.ms, "deadlock": r.deadlock, "locked": r.locked};
}

"""Write a Ruling on the request and update its status. Returns the Ruling."""
def write_ruling(req: Request, decision: str, why: str, rule: str, ms: int = 0,
                 deadlock: bool = False, locked: bool = False) -> Ruling {
    assurance = "LOW" if decision == "ALLOW" else ("MEDIUM" if decision == "STEP_UP" else "HIGH");
    r = Ruling(decision=Decision(decision), why=why, rule=rule, ms=ms, deadlock=deadlock,
               assurance=Assurance(assurance), locked=locked, at=now_s());
    req +>:Decided:+> r;
    req.status = STATUS_FOR[decision];
    add_timeline("ARBITER", f"{decision} ({rule}{', locked' if locked else ''}{', deadlock' if deadlock else ''}) - {why}");
    return r;
}

"""One English sentence for the guardian card, the Scam-Breaker and the analyst."""
def summary_of(req: Request) -> str {
    c = citizen_of(req);
    payee = payee_of(req);
    who = f"{c.name} ({c.age}, {c.city})" if c is not None else "A customer";
    to = f" to {payee.id} ({payee.owner_name}, opened {payee.opened_days_ago} days ago)" if payee is not None else "";
    return f"{who} is trying a {ACTION_WORDS.get(str(req.action), str(req.action))} of {rs(req.amount)}{to} at {req.time}.";
}

"""The strongest risk reasons from the council (max 3)."""
def evidence_of(req: Request) -> list[str] {
    props = sorted([p for p in proposals_of(req) if risk_of(p) >= 0.5], key=risk_of, reverse=True);
    return [p.reason for p in props][:3];
}

"""Ask the guardian: Alert(kind=GUARDIAN) in the guardian's language, written by B's guardian_card."""
def raise_guardian_alert(req: Request, locked: bool) -> Alert | None {
    c = citizen_of(req);
    g = guardian_of(c) if c is not None else None;
    if c is None or g is None {
        add_timeline("ARBITER", f"No guardian on file for {req.id} - the bank calls the customer");
        return None;
    }
    if [a for a in [req ->:Raised:->] if a.kind == AlertKind.GUARDIAN and a.status == AlertStatus.OPEN] {
        return None;   # already asked
    }
    others = len([x for x in req.walk_path if x.startswith("c_")]) - 1;
    card = guardian_card(summary_of(req), evidence_of(req), str(g.language),
                         {"name": first_name(c), "amount": req.amount, "others": max(others, 0)});
    st = demo_state();
    alert = Alert(
        id=f"AL-{st.next_alert:03d}", kind=AlertKind.GUARDIAN, language=g.language,
        title=str(card.get("title", "")), lines=[str(x) for x in list(card.get("lines", []))][:3],
        options=["REJECT", "CALL"] if locked else [str(x) for x in list(card.get("options", ["REJECT", "APPROVE", "CALL"]))]
    );
    st.next_alert += 1;
    req +>:Raised:+> alert;
    add_timeline("ARBITER", f"Asked guardian {g.name} ({g.relation}, {g.language}) - alert {alert.id}");
    return alert;
}

"""SESSION_REVOKED / other signals from a ruling, about the citizen's own account."""
def emit_signals(req: Request, r: Ruling, kinds: list[str]) {
    c = citizen_of(req);
    payee = payee_of(req);
    mine = [a for a in [c ->:Owns:->] if not a.is_fd] if c is not None else [];
    subject = mine[0] if mine else None;
    for kind in kinds {
        sig = Signal(
            kind=SignalKind(kind), subject_account=subject.id if subject is not None else "",
            from_bank=subject.bank if subject is not None else "",
            to_bank=payee.bank if payee is not None else "", time=req.time
        );
        r +>:Emitted:+> sig;
        add_timeline("ARBITER", f"{kind} for {sig.subject_account} ({sig.from_bank})");
    }
}

"""The Guardian Arbiter. Spawn on a Request. Reports the ruling dict."""
walker RunCouncil {
    has ruling: dict[str, any] = {};

    can run with Request entry {
        t0 = time.perf_counter();
        st = demo_state();
        c = citizen_of(here);
        payee = payee_of(here);
        here.status = RequestStatus.CHECKING;
        st.checked += 1;
        st.current_request = here.id;
        add_timeline("ARBITER", f"Bank Council meets on {here.id}: {summary_of(here)}");

        # Layer 1 reading, then the 5 specialists - each writes its own Proposal
        here spawn CoercionSentinel();
        here spawn PlaceTimeAgent();
        here spawn RoutineAgent();
        here spawn MuleRingAgent();
        here spawn PatternAgent();
        here spawn AdvocateAgent();

        # Plain-code rules decide
        pr = latest_pressure(here);
        pressure = pr.value if pr is not None else 0;
        facts = {
            "request_id": here.id, "amount": here.amount, "pressure": pressure,
            "largest_usual": largest_usual_payment(c) if c is not None else 0,
            "payee_id": payee.id if payee is not None else "",
            "payee_confirmed_mule": payee.confirmed_mule if payee is not None else False,
            "payee_frozen": payee.frozen if payee is not None else False
        };
        out = apply_rules([proposal_dict(p) for p in proposals_of(here)], facts);
        decision = str(out["decision"]);
        r = write_ruling(here, decision, str(out["why"]), str(out["rule"]), ms_since(t0),
                         bool(out["deadlock"]), bool(out["locked"]));
        emit_signals(here, r, [str(k) for k in list(out["emit"])]);

        if decision == "BLOCK" {
            st.blocked += 1;
        } elif decision in ["HOLD", "ASK_GUARDIAN"] {
            st.held += 1;
            # Detection time for this victim: first warning sign -> HOLD
            if here.first_signal_at > 0.0 and c is not None {
                secs = int((now_s() - here.first_signal_at) * 10 + 0.5) / 10.0;
                if not [d for d in st.detect_times if d.get("name") == first_name(c)] {
                    st.detect_times = st.detect_times + [{"name": first_name(c), "seconds": secs}];
                }
            }
        }
        if decision == "HOLD" and pressure >= 70 {
            here spawn ScamBreakerStart(situation=summary_of(here));
        }
        if bool(out["ask_guardian"]) or decision == "ASK_GUARDIAN" {
            raise_guardian_alert(here, bool(out["locked"]));
        }
        r.ms = ms_since(t0);
        self.ruling = ruling_dict(r);
        report self.ruling;
    }
}

"""Apply the guardian's answer (REJECT | APPROVE | CALL) to a GUARDIAN alert. Plain code, never LLM."""
walker ApplyGuardianAnswer {
    has alert_id: str = "";
    has answer: str = "";
    has ok: bool = False;

    can apply with Root entry {
        alert = find_alert(self.alert_id);
        answer = self.answer.upper();
        if alert is None or alert.kind != AlertKind.GUARDIAN or answer not in ["REJECT", "APPROVE", "CALL"] {
            report {"ok": False};
            disengage;
        }
        reqs = [n for n in [alert <-:Raised:<-] if isinstance(n, Request)];
        if not reqs {
            report {"ok": False};
            disengage;
        }
        req = reqs[0];
        st = demo_state();
        alert.answer = answer;
        alert.status = AlertStatus.ANSWERED;
        st.human_needed += 1;
        c = citizen_of(req);
        g = guardian_of(c) if c is not None else None;
        who = g.name if g is not None else "Guardian";
        last = ruling_of(req);
        payee = payee_of(req);

        if answer == "REJECT" {
            # A guardian Reject ALWAYS stops the transfer
            write_ruling(req, "BLOCK", f"{who} rejected the transfer - confirmed scam", "GUARDIAN");
            req.confirmed_scam = True;
            if payee is not None {
                payee.confirmed_mule = True;
            }
            st.blocked += 1;
            st.protected_rs += req.amount;
            add_timeline("ARBITER", f"{rs(req.amount)} protected for {first_name(c)}. Fraud Network starts.");
            req spawn RunNetwork();
        } elif answer == "APPROVE" {
            r1 = payee is not None and (payee.confirmed_mule or payee.frozen);
            locked = last is not None and last.locked;
            if r1 or locked {
                add_timeline("ARBITER", f"{who} approved, but the HOLD is locked ({'R1' if r1 else 'mule ring / pattern'}) - it stays held");
            } else {
                write_ruling(req, "ALLOW", f"{who} approved - the money goes through", "GUARDIAN");
            }
        } else {
            add_timeline("GUARDIAN", f"{who} is calling {first_name(c)} - the transfer stays held");
        }
        self.ok = True;
        report {"ok": True};
    }
}
