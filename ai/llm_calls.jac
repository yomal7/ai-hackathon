"""System 2 — LLM (by llm()) calls (owner: Person B).
Each public function: cache -> Gemini (time-limited) -> checked -> else fixed text
from ai/llm_fallback.jac. Signatures never change.
Safety: the LLM never sets numbers — any number it writes must be in the input."""

import json;
import threading;
import from functools { partial }
import from ai.env { make_llm }
import from ai.fallback { as_str }
import from ai.types { ScamPatternDraft }
import from ai.lang { safe_lang, detect_language }
import from ai.llm_guard { run_llm, text_ok, numbers_ok }
import from ai.llm_fallback {
    PATTERN_NAMES, guardian_options, analyst_options, card_values,
    fb_scam_questions, fb_guardian_card, fb_analyst_card, fb_debrief, fb_arbiter,
    fb_learn_pattern, case_scam_type, all_language_phrases
}

# ---------- LLM output types (must live in this file for byllm) ----------

obj ScamQuestions {
    has language: str;
    has questions: list[str];
    has warning: str;
}
sem ScamQuestions.questions = "2 or 3 short, calm yes/no questions. One idea each. No numbers.";
sem ScamQuestions.warning = "One short calm warning line: police and banks never ask you to move money to a safe account; talk to your family.";

obj Card {
    has language: str;
    has title: str;
    has lines: list[str];
}
sem Card.title = "One short line.";
sem Card.lines = "At most 3 short lines in plain words. Copy any number exactly from the input.";

obj PatternOut {
    has name: str;
    has features: list[str];
    has phrases: list[str];
}
sem PatternOut.name = "Scam pattern name, at most 5 words.";
sem PatternOut.features = "3 to 6 short English phrases describing how the scam works.";
sem PatternOut.phrases = "Key scam phrases exactly as the victim heard or wrote them, in their original language.";

# Typed tool choice — used when the LLM does not call the Arbiter tools itself.
obj Action {
    has tool: str;
    has args: dict[str, str];
    has why: str;
}

glob llm: any = make_llm();      # works on Jac 0.16 and 0.34 (see ai/env.jac)

glob LANG_NAME: dict[str, str] = {
    "si": "Sinhala, in Sinhala script",
    "ta": "Tamil, in Tamil script",
    "en": "English"
};

glob STYLE: str = "Use simple, calm, everyday words. No jargon. Short sentences. This reader is an elderly person or their family.";

# ==================== Scam-Breaker questions ====================

def _llm_questions(situation: str, language: str, style: str) -> ScamQuestions by llm(temperature=0.3);
sem _llm_questions = "Write 2 or 3 short, calm yes/no questions that gently check whether an elderly bank customer is being guided by a scam caller right now, and one warning line. Write ONLY in the given language. Never use numbers.";
sem _llm_questions.situation = "What is happening (English).";
sem _llm_questions.language = "The language and script to write in.";
sem _llm_questions.style = "How to write.";

def _gen_questions(situation: str, lang: str) -> dict | None {
    q = _llm_questions(situation, LANG_NAME[lang], STYLE);
    qs = [x.strip() for x in q.questions if x.strip()][:3];
    if len(qs) < 2 or not all([text_ok(x, lang, 160) for x in qs]) { return None; }
    if not text_ok(q.warning, lang, 260) { return None; }
    if not numbers_ok(" ".join(qs) + q.warning, situation) { return None; }
    return {"language": lang, "questions": qs, "warning": q.warning.strip(), "source": "llm"};
}

"""{"language", "questions": [2-3 str], "warning"} in the elder's language."""
def scam_questions(situation: str, language: str) -> dict {
    lang = safe_lang(language);
    res = run_llm("scam_questions", {"s": situation, "l": lang}, partial(_gen_questions, situation, lang));
    return dict(res) if res else fb_scam_questions(lang);
}

# ==================== cards ====================

