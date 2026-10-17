# Screen data for C's API: war_room_data / phone_data / guardian_data / story_data (A)
# Return SHAPES are fixed by section 8. C's API just returns these dicts.
# Signals, alerts and counters are read from the graph, so A's and B's nodes both show up once.
import from graph.nodes {
    RNode, Bank, Citizen, Account, Request, Signal, Alert, Guardian, PressureReading, Proposal,
    AccountKind, RequestStatus, AlertKind, AlertStatus
}
import from graph.edges { Owns, Paid, Uses, Usually, Made, Raised, ProtectedBy }
import from graph.queries {
    demo_state, all_nodes, all_banks, all_citizens, all_accounts, find_request,
    find_guardian, citizen_of, payee_of, device_of, place_of
}
import from agents.council.council_common { proposals_of, proposal_dict, latest_pressure, first_name, rs, ACTION_WORDS }
import from agents.council.arbiter { ruling_of, ruling_dict }
import from agents.council.scam_breaker { scam_breaker_state, people_saw }
import from agents.network.network { network_state }
import from ai.llm_calls { debrief }
import from seed.money { BANK_COLUMN_X, account_positions }
import from operator { attrgetter }

# Sort keys as named functions (Jac 0.34 cannot run block lambdas inside a def).
def _agent_rank(p: Proposal) -> int {
    return AGENT_ORDER.index(str(p.agent)) if str(p.agent) in AGENT_ORDER else 99;
}

def _time_of(t: dict) -> str {
    return str(t.get("time", ""));
}

def _id_of(d: dict) -> str {
    return str(d["id"]);
}

# Agent order on the War Room cards.
glob AGENT_ORDER: list[str] = [
    "COERCION", "PLACE_TIME", "ROUTINE", "MULE_RING", "PATTERN", "ADVOCATE", "SCAM_BREAKER",
    "LIAISON_LDB", "LIAISON_CDB", "LIAISON_IDB", "MONEY_TRACER"
];

# Phone screen per request status. C maps screen + message keys to text with t(key, lang).
glob PHONE_SCREEN: dict[str, str] = {
    "DRAFT": "FORM", "CHECKING": "CHECKING", "ALLOWED": "DONE", "STEP_UP": "STEP_UP",
    "HELD": "HELD", "BLOCKED": "BLOCKED"
};

# ---------- small helpers ----------

"""The request the demo is showing now, or None."""
def current_request() -> Request | None {
    rid = demo_state().current_request;
    return find_request(rid) if rid else None;
}

"""Every Signal node on the graph."""
def all_signals() -> list[Signal] {
    return [n for n in all_nodes() if isinstance(n, Signal)];
}

"""Every Alert node, oldest first."""
def alerts_in(nodes: list[RNode]) -> list[Alert] {
    return sorted([n for n in nodes if isinstance(n, Alert)], key=attrgetter("id"));
}

def alert_dict(a: Alert) -> dict[str, any] {
    return {"id": a.id, "kind": str(a.kind), "language": str(a.language), "title": a.title,
            "lines": list(a.lines), "options": list(a.options), "status": str(a.status), "answer": a.answer};
}

def signal_dict(s: Signal) -> dict[str, any] {
    return {"kind": str(s.kind), "account": s.subject_account, "from_bank": s.from_bank,
            "to_bank": s.to_bank, "status": str(s.status)};
}

"""Citizens whose scam was stopped (a confirmed-scam request that ended BLOCKED)."""
def protected_citizens() -> list[str] {
    ids: list[str] = [];
    for c in all_citizens() {
        if [r for r in [c ->:Made:->] if r.confirmed_scam and r.status == RequestStatus.BLOCKED] {
            ids.append(c.id);
        }
    }
    return ids;
}

"""Colour state of an account: frozen > mule > blocked > suspect > safe > active > normal."""
def account_state(a: Account, req: Request | None, blocked_payees: list[str], safe_people: list[str]) -> str {
    if a.frozen {
        return "frozen";
    }
    if a.confirmed_mule {
        return "mule";
    }
    if a.id in blocked_payees {
        return "blocked";
    }
    if a.kind == AccountKind.MULE_SUSPECT or a.kind == AccountKind.ATM_CASHOUT {
        return "suspect";
    }
    owners = [a <-:Owns:<-];
    if owners and owners[0].id in safe_people {
        return "safe";
    }
    if req is not None {
        payee = payee_of(req);
        c = citizen_of(req);
        if (payee is not None and payee.id == a.id) or (c is not None and owners and owners[0].id == c.id) {
            return "active";
        }
    }
    return "normal";
}

"""Colour state of a request's PaysTo line, from its status."""
def request_line_state(req: Request) -> str {
    st = str(req.status);
    if st == "BLOCKED" {
        return "blocked";
    }
    if st in ["HELD", "STEP_UP"] {
        return "suspect";
    }
    if st == "ALLOWED" {
        return "safe";
    }
    return "active";
}

