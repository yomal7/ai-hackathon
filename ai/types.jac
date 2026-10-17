"""Shared AI types for Rakshaka (owner: Person B). Shapes are fixed — see section 6."""

# System 1 (Jev) answer for one request. source = "jev" or "fallback".
obj RiskVector {
    has coached: float = 0.1;       # 0..1, someone is telling them what to do
    has routine_level: int = 0;     # 0 Normal, 1 Unusual, 2 Very unusual, 3 Never seen
    has scam_type: str = "NONE";    # one of ScamType
    has decision: str = "ALLOW";    # one of JevDecision
    has ms: int = 0;
    has source: str = "fallback";
}

enum Reply: str {
    COACHED = "COACHED",
    NOT_COACHED = "NOT_COACHED",
    UNSURE = "UNSURE"
}

enum ScamType: str {
    NONE = "NONE",
    FAKE_POLICE_SAFE_ACCOUNT = "FAKE_POLICE_SAFE_ACCOUNT",
    FAKE_BANK_STAFF = "FAKE_BANK_STAFF",
    CUSTOMS_PARCEL_FEE = "CUSTOMS_PARCEL_FEE",
    ROMANCE = "ROMANCE",
    INVESTMENT_DOUBLE = "INVESTMENT_DOUBLE",
    LOTTERY_FEE = "LOTTERY_FEE"
}

enum JevDecision: str {
    ALLOW = "ALLOW",
    STEP_UP = "STEP_UP",
    HOLD = "HOLD",
    BLOCK = "BLOCK"
}

# Public result of learn_pattern(). (The LLM's own output objs live in ai/llm_calls.jac,
# because byllm needs them in the same file as the by llm() function.)
obj ScamPatternDraft {
    has name: str;
    has features: list[str];
    has phrases: list[str];
}


glob LANGS: list[str] = ["si", "ta", "en"];