def _llm_guardian_card(summary: str, evidence: list[str], facts: str, language: str, style: str) -> Card by llm(temperature=0.2);
sem _llm_guardian_card = "Write a short alert card for the son or daughter (guardian) of an elderly bank customer. The bank paused a payment and needs them to Reject, Approve or Call. Write ONLY in the given language. Use only the facts given. Copy numbers exactly.";
sem _llm_guardian_card.summary = "What happened (English).";
sem _llm_guardian_card.evidence = "Why the bank is worried (English).";
sem _llm_guardian_card.facts = "Exact facts: names and amounts to use.";
sem _llm_guardian_card.language = "The language and script to write in.";
sem _llm_guardian_card.style = "How to write.";

def _gen_guardian_card(summary: str, evidence: list[str], facts_text: str, lang: str) -> dict | None {
    c = _llm_guardian_card(summary, evidence, facts_text, LANG_NAME[lang], STYLE);
    lines = [x.strip() for x in c.lines if x.strip()][:3];
    if not lines or not text_ok(c.title, lang, 120) or not all([text_ok(x, lang, 200) for x in lines]) { return None; }
    if not numbers_ok(c.title + " " + " ".join(lines), summary + " " + " ".join(evidence) + " " + facts_text) { return None; }
    return {"language": lang, "title": c.title.strip(), "lines": lines, "options": guardian_options(lang), "source": "llm"};
}

"""Guardian card: {"language", "title", "lines" (max 3), "options"}.
facts (optional): {"name", "parent": "father"|"mother", "amount", "others"}."""
def guardian_card(summary: str, evidence: list[str], language: str, facts: dict | None = None) -> dict {
    lang = safe_lang(language);
    f = facts or {};
    vals = card_values(f, lang);
    facts_text = json.dumps(vals, ensure_ascii=False) if vals else "";
    res = run_llm("guardian_card", {"s": summary, "e": evidence, "f": facts_text, "l": lang},
                  partial(_gen_guardian_card, summary, evidence, facts_text, lang));
    return dict(res) if res else fb_guardian_card(lang, f);
}

def _llm_analyst_card(summary: str, evidence: list[str]) -> Card by llm(temperature=0.1);
sem _llm_analyst_card = "Write a short, factual English alert card for a bank fraud analyst who must approve or keep open a cross-bank account freeze. Title: one line. Lines: at most 3, most important evidence first. If agents disagree, show both sides. Copy numbers exactly; never invent numbers.";
sem _llm_analyst_card.summary = "The freeze request.";
sem _llm_analyst_card.evidence = "Evidence lines from the agents.";

def _gen_analyst_card(summary: str, evidence: list[str]) -> dict | None {
    c = _llm_analyst_card(summary, evidence);
    lines = [x.strip() for x in c.lines if x.strip()][:3];
    if not lines or not text_ok(c.title, "en", 140) or not all([text_ok(x, "en", 220) for x in lines]) { return None; }
    if not numbers_ok(c.title + " " + " ".join(lines), summary + " " + " ".join(evidence)) { return None; }
    return {"language": "en", "title": c.title.strip(), "lines": lines, "options": analyst_options(), "source": "llm"};
}

"""Analyst card (English): same shape as guardian_card; options APPROVE / KEEP_OPEN."""
def analyst_card(summary: str, evidence: list[str]) -> dict {
    res = run_llm("analyst_card", {"s": summary, "e": evidence}, partial(_gen_analyst_card, summary, evidence));
    return dict(res) if res else fb_analyst_card(summary, evidence);
}

# ==================== debrief ====================

def _llm_debrief(english_lines: list[str], language: str, style: str) -> list[str] by llm(temperature=0.2);
sem _llm_debrief = "Rewrite each of these 4 English lines in the given language, one line each, same meaning, same order. Keep every number and name exactly. Return exactly 4 lines.";
sem _llm_debrief.english_lines = "The 4 true lines of the story (English).";
sem _llm_debrief.language = "The language and script to write in.";
sem _llm_debrief.style = "How to write.";

