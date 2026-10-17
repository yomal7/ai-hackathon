"""Scam-Breaker (agent 7, owner: Person B).
Talks to the elder in their own language: 2-3 calm questions, reads each reply
with Jev (any language), then writes ONE Proposal for the Arbiter.
Walkers: ScamBreakerStart (spawned by A on HOLD + pressure >= 70),
         ScamAnswer (spawned by C's scam_answer API)."""

import time;
import from graph.nodes { Request, ScamCheck, Proposal, Citizen, Guardian, Alert, AgentName, Scope, Stance, JevReading, Lang }
import from graph.edges { Made, Checked, HasProposal, ProtectedBy, Raised }
import from ai.jev { jev_read_reply, jev_last }
import from ai.llm_calls { scam_questions }
import from ai.lang { fixed_text, fmt_rs, safe_lang }
import from agents.network.net_common { find_request }
import from ai.fallback { round2 }

glob _warnings: dict[str, str] = {};     # request id -> warning line shown to the elder

# ---------- graph lookups ----------

def citizen_of(req: Request) -> Citizen | None {
    found = [n for n in [req <-:Made:<-] if isinstance(n, Citizen)];
    return found[0] if found else None;
}

def guardian_of(c: Citizen | None) -> Guardian | None {
    if c is None { return None; }
    found = [n for n in [c ->:ProtectedBy:->] if isinstance(n, Guardian)];
    return found[0] if found else None;
}

def checks_of(req: Request) -> list[ScamCheck] {
    return [n for n in [req ->:Checked:->] if isinstance(n, ScamCheck)];
}

def _lang_of(req: Request) -> str {
    c = citizen_of(req);
    return safe_lang(c.language if c else req.language);
}

"""Plain English situation for the LLM (never shown to the elder)."""
def situation_of(req: Request) -> str {
    c = citizen_of(req);
    who = f"{c.name} ({c.age})" if c else "An elderly customer";
    call = "is on a phone call and " if req.telemetry.get("on_call") else "";
    return f"{who} {call}is trying to {req.action} of Rs {fmt_rs(req.amount)} to a new account. Reference: '{req.reference_text}'.";
}

# ---------- Proposal from the answers (plain code) ----------

"""HOLD if any reply is COACHED, else STEP_UP. Confidence from code, never from the LLM."""
def answers_proposal(req: Request, checks: list[ScamCheck], ms: int, source: str) -> Proposal {
    readings = [c.jev_reading for c in checks];
    coached = [c for c in checks if c.jev_reading == "COACHED"];
    c = citizen_of(req);
    name = c.name if c else "The customer";
    if coached {
        stance = "HOLD";
        confidence = min(0.95, 0.6 + 0.12 * len(coached));
        reason = f"{name} answered {len(coached)} of {len(checks)} safety questions like someone being coached (reply: \"{coached[0].answer}\").";
    } elif all([r == "NOT_COACHED" for r in readings]) {
        stance = "STEP_UP";
        confidence = 0.7;
        reason = f"{name} says nobody is guiding the payment; ask for one extra check.";
    } else {
        stance = "STEP_UP";
        confidence = 0.5;
        reason = f"{name}'s replies are unclear; ask for one extra check.";
    }
    return Proposal(agent=AgentName.SCAM_BREAKER, scope=Scope.REQUEST, stance=Stance(stance), confidence=round2(confidence),
                    reason=reason, ms=ms, source=source);
}

def _first_open(checks: list[ScamCheck]) -> int {
    for (i, c) in enumerate(checks) {
        if not c.answer { return i; }
    }
    return -1;
}

# ---------- walkers ----------

walker ScamBreakerStart {
    has situation: str = "";             # optional: A may pass its own English summary

    can start with Request entry {
        if checks_of(here) {             # already started: do not ask twice
            report scam_breaker_state(here.id);
            disengage;
        }
        lang = _lang_of(here);
        res = scam_questions(self.situation or situation_of(here), lang);
        for q in list(res["questions"]) {
            here +>:Checked():+> ScamCheck(question=str(q), answer="", jev_reading=JevReading.NONE, language=Lang(lang));
        }
        _warnings[here.id] = str(res["warning"]);
        report scam_breaker_state(here.id);
    }
}

walker ScamAnswer {
    has request_id: str = "";            # set when spawned on root (C's API); empty when spawned on the Request
    has q: int = -1;                     # question index (0-based); -1 = the next unanswered one
    has answer: str = "";                # button value or typed text, any language

    can locate with Root entry {
        req = find_request(self.request_id);
        if req is None { report {"next_question": None, "error": "unknown request"}; disengage; }
        visit req;
    }

    can answer_it with Request entry {
        checks = checks_of(here);
        if not checks { report {"next_question": None}; disengage; }
        idx = self.q if 0 <= self.q and self.q < len(checks) else _first_open(checks);
        if idx < 0 { report {"next_question": None}; disengage; }    # all answered: ignore extra answers
        t0 = time.perf_counter();
        checks[idx].answer = self.answer;
        checks[idx].jev_reading = JevReading(jev_read_reply(self.answer));
        ms = int((time.perf_counter() - t0) * 1000);
        left = [c for c in checks if not c.answer];
        if left {
            report {"next_question": left[0].question};
            disengage;
        }
        old = [p for p in [here ->:HasProposal:->] if isinstance(p, Proposal) and p.agent == "SCAM_BREAKER"];
        if not old {                     # write the Proposal once, after the last answer
            here +>:HasProposal():+> answers_proposal(here, checks, ms, str(jev_last("jev_read_reply")["source"]));
        }
        report {"next_question": None};
    }
}

# ---------- state for screens ----------

"""For get_phone(): {active, language, questions, warning, answers, readings, guardian_message}."""
def scam_breaker_state(request_id: str) -> dict {
    req = find_request(request_id);
    if req is None {
        return {"active": False, "language": "en", "questions": [], "warning": "", "answers": [], "readings": [], "guardian_message": ""};
    }
    checks = checks_of(req);
    lang = _lang_of(req);
    g = guardian_of(citizen_of(req));
    asked = [a for a in [req ->:Raised:->] if isinstance(a, Alert) and a.kind == "GUARDIAN"];
    return {
        "active": bool(checks) and req.status not in ["ALLOWED", "BLOCKED"],
        "language": lang,
        "questions": [c.question for c in checks],
        "warning": _warnings.get(req.id, fixed_text("sb_warning", lang)) if checks else "",
        "answers": [c.answer for c in checks],
        "readings": [c.jev_reading for c in checks],
        "guardian_message": fixed_text("sb_guardian_asked", lang, {"guardian": g.name if g else ""}) if asked else ""
    };
}

"""For the War Room hover: everything the elder and the guardian saw, in their language."""
def people_saw(request_id: str) -> list[dict] {
    req = find_request(request_id);
    if req is None { return []; }
    c = citizen_of(req);
    elder = c.name if c else "Elder";
    st = scam_breaker_state(request_id);
    out: list[dict] = [{"who": elder, "language": st["language"], "text": q} for q in st["questions"]];
    if st["warning"] { out.append({"who": elder, "language": st["language"], "text": st["warning"]}); }
    if st["guardian_message"] { out.append({"who": elder, "language": st["language"], "text": st["guardian_message"]}); }
    g = guardian_of(c);
    for a in [req ->:Raised:->] {
        if isinstance(a, Alert) and a.kind == "GUARDIAN" {
            out.append({"who": g.name if g else "Guardian", "language": a.language, "text": " / ".join([a.title] + list(a.lines))});
        }
    }
    return out;
}
