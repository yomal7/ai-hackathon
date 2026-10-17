# System 2 (by llm) calls. STUB written by A: fixed fallback texts, no LLM yet - B owns and replaces this file (B)
import from ai.lang { pick, SCAM_QUESTIONS, SCAM_WARNING, GUARDIAN_TITLE, GUARDIAN_LINES, DEBRIEF }

"""Rule R6 only. Fallback: follow the strongest risky proposal."""
def arbiter_decide(proposals: list[dict], state: dict) -> dict {
    decision = "ALLOW";
    why = "No strong risk signal from the council";
    for p in proposals {
        stance = str(p.get("stance", "ALLOW"));
        conf = float(p.get("confidence", 0.0) as float);
        if stance in ["HOLD", "BLOCK"] and conf >= 0.5 {
            decision = "HOLD";
            why = f"{p.get('agent', '?')} says {stance} ({conf})";
        } elif stance == "STEP_UP" and decision == "ALLOW" {
            decision = "STEP_UP";
            why = f"{p.get('agent', '?')} asks for a step-up check";
        }
    }
    return {"decision": decision, "why": why, "tools_used": []};
}

"""2-3 Scam-Breaker questions in the elder's language."""
def scam_questions(situation: str, language: str) -> dict {
    return {
        "language": language,
        "questions": pick(SCAM_QUESTIONS, language),
        "warning": pick(SCAM_WARNING, language)
    };
}

"""Guardian card: title + max 3 lines + options, in the guardian's language."""
def guardian_card(summary: str, evidence: list[str], language: str, facts: dict | None = None) -> dict {
    return {
        "language": language,
        "title": pick(GUARDIAN_TITLE, language),
        "lines": pick(GUARDIAN_LINES, language)[:3],
        "options": ["REJECT", "APPROVE", "CALL"]
    };
}

"""Analyst card in English, same shape as guardian_card."""
def analyst_card(summary: str, evidence: list[str]) -> dict {
    lines = evidence[:3] if evidence else [summary];
    return {
        "language": "en",
        "title": "Cross-bank freeze needs your approval",
        "lines": lines,
        "options": ["APPROVE", "KEEP_OPEN"]
    };
}

"""4 short lines telling the person what happened."""
def debrief(case_info: dict, language: str) -> str {
    return str(pick(DEBRIEF, language));
}