def _gen_debrief(english_lines: list[str], lang: str) -> dict | None {
    lines = [x.strip() for x in _llm_debrief(english_lines, LANG_NAME[lang], STYLE) if x.strip()];
    if len(lines) != 4 or not all([text_ok(x, lang, 220) for x in lines]) { return None; }
    if not numbers_ok(" ".join(lines), " ".join(english_lines)) { return None; }
    return {"text": "\n".join(lines)};
}

"""4 short lines. case_info keys: name, amount, seconds, guardian, recovered.
(Named case_info because `case` is a Jac keyword; call it positionally.)"""
def debrief(case_info: dict, language: str) -> str {
    lang = safe_lang(language);
    english = fb_debrief(case_info, "en").split("\n");
    if lang == "en" { return "\n".join(english); }          # the English lines are already the true story
    res = run_llm("debrief", {"e": english, "l": lang}, partial(_gen_debrief, english, lang));
    return str(res["text"]) if res else fb_debrief(case_info, lang);
}

# ==================== Arbiter (rule R6 only) ====================
# The tools only RECORD the choice. A's code writes the Ruling. The LLM never sets numbers.

glob DECISION_TOOLS: list[str] = ["ALLOW", "STEP_UP", "HOLD", "BLOCK", "ASK_GUARDIAN", "ASK_ANALYST"];
glob _arb_lock: threading.Lock = threading.Lock();
glob _arb_calls: list[str] = [];

def allow(why: str) -> str { _arb_calls.append("ALLOW"); return "ALLOW recorded"; }
sem allow = "Let the payment go through. It is normal for this person.";
sem allow.why = "One short English sentence.";
def step_up(why: str) -> str { _arb_calls.append("STEP_UP"); return "STEP_UP recorded"; }
sem step_up = "Ask for an extra check (e.g. guardian approval) before paying. Good for a real but unusual need.";
sem step_up.why = "One short English sentence.";
def hold(why: str) -> str { _arb_calls.append("HOLD"); return "HOLD recorded"; }
sem hold = "Pause the payment: likely scam pressure on the real owner.";
sem hold.why = "One short English sentence.";
def block(why: str) -> str { _arb_calls.append("BLOCK"); return "BLOCK recorded"; }
sem block = "Stop it: clearly not the owner, or a confirmed mule account.";
sem block.why = "One short English sentence.";
def ask_guardian(why: str) -> str { _arb_calls.append("ASK_GUARDIAN"); return "ASK_GUARDIAN recorded"; }
sem ask_guardian = "Ask the elder's son or daughter to approve or reject.";
sem ask_guardian.why = "One short English sentence.";
def ask_analyst(why: str) -> str { _arb_calls.append("ASK_ANALYST"); return "ASK_ANALYST recorded"; }
sem ask_analyst = "Ask a human bank fraud analyst to decide.";
sem ask_analyst.why = "One short English sentence.";
def emit_signal(kind: str, account: str) -> str { _arb_calls.append("emit_signal"); return "signal noted"; }
sem emit_signal = "Warn the other banks about an account (optional, in addition to one decision).";
sem emit_signal.kind = "ACCOUNT_FLAGGED or FREEZE_REQUEST.";
sem emit_signal.account = "Account id.";

def _llm_arbiter(proposals: str, state: str) -> str by llm(
    tools=[allow, step_up, hold, block, ask_guardian, ask_analyst, emit_signal],
    max_react_iterations=3, temperature=0.0
);
sem _llm_arbiter = "You are the Guardian Arbiter of a bank. The specialist agents are deadlocked. Call exactly ONE decision tool (allow, step_up, hold, block, ask_guardian, ask_analyst); you may also call emit_signal. Use at most 2 tools. Protect the elder without locking them out of their own money. Then answer with ONE short English sentence saying why. Never invent numbers.";
sem _llm_arbiter.proposals = "The agents' proposals (JSON).";
sem _llm_arbiter.state = "The request facts (JSON).";

