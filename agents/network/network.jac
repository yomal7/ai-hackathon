"""Fraud Network (layer 3, owner: Person B).
RunNetwork (spawned by A on a confirmed scam): Pattern Learner -> Money Tracer -> Bank Liaisons.
ApplyAnalystAnswer (spawned by C's analyst_answer API): the ONLY place an account is frozen,
and only after a human analyst says APPROVE."""

import from graph.nodes { Request, Account, Signal, Alert }
import from graph.edges { PaysTo, Emitted, Raised }
import from ai.lang { fmt_rs }
import from rules.network_rules { may_freeze }
import from agents.network.net_common {
    all_signals, all_patterns, find_alert, add_line, reset_network, held_amount, held_victim, TIMELINE, WALK, HELD, TOTALS
}
import from agents.network.pattern_learner { PatternLearner }
import from agents.network.money_tracer { MoneyTracer }
import from agents.network.bank_liaison { BankLiaison, account_of }

glob BANKS: list[str] = ["LDB", "CDB", "IDB"];

walker RunNetwork {
    can run with Request entry {
        add_line("NETWORK", f"Scam confirmed on {here.id}. Fraud Network starts: learn -> trace -> liaise.");
        here spawn PatternLearner();
        payees = [n for n in [here ->:PaysTo:->] if isinstance(n, Account)];
        if payees {
            payees[0] spawn MoneyTracer();
        } else {
            add_line("MONEY_TRACER", f"{here.id} has no payee account — nothing to trace.");
        }
        for b in BANKS {
            root spawn BankLiaison(bank=b);
        }
        open_alerts = [a for a in analyst_alerts() if a["status"] == "OPEN"];
        add_line("NETWORK", f"{len(open_alerts)} freeze request(s) wait for the human analyst.");
    }
}

walker ApplyAnalystAnswer {
    has alert_id: str;
    has answer: str;                     # APPROVE | KEEP_OPEN
    has ok: bool = False;

    can apply with Root entry {
        alert = find_alert(self.alert_id);
        if alert is None or alert.kind != "ANALYST" or alert.status == "ANSWERED" { report {"ok": False}; disengage; }
        sigs = [s for s in [alert <-:Raised:<-] if isinstance(s, Signal)];
        acc = account_of(sigs[0]) if sigs else None;
        alert.status = "ANSWERED";
        alert.answer = self.answer;
        if sigs and acc is not None {
            if may_freeze(self.answer) {
                acc.frozen = True;
                sigs[0].status = "DONE";
                held = held_amount(acc);
                victim = held_victim(acc);
                TOTALS["recovered_rs"] = TOTALS["recovered_rs"] + held;
                add_line("ANALYST", f"Analyst approved: {acc.id} frozen before cash-out. Rs {fmt_rs(held)} recovered" + (f" for {victim}." if victim else "."));
            } else {
                sigs[0].status = "OBJECTED";
                add_line("ANALYST", f"Analyst kept {acc.id} open — we don't freeze innocent shops.");
            }
        }
        self.ok = True;
        report {"ok": True};
    }
}

# ---------- state for the War Room ----------

def analyst_alerts() -> list[dict] {
    out: list[dict] = [];
    for s in all_signals() {
        for a in [s ->:Raised:->] {
            if isinstance(a, Alert) and a.kind == "ANALYST" {
                out.append({"id": a.id, "kind": a.kind, "language": a.language, "title": a.title, "lines": list(a.lines),
                            "options": list(a.options), "status": a.status, "answer": a.answer});
            }
        }
    }
    return out;
}

"""For A's war_room_data(): signals, analyst alerts, money-trace walk, recovered Rs, timeline, patterns."""
def network_state() -> dict {
    return {
        "signals": [{"kind": s.kind, "account": s.subject_account, "from_bank": s.from_bank, "to_bank": s.to_bank,
                     "status": s.status} for s in all_signals()],
        "alerts": analyst_alerts(),
        "walk": {"kind": WALK["kind"], "path": list(WALK["path"]), "step": WALK["step"], "hops": list(WALK["hops"])} if WALK else None,
        "recovered_rs": TOTALS["recovered_rs"],
        "held": dict(HELD),
        "timeline": list(TIMELINE),
        "patterns": [{"name": p.name, "phrases": len(p.phrases), "learned_from": p.learned_from} for p in all_patterns()]
    };
}