# ---------- War Room ----------

"""Nodes + edges for the War Room canvas (about 1000 x 600)."""
def graph_data(req: Request | None) -> dict[str, any] {
    nodes: list[dict[str, any]] = [];
    edges: list[dict[str, any]] = [];
    me = citizen_of(req) if req is not None else None;
    safe_people = protected_citizens();
    blocked_payees: list[str] = [];
    for c in all_citizens() {
        for r in [c ->:Made:->] {
            p = payee_of(r);
            if p is not None and r.status == RequestStatus.BLOCKED {
                blocked_payees.append(p.id);
            }
        }
    }
    for b in all_banks() {
        nodes.append({"id": f"bank_{b.short}", "type": "Bank", "label": b.name,
                      "x": BANK_COLUMN_X.get(b.short, 500), "y": 15, "state": "normal"});
    }
    for c in all_citizens() {
        state = "safe" if c.id in safe_people else ("active" if me is not None and c.id == me.id else "normal");
        nodes.append({"id": c.id, "type": "Citizen", "label": first_name(c), "x": c.x, "y": c.y, "state": state});
        for a in [c ->:Owns:->] {
            edges.append({"from": c.id, "to": a.id, "type": "Owns", "label": "", "state": "normal"});
        }
    }
    pos = account_positions(all_banks());     # used when an account's saved x / y is missing (0, 0)
    for a in all_accounts() {
        label = a.owner_name if a.kind != AccountKind.PERSONAL else a.id;
        xy = [a.x, a.y] if (a.x or a.y) else pos.get(a.id, [0, 0]);
        nodes.append({"id": a.id, "type": "Account", "label": label, "x": xy[0], "y": xy[1],
                      "state": account_state(a, req, blocked_payees, safe_people)});
        seen: list[str] = [];
        for b in [a ->:Paid:->] {
            if b.id in seen {
                continue;
            }
            seen.append(b.id);
            hot = a.kind == AccountKind.MULE_SUSPECT or b.kind in [AccountKind.MULE_SUSPECT, AccountKind.ATM_CASHOUT] or a.confirmed_mule or b.confirmed_mule;
            for e in [edge a ->:Paid:-> b] {
                edges.append({"from": a.id, "to": b.id, "type": "Paid",
                              "label": f"{rs(e.amount)} · {e.time}" + ("" if e.days_ago == 0 else f" · {e.days_ago}d ago"),
                              "state": "suspect" if hot else "normal"});
            }
        }
    }
    if req is not None and me is not None {
        payee = payee_of(req);
        if payee is not None {
            edges.append({"from": me.id, "to": payee.id, "type": "PaysTo", "label": rs(req.amount),
                          "state": request_line_state(req)});
        }
    }
    return {"nodes": nodes, "edges": edges};
}

def request_dict(req: Request) -> dict[str, any] {
    c = citizen_of(req);
    payee = payee_of(req);
    return {"id": req.id, "citizen": c.name if c is not None else "", "language": str(c.language) if c is not None else str(req.language),
            "action": str(req.action), "amount": req.amount, "payee": payee.id if payee is not None else "",
            "status": str(req.status)};
}

"""What a password + OTP + device + place system would say about this request."""
def normal_security_for(req: Request | None) -> dict[str, any] {
    device_ok = True;
    place_ok = True;
    if req is not None {
        c = citizen_of(req);
        dev = device_of(req);
        place = place_of(req);
        device_ok = c is not None and dev is not None and dev.trusted and dev in [c ->:Uses:->];
        place_ok = c is not None and place is not None and place in [c ->:Usually:->];
    }
    return {"password": True, "otp": True, "device": device_ok, "place": place_ok,
            "verdict": "ALLOW" if device_ok and place_ok else "STEP_UP"};
}

"""Mule Ring walk of the current request, unless B's Money Tracer is walking."""
def walk_for(req: Request | None, net: dict) -> dict[str, any] | None {
    if net.get("walk") {
        return dict(net["walk"]);
    }
    if req is not None and req.walk_path {
        return {"kind": "MULE_RING", "path": list(req.walk_path), "step": len(req.walk_path) - 1};
    }
    return None;
}

"""Detection time per victim (seconds None = missed)."""
def detect_times() -> list[dict[str, any]] {
    return [{"name": d.get("name", ""), "seconds": d.get("seconds")} for d in demo_state().detect_times];
}

