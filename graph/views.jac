# Screen data for C's API: war_room_data / phone_data / guardian_data (A)
# FAKE fixed data until M3, so C can build the screens now. The return SHAPES are final (section 8).

"""Everything the War Room shows."""
def war_room_data() -> dict {
    return {
        "graph": {
            "nodes": [
                {"id": "c_seeya", "type": "Citizen", "label": "Seeya", "x": 80, "y": 200, "state": "active"},
                {"id": "a_ldb_77821", "type": "Account", "label": "LDB-77821", "x": 380, "y": 260, "state": "mule"}
            ],
            "edges": [{"from": "c_seeya", "to": "a_ldb_77821", "type": "PaysTo", "label": "Rs 4,200,000", "state": "suspect"}]
        },
        "request": {
            "id": "req_demo", "citizen": "Siriwardena (Seeya)", "language": "si", "action": "BREAK_FD",
            "amount": 4200000, "payee": "LDB-77821", "status": "HELD"
        },
        "proposals": [
            {"agent": "MULE_RING", "stance": "BLOCK", "confidence": 0.93,
             "reason": "2 other elders paid this 9-day-old account in the last 35 min", "ms": 41, "source": "code"}
        ],
        "ruling": {"decision": "HOLD", "why": "Coached transfer to a mule ring account", "rule": "R3",
                   "assurance": "HIGH", "ms": 180, "deadlock": False, "locked": True},
        "pressure": {"value": 86, "reasons": ["On a phone call", "Pasted account number", "Note says 'safe account'"]},
        "walk": {"kind": "MULE_RING", "path": ["c_seeya", "a_ldb_77821"], "step": 1},
        "signals": [],
        "alerts": [],
        "people_saw": [],
        "counters": {"checked": 1, "blocked": 0, "held": 1, "protected_rs": 0, "recovered_rs": 0, "human_needed": 0,
                     "detect_times": [{"name": "Mallika", "seconds": -1}, {"name": "Rasheed", "seconds": -1}]},
        "normal_security": {"password": True, "otp": True, "device": True, "place": True, "verdict": "ALLOW"},
        "timeline": [{"time": "14:30:05", "agent": "COERCION", "text": "Pressure 86 - on a phone call"}]
    };
}

"""What the elder's phone shows for one request."""
def phone_data(request_id: str) -> dict {
    return {
        "language": "si", "screen": "HELD", "pressure": 86, "balance": 185000, "fd": 4200000,
        "scam_breaker": {"active": False, "language": "si", "questions": [], "warning": "", "answers": []},
        "message": ""
    };
}

"""What the guardian's phone shows."""
def guardian_data(guardian_id: str) -> dict {
    return {"language": "si", "name": "Dilshan", "alerts": []};
}
