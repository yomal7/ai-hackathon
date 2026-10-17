# Arbiter rules R1-R6 - PLAIN CODE, never LLM. Applied in order; the first rule that fits decides (A)
# Only R6 asks B's arbiter_decide (System 2), and even then the decision must be one of ours.
import from ai.llm_calls { arbiter_decide }

glob SPECIALISTS: list[str] = ["COERCION", "PLACE_TIME", "ROUTINE", "MULE_RING", "PATTERN"];
glob RISKY: list[str] = ["STEP_UP", "HOLD", "BLOCK", "ASK_GUARDIAN", "FREEZE"];
glob DECISIONS: list[str] = ["ALLOW", "STEP_UP", "HOLD", "BLOCK", "ASK_GUARDIAN", "ASK_ANALYST"];

glob ASSURANCE: dict[str, str] = {
    "ALLOW": "LOW", "STEP_UP": "MEDIUM", "HOLD": "HIGH", "ASK_GUARDIAN": "HIGH", "BLOCK": "HIGH", "ASK_ANALYST": "HIGH"
};

"""The proposal dict of one agent, or an empty dict."""
def find(proposals: list[dict], agent: str) -> dict {
    for p in proposals {
        if p.get("agent") == agent {
            return p;
        }
    }
    return {};
}

def conf(p: dict) -> float {
    return float(p.get("confidence", 0.0) as float);
}

"""Risk a proposal claims: its confidence if its stance is risky, else 0."""
def risk(p: dict) -> float {
    return conf(p) if str(p.get("stance", "")) in RISKY else 0.0;
}

"""Build a ruling dict with every field the arbiter needs."""
def ruling(decision: str, why: str, rule: str, locked: bool = False, deadlock: bool = False,
           ask_guardian: bool = False, scam_breaker: bool = False, emit: list[str] = [],
           tools_used: list[str] = []) -> dict {
    return {
        "decision": decision, "why": why, "rule": rule, "assurance": ASSURANCE.get(decision, "HIGH"),
        "locked": locked, "deadlock": deadlock, "ask_guardian": ask_guardian,
        "scam_breaker": scam_breaker, "emit": list(emit), "tools_used": list(tools_used)
    };
}

"""Apply R1..R6. proposals: [{"agent","stance","confidence","reason"}].
facts (code): payee_id, payee_confirmed_mule, payee_frozen, pressure, amount, largest_usual."""
def apply_rules(proposals: list[dict], facts: dict) -> dict {
    payee = str(facts.get("payee_id", ""));
    pressure = int(facts.get("pressure", 0) as int);
    amount = int(facts.get("amount", 0) as int);
    largest = int(facts.get("largest_usual", 0) as int);

    # R1. A confirmed mule or a frozen payee is always blocked.
    if facts.get("payee_confirmed_mule") or facts.get("payee_frozen") {
        what = "frozen" if facts.get("payee_frozen") else "a confirmed mule account";
        return ruling("BLOCK", f"Payee {payee} is {what} - always blocked", "R1");
    }

    # R2. Not the owner: impossible travel, or a new untrusted device at an odd hour with a big amount.
    pt = find(proposals, "PLACE_TIME");
    if pt.get("stance") == "BLOCK" {
        return ruling("BLOCK", f"Not the real owner: {pt.get('reason', '')}. Session revoked.", "R2",
                      emit=["SESSION_REVOKED"]);
    }

    # R3. The real owner under pressure, moving far more than usual: 24 h cooling-off.
    if pressure >= 70 and amount >= 5 * largest {
        mule = find(proposals, "MULE_RING");
        pat = find(proposals, "PATTERN");
        locked = risk(mule) >= 0.75 or risk(pat) >= 0.75;
        times = f"{int(amount / largest + 0.5):,}×" if largest > 0 else "far above";
        why = f"Pressure {pressure} and {times} the usual payment: HOLD 24 h, Scam-Breaker and guardian";
        if locked {
            who = "MULE_RING" if risk(mule) >= 0.75 else "PATTERN";
            why += f". Locked by {who} - guardian can only Reject or Call";
        }
        return ruling("HOLD", why, "R3", locked=locked, ask_guardian=True, scam_breaker=True);
    }

    # R4. Fast path: no specialist sees real risk.
    if all([risk(find(proposals, a)) <= 0.3 for a in SPECIALISTS]) {
        return ruling("ALLOW", "All specialists see low risk", "R4");
    }

    # R5. Deadlock: Coercion or Routine says HOLD/BLOCK, the Advocate says ALLOW - both strong.
    adv = find(proposals, "ADVOCATE");
    for a in ["COERCION", "ROUTINE"] {
        p = find(proposals, a);
        if p.get("stance") in ["HOLD", "BLOCK"] and conf(p) >= 0.75 and adv.get("stance") == "ALLOW" and conf(adv) >= 0.75 {
            why = f"DEADLOCK - {a}: {p.get('stance')} ({p.get('reason', '')}) vs ADVOCATE: ALLOW ({adv.get('reason', '')}). Step-up check and ask the guardian.";
            return ruling("STEP_UP", why, "R5", deadlock=True, ask_guardian=True);
        }
    }

    # R6. Everything else: System 2 reasons over the proposals. Its decision must be one of ours.
    out = arbiter_decide(proposals, facts);
    decision = str(out.get("decision", ""));
    if decision not in DECISIONS {
        decision = "STEP_UP";
    }
    tools = [str(t) for t in (out.get("tools_used", []) or [])];
    return ruling(decision, str(out.get("why", "System 2 decision")), "R6",
                  ask_guardian=decision in ["HOLD", "ASK_GUARDIAN"], tools_used=tools);
}
