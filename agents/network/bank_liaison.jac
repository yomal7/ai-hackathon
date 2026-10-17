"""Bank Liaison (agent 11, one per bank, owner: Person B).
For each FREEZE_REQUEST sent to its bank, it decides FREEZE / WATCH / IGNORE with its OWN
advocate check, then the plain-code network rules raise an analyst Alert. It never freezes."""

import from graph.nodes { Account, Signal, Alert, Proposal }
import from graph.edges { Emitted, Raised, HasProposal }
import from ai.llm_calls { analyst_card }
import from ai.lang { fmt_rs }
import from ai.fallback { round2 }
import from rules.network_rules { advocate_objection, network_verdict }
import from agents.network.net_common { all_signals, add_line, held_amount, held_victim }
import from agents.network.money_tracer { paid_in }

glob BANK_NAMES: dict[str, str] = {"LDB": "Lanka Demo Bank", "CDB": "Ceylon Demo Bank", "IDB": "Island Demo Bank"};

def account_of(sig: Signal) -> Account | None {
    found = [n for n in [sig <-:Emitted:<-] if isinstance(n, Account)];
    return found[0] if found else None;
}

def tracer_proposal(acc: Account) -> Proposal | None {
    found = [p for p in [acc ->:HasProposal:->] if isinstance(p, Proposal) and p.agent == "MONEY_TRACER"];
    return found[0] if found else None;
}

def _has_alert(sig: Signal) -> bool {
    return len([a for a in [sig ->:Raised:->] if isinstance(a, Alert)]) > 0;
}

walker BankLiaison {
    has bank: str;                       # LDB | CDB | IDB
    has decided: list[dict] = [];        # result, for the caller

    can review with Root entry {
        for sig in all_signals() {
            if sig.kind == "FREEZE_REQUEST" and sig.to_bank == self.bank and sig.status == "OPEN" and not _has_alert(sig) {
                self._review(sig);
            }
        }
    }

    def _review(sig: Signal) -> None {
        agent = "LIAISON_" + self.bank;
        acc = account_of(sig);
        if acc is None { return; }
        if acc.frozen {                  # IGNORE: nothing left to do
            sig.status = "DONE";
            add_line(agent, f"{acc.id} is already frozen — ignore.");
            self.decided.append({"account": acc.id, "decision": "IGNORE"});
            return;
        }
        tp = tracer_proposal(acc);
        score = tp.confidence if tp else 0.0;
        ins = paid_in(acc);
        objection = advocate_objection(acc.opened_days_ago, acc.kind, len(set([f.acc.id for f in ins])), len(ins));
        verdict = network_verdict(score, objection);
        held = held_amount(acc);
        victim = held_victim(acc);
        name = f"{acc.id} ({acc.owner_name})" if acc.owner_name else acc.id;
        bank_name = BANK_NAMES.get(self.bank, self.bank);
        tracer_side = tp.reason if tp else f"Money Tracer: mule score {score}.";
        advocate_side = f"{self.bank} Advocate: account is {acc.opened_days_ago} days old, {acc.kind}, {len(ins)} payments from {len(set([f.acc.id for f in ins]))} different people — steady normal business (objection {objection}).";

        if verdict == "ASK_ANALYST" {
            stance = "FREEZE";
            conf = score;
            reason = f"{bank_name} agrees to freeze {name}: mule score {score}, no objection from our advocate.";
            sig.status = "AGREED";
            card = analyst_card(f"Freeze {name} at {bank_name}?",
                                [tracer_side, f"{bank_name} Liaison agrees: FREEZE.", "Cross-bank freeze needs your approval."]);
            self._alert(sig, str(card["title"]), list(card["lines"]), list(card["options"]));
        } elif verdict == "DEADLOCK" {
            stance = "WATCH";
            conf = objection;
            reason = f"{bank_name} Advocate objects to freezing {name}: old account with steady sales from many customers.";
            card = analyst_card(f"DEADLOCK: freeze {name} at {bank_name}?", [tracer_side, advocate_side]);
            title = str(card["title"]);
            if "DEADLOCK" not in title.upper() { title = "DEADLOCK: " + title; }
            self._alert(sig, title, ["FOR freeze — " + tracer_side, "AGAINST — " + advocate_side,
                        "Agents disagree. Your call: approve freeze or keep open."], list(card["options"]));
        } else {
            stance = "WATCH";
            conf = 1.0 - score;
            reason = f"{bank_name} will watch {name}: mule score {score} is below 0.8.";
        }
        acc +>:HasProposal():+> Proposal(agent=agent, scope="NETWORK", stance=stance, confidence=round2(conf),
                                         reason=reason, ms=0, source="code");
        owner = f" of {victim}'s money" if victim else "";
        money = f" Rs {fmt_rs(held)}{owner} is still there." if held > 0 else "";
        add_line(agent, reason + money + (" -> DEADLOCK, analyst decides." if verdict == "DEADLOCK" else ""));
        self.decided.append({"account": acc.id, "decision": verdict, "score": score, "objection": objection});
    }

    def _alert(sig: Signal, title: str, lines: list[str], options: list) -> None {
        sig +>:Raised():+> Alert(id="AL-" + sig.subject_account, kind="ANALYST", language="en", title=title,
                                 lines=lines[:3], options=options, status="OPEN", answer="");
    }
}
