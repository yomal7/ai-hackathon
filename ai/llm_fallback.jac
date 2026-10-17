"""Fixed-text fallbacks for every System 2 (LLM) function (owner: Person B).
Same return shapes as ai/llm_calls.jac, source = "fallback". No network."""

import from ai.types { ScamPatternDraft }
import from ai.fallback { to_float }
import from ai.lang {
    fixed_text, fmt_rs, scam_keywords_hit, scam_type_from_text, keywords_for, ANALYST_TEXT
}

glob PATTERN_NAMES: dict[str, str] = {
    "FAKE_POLICE_SAFE_ACCOUNT": "Fake CID — safe account",
    "FAKE_BANK_STAFF": "Fake bank staff",
    "CUSTOMS_PARCEL_FEE": "Customs parcel fee",
    "ROMANCE": "Romance scam",
    "INVESTMENT_DOUBLE": "Double your money",
    "LOTTERY_FEE": "Lottery fee"
};

"""Button values for the guardian card. C's screen shows the labels with t(key, lang)."""
def guardian_options(lang: str) -> list[str] {
    return ["REJECT", "APPROVE", "CALL"];
}

"""Button values for the analyst card."""
def analyst_options() -> list[str] {
    return ["APPROVE", "KEEP_OPEN"];
}

def fb_scam_questions(lang: str) -> dict {
    return {
        "language": lang,
        "questions": [fixed_text(k, lang) for k in ["sb_q1", "sb_q2", "sb_q3"]],
        "warning": fixed_text("sb_warning", lang),
        "questions_en": [fixed_text(k, "en") for k in ["sb_q1", "sb_q2", "sb_q3"]],
        "warning_en": fixed_text("sb_warning", "en"),
        "source": "fallback"
    };
}

"""Values for the guardian card template; {} if facts has no amount."""
def card_values(facts: dict, lang: str) -> dict {
    if "amount" not in facts { return {}; }
    return {
        "name": facts.get("name", ""),
        "parent": fixed_text("parent_" + str(facts.get("parent", "father")), lang),
        "amount": fmt_rs(to_float(facts["amount"])),
        "others": facts.get("others", 0)
    };
}

def fb_guardian_card(lang: str, facts: dict) -> dict {
    vals = card_values(facts, lang);
    if vals {
        title = fixed_text("gc_title", lang, vals);
        lines = [fixed_text("gc_line_call", lang, vals)];
        if to_float(vals["others"]) > 0 { lines.append(fixed_text("gc_line_others", lang, vals)); }
        lines.append(fixed_text("gc_line_paused", lang));
    } else {
        title = fixed_text("gc_title_generic", lang);
        lines = [fixed_text("gc_line_paused", lang)];
    }
    return {"language": lang, "title": title, "lines": lines[:3], "options": guardian_options(lang), "source": "fallback"};
}

def fb_analyst_card(summary: str, evidence: list[str]) -> dict {
    lines = [e for e in evidence if e][:3] or [ANALYST_TEXT["ac_no_evidence"]];
    return {
        "language": "en",
        "title": ANALYST_TEXT["ac_title"].replace("{summary}", summary),
        "lines": lines,
        "options": analyst_options(),
        "source": "fallback"
    };
}

def debrief_values(case_info: dict) -> dict {
    return {
        "name": case_info.get("name", ""),
        "amount": fmt_rs(to_float(case_info.get("amount", 0))),
        "seconds": case_info.get("seconds", 0),
        "guardian": case_info.get("guardian", ""),
        "recovered": fmt_rs(to_float(case_info.get("recovered", 0)))
    };
}

def fb_debrief(case_info: dict, lang: str) -> str {
    vals = debrief_values(case_info);
    return "\n".join([fixed_text(k, lang, vals) for k in ["db_1", "db_2", "db_3", "db_4"]]);
}

def fb_arbiter(proposals: list[dict]) -> dict {
    holders = [str(p.get("agent", "?")) for p in proposals
               if p.get("stance") == "HOLD" and to_float(p.get("confidence", 0)) >= 0.6];
    if holders {
        return {"decision": "HOLD", "why": "Agents " + ", ".join(holders) + " want a hold, so the payment is paused for a check.",
                "tools_used": [], "source": "fallback"};
    }
    return {"decision": "STEP_UP", "why": "Agents disagree, so the bank asks for an extra check before paying.",
            "tools_used": [], "source": "fallback"};
}

"""Scam type of a case; FAKE_POLICE_SAFE_ACCOUNT if no keyword is found."""
def case_scam_type(text: str) -> str {
    kind = scam_type_from_text(text);
    return "FAKE_POLICE_SAFE_ACCOUNT" if kind == "NONE" else kind;
}

"""Keyword hits + all keywords of the scam type in si / ta / en, so other victims match too."""
def all_language_phrases(text: str, kind: str, extra: list[str]) -> list[str] {
    phrases: list[str] = [];
    for p in extra + scam_keywords_hit(text) + keywords_for(kind) {
        if p and p not in phrases { phrases.append(p); }
    }
    return phrases;
}

def fb_learn_pattern(request_summary: str, scam_answers: list[str]) -> ScamPatternDraft {
    text = request_summary + " " + " ".join(scam_answers);
    kind = case_scam_type(text);
    return ScamPatternDraft(
        name=PATTERN_NAMES.get(kind, kind),
        features=["on a phone call", "new payee", "amount far above normal", "caller claims authority", "told to keep it secret"],
        phrases=all_language_phrases(text, kind, [])
    );
}
