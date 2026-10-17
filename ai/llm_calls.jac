"""System 2 — LLM (by llm()) calls (owner: Person B).
M1: STUBS. Every function returns fixed texts from ai/lang.jac (source = "fallback").
M4 adds the real by llm() call in front; signatures never change.
The LLM never sets numbers: numbers come from code or Jev."""

import from ai.types { ScamPatternDraft }
import from ai.fallback { to_float }
import from ai.lang {
    fixed_text, safe_lang, fmt_rs, scam_keywords_hit, scam_type_from_text, keywords_for, ANALYST_TEXT
}

def _options(lang: str) -> list[dict] {
    return [
        {"value": "REJECT", "label": fixed_text("opt_reject", lang)},
        {"value": "APPROVE", "label": fixed_text("opt_approve", lang)},
        {"value": "CALL", "label": fixed_text("opt_call", lang)}
    ];
}

# ---------- Scam-Breaker ----------

"""{"language", "questions": [2-3 str], "warning"} in the elder's language."""
def scam_questions(situation: str, language: str) -> dict {
    lang = safe_lang(language);
    return {
        "language": lang,
        "questions": [fixed_text(k, lang) for k in ["sb_q1", "sb_q2", "sb_q3"]],
        "warning": fixed_text("sb_warning", lang),
        "source": "fallback"
    };
}

# ---------- cards ----------

"""Guardian card: {"language", "title", "lines" (max 3), "options"}.
facts (optional): {"name", "parent": "father"|"mother", "amount", "others"} fill the template."""
def guardian_card(summary: str, evidence: list[str], language: str, facts: dict | None = None) -> dict {
    lang = safe_lang(language);
    f = facts or {};
    if "amount" in f {
        vals = {
            "name": f.get("name", ""),
            "parent": fixed_text("parent_" + str(f.get("parent", "father")), lang),
            "amount": fmt_rs(to_float(f["amount"])),
            "others": f.get("others", 0)
        };
        title = fixed_text("gc_title", lang, vals);
        lines = [fixed_text("gc_line_call", lang, vals)];
        if to_float(vals["others"]) > 0 { lines.append(fixed_text("gc_line_others", lang, vals)); }
        lines.append(fixed_text("gc_line_paused", lang));
    } else {
        title = fixed_text("gc_title_generic", lang);
        lines = [fixed_text("gc_line_paused", lang)];
    }
    return {"language": lang, "title": title, "lines": lines[:3], "options": _options(lang), "source": "fallback"};
}

"""Analyst card (English): same shape as guardian_card; options APPROVE / KEEP_OPEN."""
def analyst_card(summary: str, evidence: list[str]) -> dict {
    lines = [e for e in evidence if e][:3] or [ANALYST_TEXT["ac_no_evidence"]];
    return {
        "language": "en",
        "title": ANALYST_TEXT["ac_title"].replace("{summary}", summary),
        "lines": lines,
        "options": [
            {"value": "APPROVE", "label": ANALYST_TEXT["opt_approve_freeze"]},
            {"value": "KEEP_OPEN", "label": ANALYST_TEXT["opt_keep_open"]}
        ],
        "source": "fallback"
    };
}

# ---------- story ----------

"""4 short lines. case_info keys: name, amount, seconds, guardian, recovered.
(Named case_info because `case` is a Jac keyword; call it positionally.)"""
def debrief(case_info: dict, language: str) -> str {
    lang = safe_lang(language);
    vals = {
        "name": case_info.get("name", ""),
        "amount": fmt_rs(to_float(case_info.get("amount", 0))),
        "seconds": case_info.get("seconds", 0),
        "guardian": case_info.get("guardian", ""),
        "recovered": fmt_rs(to_float(case_info.get("recovered", 0)))
    };
    return "\n".join([fixed_text(k, lang, vals) for k in ["db_1", "db_2", "db_3", "db_4"]]);
}

# ---------- Arbiter (rule R6 only) ----------

"""{"decision", "why", "tools_used"}. Stub: any HOLD with confidence >= 0.6 -> HOLD, else STEP_UP."""
def arbiter_decide(proposals: list[dict], state: dict) -> dict {
    holders = [p.get("agent", "?") for p in proposals
               if p.get("stance") == "HOLD" and to_float(p.get("confidence", 0)) >= 0.6];
    if holders {
        return {"decision": "HOLD", "why": "Agents " + ", ".join(holders) + " want a hold, so the payment is paused for a check.",
                "tools_used": [], "source": "fallback"};
    }
    return {"decision": "STEP_UP", "why": "Agents disagree, so the bank asks for an extra check before paying.",
            "tools_used": [], "source": "fallback"};
}

# ---------- Pattern Learner ----------

glob PATTERN_NAMES: dict[str, str] = {
    "FAKE_POLICE_SAFE_ACCOUNT": "Fake CID — safe account",
    "FAKE_BANK_STAFF": "Fake bank staff",
    "CUSTOMS_PARCEL_FEE": "Customs parcel fee",
    "ROMANCE": "Romance scam",
    "INVESTMENT_DOUBLE": "Double your money",
    "LOTTERY_FEE": "Lottery fee"
};

"""New scam pattern from a confirmed case. Phrases cover si / ta / en so other victims match too."""
def learn_pattern(request_summary: str, scam_answers: list[str]) -> ScamPatternDraft {
    text = request_summary + " " + " ".join(scam_answers);
    kind = scam_type_from_text(text);
    if kind == "NONE" { kind = "FAKE_POLICE_SAFE_ACCOUNT"; }
    phrases: list[str] = scam_keywords_hit(text);
    for p in keywords_for(kind) {
        if p not in phrases { phrases.append(p); }
    }
    return ScamPatternDraft(
        name=PATTERN_NAMES.get(kind, kind),
        features=["on a phone call", "new payee", "amount far above normal", "caller claims authority", "told to keep it secret"],
        phrases=phrases
    );
}
