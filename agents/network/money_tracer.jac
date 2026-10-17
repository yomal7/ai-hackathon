"""Money Tracer (agent 10, owner: Person B).
Starts at the confirmed mule account and follows Paid edges FORWARD in time, hop by hop.
Each hop: ONE jev_mule_scores call for the next accounts, plus the traced-money rule.
Finds where victims' money still sits (before ATM cash-out) and asks the owning bank to freeze it.
It never freezes anything itself."""

import from graph.nodes { Account, Signal, Proposal, AgentName, Scope, Stance, SignalKind, SignalStatus }
import from graph.edges { Paid, HasProposal, Emitted }
import from ai.jev { jev_mule_scores, jev_last }
import from ai.lang { fmt_rs }
import from rules.network_rules { traced_score, mule_score, FREEZE_MIN_SCORE }
import from agents.network.net_common { bank_short, to_minutes, add_line, WALK, HELD, now_hms }
import from ai.fallback { to_float, round2 }

glob STOP_KINDS: list[str] = ["SHOP", "BILLER", "HOSPITAL", "ATM_CASHOUT"];   # money is spent / cashed here
glob MAX_HOPS: int = 4;

"""One money movement along a Paid edge."""
obj Flow {
    has acc: Account;          # the other end
    has amount: float;
    has time: str;
    has minute: int | None;
}

def _flow(acc: Account, e: Paid) -> Flow {
    return Flow(acc=acc, amount=float(e.amount), time=str(e.time), minute=to_minutes(e.time));
}

def _sort_key(f: Flow) -> int {
    return f.minute if f.minute is not None else 0;
}

"""Money that left acc, oldest first."""
def paid_out(acc: Account) -> list[Flow] {
    out: list[Flow] = [];
    for n in [acc ->:Paid:->] {
        for e in [edge acc ->:Paid:-> n] { out.append(_flow(n, e)); }
    }
    return sorted(out, key=_sort_key);
}

"""Money that came into acc (acc field = the sender)."""
def paid_in(acc: Account) -> list[Flow] {
    out: list[Flow] = [];
    for n in [acc <-:Paid:<-] {
        for e in [edge n ->:Paid:-> acc] { out.append(_flow(n, e)); }
    }
    return out;
}

def _after(f: Flow, minute: int | None) -> bool {
    return minute is None or f.minute is None or f.minute >= minute;
}

"""Facts Jev needs about one account the money reached at `arrived` (minutes)."""
def account_facts(acc: Account, amount: float, arrived: int | None) -> dict {
    ins = paid_in(acc);
    later = [f for f in paid_out(acc) if _after(f, arrived)];
    moved: int | None = None;
    if later and arrived is not None and later[0].minute is not None {
        moved = later[0].minute - arrived;
    }
    return {
        "id": acc.id, "kind": acc.kind, "owner_name": acc.owner_name, "opened_days_ago": acc.opened_days_ago,
        "inflow_count": len(ins), "distinct_senders": len(set([f.acc.id for f in ins])),
        "minutes_to_move_on": moved, "from_flagged": True, "amount_received": amount,
        "moved_on_rs": sum([f.amount for f in later])
    };
}

