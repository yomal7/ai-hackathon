"""Code-only fallback rules for every Jev (System 1) answer (owner: Person B).
Same return types as the real calls, source = "fallback". Never calls the network."""

import from ai.types { RiskVector }
import from ai.lang { scam_keywords_hit, scam_type_from_text, keywords_for, has_word, YES_WORDS, NO_WORDS }

glob LARGE_AMOUNT: float = 100000.0;

"""All text inside a state (any nesting), joined — so keywords are found wherever they sit."""
def state_text(value: any) -> str {
    if isinstance(value, str) { return value; }
    if isinstance(value, dict) { return " ".join([state_text(v) for v in value.values()]); }
    if isinstance(value, list) { return " ".join([state_text(v) for v in value]); }
    return "";
}

"""Any value -> str (for json.dumps default=)."""
def as_str(o: any) -> str {
    return str(o);
}

"""Any value -> float, or fallback_val if it is not a number."""
def to_float(v: any, fallback_val: float = 0.0) -> float {
    if isinstance(v, bool) { return float(v); }
    if isinstance(v, (int, float)) { return float(v); }
    try { return float(str(v)); } except ValueError { return fallback_val; }
}

def _num(d: dict, key: str, fallback_val: float = 0.0) -> float {
    return to_float(d.get(key), fallback_val);
}

"""Round to 2 decimals (0..1 scores)."""
def round2(x: float) -> float {
    return int(x * 100 + 0.5) / 100;
}

def _clip(x: float, lo: float, hi: float) -> float {
    return int(max(lo, min(x, hi)) * 100 + 0.5) / 100;
}

# ---------- coached / pressure ----------

def fb_coached(telemetry: dict, request: dict) -> float {
    on_call = bool(telemetry.get("on_call"));
    risky_payee = bool(telemetry.get("pasted_account") or telemetry.get("new_payee"));
    large = _num(request, "amount") >= LARGE_AMOUNT or request.get("action") == "BREAK_FD";
    text = state_text(request.get("reference_text", ""));
    hits = scam_keywords_hit(text);

    score = 0.1;
    if on_call and risky_payee and large { score = 0.9; }
    elif on_call { score = 0.6; }
    if hits and scam_type_from_text(text) != "NONE" { score = max(score, 0.6); }   # scam words alone are strong
    if _num(telemetry, "hesitation_ms") > 4000 or _num(telemetry, "backtracks") >= 2 { score += 0.1; }
    if hits { score += 0.1; }
    return _clip(score, 0.0, 0.98);
}

# ---------- routine ----------

"""0 Normal, 1 Unusual, 2 Very unusual, 3 Never seen — from amount ÷ largest habit amount."""
def fb_routine_level(state: dict) -> int {
    habits = state.get("habits", []) or [];
    action = state.get("action", "");
    amount = _num(state, "amount");
    if action == "LOGIN" or amount <= 0 { return 0; }
    if habits and action not in [h.get("action") for h in habits] { return 3; }   # e.g. first FD break ever
    largest = _num(state, "largest_habit_amount");
    for h in habits { largest = max(largest, _num(h as dict, "typical_amount")); }
    if largest <= 0 { return 2; }
    ratio = amount / largest;
    if ratio < 2 { return 0; }
    if ratio < 5 { return 1; }
    if ratio < 50 { return 2; }
    return 3;
}

def fb_decision(coached: float, routine_level: int) -> str {
    if coached >= 0.8 { return "HOLD"; }
    if coached >= 0.6 and routine_level >= 2 { return "HOLD"; }
    if coached >= 0.6 or routine_level >= 2 { return "STEP_UP"; }
    return "ALLOW";
}

def fb_request_vector(state: dict) -> RiskVector {
    tel = state.get("telemetry", {}) or {};
    coached = fb_coached(tel as dict, state);
    level = fb_routine_level(state);
    return RiskVector(
        coached=coached, routine_level=level,
        scam_type=scam_type_from_text(state_text(state)),
        decision=fb_decision(coached, level), ms=0, source="fallback"
    );
}

