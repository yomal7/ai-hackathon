# Scam-Breaker: talks to the elder in their language. STUB written by A - B owns and replaces this file (B)

"""Spawned by RunCouncil on a HELD Request with high pressure (B's real walker asks the questions)."""
walker ScamBreakerStart {
    has situation: str = "";             # English summary written by RunCouncil
}

"""Store the elder's answer, Jev reading and a new Proposal."""
walker ScamAnswer {
    has request_id: str = "";
    has q: int = 0;
    has answer: str = "";
}

"""Scam-Breaker part of the phone / War Room data."""
def scam_breaker_state(request_id: str) -> dict {
    return {"active": False, "language": "", "questions": [], "warning": "", "answers": []};
}
