# Shared AI types. STUB written by A - B owns and replaces this file (B)

"""System 1 (Jev) answer: a fast, calibrated risk reading."""
obj RiskVector {
    has coached: float = 0.0;        # 0..1 - how likely the person is being coached by a scammer
    has routine_level: int = 0;      # 0 Normal, 1 Unusual, 2 Very unusual, 3 Never seen
    has scam_type: str = "NONE";     # NONE | FAKE_POLICE_SAFE_ACCOUNT | FAKE_BANK_STAFF | ...
    has decision: str = "ALLOW";     # ALLOW | STEP_UP | HOLD | BLOCK
    has ms: int = 0;
    has source: str = "fallback";    # "jev" or "fallback"
}