"""Everything the War Room shows (section 8 shape)."""
def war_room_data() -> dict[str, any] {
    st = demo_state();
    req = current_request();
    net = network_state();
    everything = all_nodes();      # one walk over the graph for alerts + signals
    alerts = alerts_in(everything);
    proposals: list[dict[str, any]] = [];
    ruling: dict[str, any] | None = None;
    pressure: dict[str, any] = {"value": 0, "reasons": []};
    saw: list[dict] = [];
    if req is not None {
        props = sorted(proposals_of(req), key=_agent_rank);
        proposals = [proposal_dict(p) for p in props];
        r = ruling_of(req);
        ruling = ruling_dict(r) if r is not None else None;
        pr = latest_pressure(req);
        if pr is not None {
            pressure = {"value": pr.value, "reasons": list(pr.top_reasons)};
        }
        saw = people_saw(req.id);
    }
    timeline = sorted(list(st.timeline) + list(net.get("timeline", []) or []), key=_time_of);
    return {
        "graph": graph_data(req),
        "request": request_dict(req) if req is not None else None,
        "proposals": proposals,
        "ruling": ruling,
        "pressure": pressure,
        "walk": walk_for(req, net),
        "signals": [signal_dict(s) for s in everything if isinstance(s, Signal)],
        "alerts": [alert_dict(a) for a in alerts],
        "people_saw": saw,
        "counters": {
            "checked": st.checked, "blocked": st.blocked, "held": st.held,
            "protected_rs": st.protected_rs,
            "recovered_rs": st.recovered_rs + int(net.get("recovered_rs", 0) or 0),
            "human_needed": len([a for a in alerts if a.status == AlertStatus.ANSWERED]),
            "detect_times": detect_times()
        },
        "normal_security": normal_security_for(req),
        "timeline": timeline[-80:]
    };
}

# ---------- Phone ----------

"""i18n key of the one-line message on the elder's phone (C turns it into text with t())."""
def phone_message(req: Request, sb_active: bool) -> str {
    st = str(req.status);
    if st == "HELD" {
        return "phone.msg.scam_breaker" if sb_active else "phone.msg.held";
    }
    if st == "BLOCKED" {
        return "phone.msg.blocked_protected" if req.confirmed_scam else "phone.msg.blocked";
    }
    if st == "STEP_UP" {
        return "phone.msg.step_up";
    }
    if st == "ALLOWED" {
        return "phone.msg.done";
    }
    return "";
}

"""What the elder's phone shows for one request. screen: FORM | CHECKING | DONE | STEP_UP | HELD | BLOCKED.
message: an i18n key for t() ("" = none)."""
def phone_data(request_id: str) -> dict[str, any] {
    req = find_request(request_id);
    if req is None {
        return {"language": "en", "screen": "FORM", "pressure": 0, "balance": 0, "fd": 0,
                "scam_breaker": scam_breaker_state(request_id), "message": ""};
    }
    c = citizen_of(req);
    mine = [c ->:Owns:->] if c is not None else [];
    pr = latest_pressure(req);
    sb = scam_breaker_state(req.id);
    return {
        "language": str(c.language) if c is not None else str(req.language),
        "screen": PHONE_SCREEN.get(str(req.status), "FORM"),
        "pressure": pr.value if pr is not None else 0,
        "balance": sum([a.balance for a in mine if not a.is_fd]),
        "fd": sum([a.balance for a in mine if a.is_fd]),
        "scam_breaker": sb,
        "message": phone_message(req, bool(sb.get("active", False)))
    };
}

# ---------- Guardian ----------

"""What the guardian's phone shows: their GUARDIAN alerts, newest first."""
def guardian_data(guardian_id: str) -> dict[str, any] {
    g = find_guardian(guardian_id);
    if g is None {
        return {"language": "en", "name": "", "alerts": []};
    }
    wards = [c for c in all_citizens() if g in [c ->:ProtectedBy:->]];
    alerts: list[dict[str, any]] = [];
    for c in wards {
        for r in [c ->:Made:->] {
            for a in [r ->:Raised:->] {
                if a.kind == AlertKind.GUARDIAN {
                    d = alert_dict(a);
                    d["request_id"] = r.id;
                    d["elder"] = first_name(c);
                    alerts.append(d);
                }
            }
        }
    }
    alerts = sorted(alerts, key=_id_of, reverse=True);
    return {"language": str(g.language), "name": g.name, "alerts": alerts};
}

# ---------- Story ----------

"""The story screen: B's debrief of the current case in the elder's language + the timeline."""
def story_data() -> dict[str, any] {
    req = current_request();
    st = demo_state();
    if req is None {
        return {"language": "en", "debrief": "", "timeline": list(st.timeline)};
    }
    c = citizen_of(req);
    lang = str(c.language) if c is not None else "en";
    r = ruling_of(req);
    payee = payee_of(req);
    case_info = {
        "request_id": req.id, "name": first_name(c), "amount": req.amount,
        "action": ACTION_WORDS.get(str(req.action), str(req.action)),
        "payee": payee.id if payee is not None else "", "decision": str(r.decision) if r is not None else "",
        "why": r.why if r is not None else "", "confirmed_scam": req.confirmed_scam
    };
    return {"language": lang, "debrief": debrief(case_info, lang), "timeline": list(st.timeline)};
}