walker MoneyTracer {
    has path: list[str] = [];
    has hops: list[dict] = [];
    has arrived: dict[str, int] = {};          # account id -> minute the traced money arrived
    has victim_of: dict[str, str] = {};        # account id -> victim whose money it holds
    has depth: dict[str, int] = {};
    has from_bank: str = "";

    can trace with Account entry {
        if not self.path {                     # the confirmed mule: where the trace starts
            self._start(here);
        }
        if self.depth.get(here.id, 0) >= MAX_HOPS { skip; }
        nexts = [f for f in paid_out(here) if f.acc.id not in self.path and _after(f, self.arrived.get(here.id))];
        if not nexts { skip; }
        facts = [account_facts(f.acc, f.amount, f.minute) for f in nexts];
        scores = jev_mule_scores(facts);       # ONE Jev call for this hop
        to_visit: list[Account] = [];
        for (i, f) in enumerate(nexts) {
            self._hop(here, f, facts[i], to_float(scores.get(f.acc.id, 0.0)));
            if f.acc.kind not in STOP_KINDS { to_visit.append(f.acc); }
        }
        visit to_visit;
    }

    def _start(mule: Account) -> None {
        self.path.append(mule.id);
        self.depth[mule.id] = 0;
        self.from_bank = bank_short(mule);
        ins = paid_in(mule);
        times = [f.minute for f in ins if f.minute is not None];
        if times { self.arrived[mule.id] = min(times); }
        for f in ins { self.victim_of[mule.id + ":" + fmt_rs(f.amount)] = f.acc.owner_name; }
        _signal(mule, "ACCOUNT_FLAGGED", self.from_bank);
        add_line("MONEY_TRACER", f"Start at confirmed mule {mule.id}: {len(ins)} victim payments came in.");
        WALK.clear();
        WALK.update({"kind": "MONEY_TRACE", "path": self.path, "step": 0, "hops": self.hops});
    }

    def _hop(src: Account, mv: Flow, f: dict, jev_score: float) -> None {
        acc = mv.acc;
        amount = mv.amount;
        at = mv.time;
        self.path.append(acc.id);
        self.depth[acc.id] = self.depth.get(src.id, 0) + 1;
        if mv.minute is not None { self.arrived[acc.id] = mv.minute; }
        victim = self.victim_of.get(src.id + ":" + fmt_rs(amount), self.victim_of.get(src.id, ""));
        self.victim_of[acc.id] = victim;
        moved = f["minutes_to_move_on"];
        traced = traced_score(acc.opened_days_ago, int(moved) if moved is not None else None, acc.kind);
        score = round2(mule_score(jev_score, traced));
        held = 0.0 if acc.kind == "ATM_CASHOUT" else max(0.0, min(float(acc.balance), amount - to_float(f["moved_on_rs"])));
        HELD[acc.id] = {"amount": held, "victim": victim};
        who = f" ({victim})" if victim else "";
        if acc.kind == "ATM_CASHOUT" {
            where = "already cashed out at an ATM";
        } elif held > 0 {
            where = f"Rs {fmt_rs(held)} still here";
        } else {
            where = "already moved on";
        }
        reason = f"Rs {fmt_rs(amount)}{who} went {src.id} -> {acc.id} at {at}; {where}. Mule score {score} (Jev {jev_score}, traced-money rule {traced}).";
        stance = "FREEZE" if score >= FREEZE_MIN_SCORE and held > 0 else "WATCH";
        _proposal(acc, stance, score, reason);
        if score >= FREEZE_MIN_SCORE and held > 0 and not acc.frozen {
            _signal(acc, "FREEZE_REQUEST", self.from_bank);
        } elif score >= FREEZE_MIN_SCORE and acc.kind != "ATM_CASHOUT" {
            _signal(acc, "ACCOUNT_FLAGGED", self.from_bank);
        }
        self.hops.append({"from": src.id, "to": acc.id, "amount": amount, "time": at, "score": score,
                          "held": held, "victim": victim, "kind": acc.kind});
        WALK["step"] = len(self.path) - 1;
        add_line("MONEY_TRACER", reason);
    }
}

"""One MONEY_TRACER proposal per account (re-runs do not duplicate)."""
def _proposal(acc: Account, stance: str, score: float, reason: str) -> None {
    old = [p for p in [acc ->:HasProposal:->] if isinstance(p, Proposal) and p.agent == "MONEY_TRACER"];
    last = jev_last("jev_mule_scores");
    if old {
        old[0].stance = Stance(stance); old[0].confidence = score; old[0].reason = reason;
        return;
    }
    acc +>:HasProposal():+> Proposal(agent=AgentName.MONEY_TRACER, scope=Scope.NETWORK, stance=Stance(stance), confidence=score,
                                     reason=reason, ms=int(last["ms"]), source=str(last["source"]));
}

"""One Signal per (account, kind) — re-runs do not duplicate."""
def _signal(acc: Account, kind: str, from_bank: str) -> None {
    old = [s for s in [acc ->:Emitted:->] if isinstance(s, Signal) and s.kind == kind];
    if old { return; }
    acc +>:Emitted():+> Signal(kind=SignalKind(kind), subject_account=acc.id, from_bank=from_bank, to_bank=bank_short(acc),
                               time=now_hms(), status=SignalStatus.OPEN);
}