def fb_pressure(telemetry: dict, request: dict) -> RiskVector {
    coached = fb_coached(telemetry, request);
    level = fb_routine_level(request);
    return RiskVector(
        coached=coached, routine_level=level,
        scam_type=scam_type_from_text(state_text(request)),
        decision=fb_decision(coached, level), ms=0, source="fallback"
    );
}

# ---------- patterns ----------

# Words in a pattern name -> the scam type it describes.
glob NAME_HINTS: dict[str, list[str]] = {
    "FAKE_POLICE_SAFE_ACCOUNT": ["cid", "police", "safe account"],
    "CUSTOMS_PARCEL_FEE": ["customs", "parcel"],
    "LOTTERY_FEE": ["lottery", "prize"],
    "INVESTMENT_DOUBLE": ["double", "investment"],
    "FAKE_BANK_STAFF": ["bank staff", "bank officer"],
    "ROMANCE": ["romance", "love"]
};

"""Pattern name that fits the state, or "NONE". Uses state["pattern_phrases"] {name: [phrases]} if given."""
def fb_pattern(state: dict, pattern_names: list[str]) -> str {
    if not pattern_names { return "NONE"; }
    text = state_text({k: v for (k, v) in state.items() if k != "pattern_phrases"});
    phrases = state.get("pattern_phrases", {}) or {};
    best = "NONE";
    best_n = 0;
    for name in pattern_names {
        n = len([p for p in phrases.get(name, []) if has_word(text, str(p))]);
        if n > best_n { best = name; best_n = n; }
    }
    if best != "NONE" { return best; }
    kind = scam_type_from_text(text);
    if kind == "NONE" { return "NONE"; }
    for name in pattern_names {
        for hint in NAME_HINTS.get(kind, []) {
            if hint in name.lower() { return name; }
        }
    }
    return "NONE";
}

# ---------- Scam-Breaker reply ----------

def fb_read_reply(text: str) -> str {
    yes = any([has_word(text, w) for w in YES_WORDS]);
    no = any([has_word(text, w) for w in NO_WORDS]);
    caller_words = keywords_for("FAKE_POLICE_SAFE_ACCOUNT") + keywords_for("FAKE_BANK_STAFF");
    police = any([has_word(text, w) for w in caller_words]);
    if yes or (police and not no) { return "COACHED"; }
    if no { return "NOT_COACHED"; }
    return "UNSURE";
}

# ---------- mule scores ----------

"""Score 0..1 per account. Keys used: id, kind, opened_days_ago, distinct_senders,
minutes_to_move_on (None = not moved yet), from_flagged (got money from a known mule)."""
def fb_mule_score(acc: dict) -> float {
    age = _num(acc, "opened_days_ago", 9999.0);
    senders = _num(acc, "distinct_senders");
    kind = acc.get("kind", "PERSONAL");
    s = 0.05;
    if age < 30 { s += 0.35; } elif age < 90 { s += 0.15; }
    if senders >= 3 { s += 0.25; } elif senders == 2 { s += 0.15; }
    moved = acc.get("minutes_to_move_on");
    if isinstance(moved, (int, float)) {
        if moved < 60 { s += 0.25; } elif moved < 240 { s += 0.1; }
    }
    if acc.get("from_flagged") { s += 0.25; }
    if kind == "MULE_SUSPECT" { s += 0.1; }
    if kind == "ATM_CASHOUT" { s += 0.15; }
    if kind in ["SHOP", "BILLER", "HOSPITAL"] and age >= 365 { s = min(s, 0.3); }   # old real business
    return _clip(s, 0.0, 0.99);
}

def fb_mule_scores(accounts: list[dict]) -> dict {
    return {str(a.get("id", "")): fb_mule_score(a) for a in accounts};
}