def _llm_arbiter_action(proposals: str, state: str) -> Action by llm(temperature=0.0);
sem _llm_arbiter_action = "You are the Guardian Arbiter of a bank. The specialist agents are deadlocked. Pick ONE tool: ALLOW, STEP_UP, HOLD, BLOCK, ASK_GUARDIAN or ASK_ANALYST. args = {}. why = one short English sentence. Protect the elder without locking them out of their own money.";

def _gen_arbiter(proposals_text: str, state_text: str, fallback_why: str) -> dict | None {
    with _arb_lock {
        _arb_calls.clear();
        why = _llm_arbiter(proposals_text, state_text);
        used = list(_arb_calls)[:2];
    }
    picks = [u for u in used if u in DECISION_TOOLS];
    if not picks {                         # model did not call a tool -> typed Action
        a = _llm_arbiter_action(proposals_text, state_text);
        if a.tool.upper() not in DECISION_TOOLS { return None; }
        picks = [a.tool.upper()];
        used = [picks[0]];
        why = a.why;
    }
    good_why = text_ok(why, "en", 220) and numbers_ok(why, proposals_text + state_text);
    return {"decision": picks[0], "why": why.strip() if good_why else fallback_why, "tools_used": used, "source": "llm"};
}

"""Rule R6 only: {"decision", "why", "tools_used"}."""
def arbiter_decide(proposals: list[dict], state: dict) -> dict {
    fb = fb_arbiter(proposals);
    slim = [{"agent": p.get("agent"), "stance": p.get("stance"), "confidence": p.get("confidence"), "reason": p.get("reason")} for p in proposals];
    proposals_text = json.dumps(slim, ensure_ascii=False, default=as_str);
    state_text = json.dumps(state, ensure_ascii=False, default=as_str, sort_keys=True);
    res = run_llm("arbiter_decide", {"p": proposals_text, "s": state_text},
                  partial(_gen_arbiter, proposals_text, state_text, str(fb["why"])));
    return dict(res) if res else fb;
}

# ==================== Pattern Learner ====================

def _llm_pattern(request_summary: str, scam_answers: list[str]) -> PatternOut by llm(temperature=0.2);
sem _llm_pattern = "A confirmed scam case. Describe it as a reusable scam pattern so other banks can spot the same scam. Keep phrases in their original language (Sinhala, Tamil, English or Singlish).";
sem _llm_pattern.request_summary = "The case (English, may quote other languages).";
sem _llm_pattern.scam_answers = "The victim's answers to the safety questions, any language.";

def _gen_pattern(request_summary: str, scam_answers: list[str]) -> dict | None {
    d = _llm_pattern(request_summary, scam_answers);
    features = [f.strip() for f in d.features if f.strip() and len(f) <= 80][:6];
    phrases = [p.strip() for p in d.phrases if p.strip() and len(p) <= 60][:10];
    if not features { return None; }
    return {"name": d.name.strip()[:60], "features": features, "phrases": phrases};
}

"""New scam pattern from a confirmed case. Name is the fixed name for a known scam type
(so the demo is stable); phrases cover si / ta / en so other victims match too."""
def learn_pattern(request_summary: str, scam_answers: list[str]) -> ScamPatternDraft {
    res = run_llm("learn_pattern", {"s": request_summary, "a": scam_answers}, partial(_gen_pattern, request_summary, scam_answers));
    if not res { return fb_learn_pattern(request_summary, scam_answers); }
    text = request_summary + " " + " ".join(scam_answers);
    kind = case_scam_type(text);
    return ScamPatternDraft(
        name=PATTERN_NAMES.get(kind, str(res["name"])),
        features=list(res["features"]),
        phrases=all_language_phrases(text, kind, list(res["phrases"]))
    );
}
