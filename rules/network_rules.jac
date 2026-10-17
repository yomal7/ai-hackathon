"""Fraud Network safety rules — PLAIN CODE, never LLM (owner: Person B).
- A cross-bank freeze ALWAYS needs a human analyst. Nothing here freezes an account.
- FREEZE is only proposed when mule score >= 0.8 AND the liaison's advocate does not object (>= 0.75).
- Advocate objects -> DEADLOCK -> the analyst sees both sides."""

import from ai.fallback { round2 }

glob FREEZE_MIN_SCORE: float = 0.8;
glob OBJECTION_MIN: float = 0.75;
glob TRACED_BASE: float = 0.8;           # money traced straight from a confirmed mule landed here

"""Code evidence from the money trail (the tracer saw it, so it is a fact, not a guess)."""
def traced_score(opened_days_ago: int, minutes_to_move_on: int | None, kind: str) -> float {
    if kind == "ATM_CASHOUT" { return 0.0; }        # cash already out: nothing to freeze
    s = TRACED_BASE;
    if opened_days_ago < 90 { s += 0.05; }
    if minutes_to_move_on is not None and minutes_to_move_on < 60 { s += 0.05; }
    return round2(min(s, 0.95));
}

"""Mule score = the higher of Jev's score and the traced-money rule."""
def mule_score(jev_score: float, traced: float) -> float {
    return max(jev_score, traced);
}

"""Liaison's own advocate: an old account with steady normal sales from many people is not a mule.
Returns objection strength 0..1 (0 = no objection)."""
def advocate_objection(opened_days_ago: int, kind: str, distinct_senders: int, inflow_count: int) -> float {
    old = opened_days_ago >= 365;
    business = kind in ["SHOP", "BILLER", "HOSPITAL"];
    steady = distinct_senders >= 10 or inflow_count >= 10;
    if old and business and steady { return 0.85; }
    if old and (business or steady) { return 0.6; }
    return 0.0;
}

"""ASK_ANALYST (freeze proposed), DEADLOCK (advocate objects), or WATCH (score too low)."""
def network_verdict(score: float, objection: float) -> str {
    if score < FREEZE_MIN_SCORE { return "WATCH"; }
    if objection >= OBJECTION_MIN { return "DEADLOCK"; }
    return "ASK_ANALYST";
}

"""Only a human analyst's APPROVE may freeze an account at another bank."""
def may_freeze(analyst_answer: str) -> bool {
    return analyst_answer == "APPROVE";
}
