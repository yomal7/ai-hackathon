# Shared helpers for the Phone Shield and the Bank Council agents (A)
# Agents never call each other: they read the graph and write Proposal nodes on it.
import time;
import from graph.nodes { RNode, Citizen, Habit, Account, Request, Proposal, PressureReading, Stance, Action }
import from graph.edges { Has, HasProposal, Read }
import from graph.queries { citizen_of, payee_of, add_timeline }

# Stances that mean "risk". ALLOW / WATCH carry no risk.
glob RISKY_STANCES: list[str] = ["STEP_UP", "HOLD", "BLOCK", "ASK_GUARDIAN", "FREEZE"];

# The 5 specialists whose risk rule R4 looks at (the Advocate argues the other side).
glob SPECIALISTS: list[str] = ["COERCION", "PLACE_TIME", "ROUTINE", "MULE_RING", "PATTERN"];

# Readable names for request actions (English reasons for the War Room).
glob ACTION_WORDS: dict[str, str] = {
    "BILL_PAY": "bill payment", "TRANSFER": "transfer", "BREAK_FD": "FD break", "LOGIN": "login"
};

"""Milliseconds since t0 (a time.perf_counter() value)."""
def ms_since(t0: float) -> int {
    return int((time.perf_counter() - t0) * 1000);
}

"""Round a 0..1 score to 2 decimals and keep it inside 0..1."""
def score(x: float) -> float {
    v = 1.0 if x > 1.0 else (0.0 if x < 0.0 else x);
    return int(v * 100 + 0.5) / 100.0;
}

"""Rs 4200000 -> "Rs 4,200,000"."""
def rs(amount: int) -> str {
    return f"Rs {amount:,}";
}

"""Demo clock "02:13" -> "2:13 AM"."""
def clock12(hhmm: str) -> str {
    parts = hhmm.split(":");
    h = int(parts[0]);
    suffix = "AM" if h < 12 else "PM";
    h12 = h % 12;
    return f"{12 if h12 == 0 else h12}:{parts[1]} {suffix}";
}

"""Hour of a demo clock "HH:MM"."""
def hour_of(hhmm: str) -> int {
    return int(hhmm.split(":")[0]);
}

"""First name for short labels ("Seeya Siriwardena" -> "Seeya")."""
def first_name(c: Citizen | None) -> str {
    return c.name.split(" ")[0] if c is not None else "?";
}

def habits_of(c: Citizen) -> list[Habit] {
    return [c ->:Has:->];
}

"""Largest usual PAYMENT (bills, transfers) - withdrawals do not count."""
def largest_usual_payment(c: Citizen) -> int {
    amounts = [h.typical_amount for h in habits_of(c) if h.action in ["BILL_PAY", "TRANSFER"]];
    return max(amounts) if amounts else 0;
}

"""The request as a plain dict (what Jev and the rules read). Keys match B's ai/ functions."""
def request_state(req: Request) -> dict[str, any] {
    c = citizen_of(req);
    payee = payee_of(req);
    own_habits = habits_of(c) if c is not None else [];
    habits: list[dict[str, any]] = [
        {"action": h.action, "label": h.label, "typical_amount": h.typical_amount,
         "hour_from": h.hour_from, "hour_to": h.hour_to, "count": h.count}
        for h in own_habits
    ];
    return {
        "id": req.id,
        "action": str(req.action),
        "amount": req.amount,
        "time": req.time,
        "reference_text": req.reference_text,
        "language": str(req.language),
        "telemetry": dict(req.telemetry),
        "citizen_age": c.age if c is not None else 0,
        "habits": habits,
        "largest_habit_amount": largest_usual_payment(c) if c is not None else 0,
        "payee": {"id": payee.id, "kind": str(payee.kind), "opened_days_ago": payee.opened_days_ago} if payee is not None else {}
    };
}

"""Latest proposal of each agent on a node (request or account)."""
def proposals_of(target: RNode) -> list[Proposal] {
    return [target ->:HasProposal:->];
}

def proposal_of(target: RNode, agent: str) -> Proposal | None {
    found = [p for p in proposals_of(target) if p.agent == agent];
    return found[-1] if found else None;
}

"""Save an agent's Proposal on a node. Its older proposal on that node is replaced. Adds a timeline line."""
def put_proposal(target: RNode, p: Proposal) -> Proposal {
    for old in proposals_of(target) {
        if old.agent == p.agent {
            del old;
        }
    }
    target +>:HasProposal:+> p;
    add_timeline(str(p.agent), f"{p.stance} ({p.confidence:.2f}) - {p.reason}");
    return p;
}

"""How much risk a proposal claims: its confidence if the stance is risky, else 0."""
def risk_of(p: Proposal) -> float {
    return p.confidence if str(p.stance) in RISKY_STANCES else 0.0;
}

"""Proposal as a plain dict (for the rules, B's arbiter_decide and the War Room)."""
def proposal_dict(p: Proposal) -> dict[str, any] {
    return {"agent": str(p.agent), "stance": str(p.stance), "confidence": p.confidence,
            "reason": p.reason, "ms": p.ms, "source": p.source};
}

"""Latest pressure reading of a request, or None."""
def latest_pressure(req: Request) -> PressureReading | None {
    found = [req ->:Read:->];
    return found[-1] if found else None;
}

"""Stance from a 0..1 risk: >= hold -> HOLD, >= step -> STEP_UP, else ALLOW."""
def stance_for(risk: float, hold: float = 0.75, step: float = 0.4) -> Stance {
    if risk >= hold {
        return Stance.HOLD;
    }
    if risk >= step {
        return Stance.STEP_UP;
    }
    return Stance.ALLOW;
}

"""Confidence to store with a stance: the risk itself, or (1 - risk) when the stance is ALLOW."""
def confidence_for(stance: Stance, risk: float) -> float {
    return score(1.0 - risk) if stance == Stance.ALLOW else score(risk);
}
