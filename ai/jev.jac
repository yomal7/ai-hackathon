# System 1 (Jev) calls. STUB written by A: simple code rules, source="fallback" - B owns and replaces this file (B)
import re;
import time;
import from ai.types { RiskVector }
import from ai.lang { scam_keywords_hit, scam_type_of }

"""Milliseconds since t0 (a perf_counter value)."""
def _ms_since(t0: float) -> int {
    return int((time.perf_counter() - t0) * 1000);
}

"""Clamp a score into 0..1 and round to 2 decimals."""
def _clamp01(x: float) -> float {
    v = 1.0 if x > 1.0 else (0.0 if x < 0.0 else x);
    return int(v * 100 + 0.5) / 100.0;  # round(x, 2) trips the type checker
}

"""Map a 0..1 risk score to a Jev decision."""
def _decision_for(score: float) -> str {
    if score >= 0.7 {
        return "HOLD";
    }
    if score >= 0.4 {
        return "STEP_UP";
    }
    return "ALLOW";
}

"""Whole-request reading. state may hold si/ta/en/Singlish text."""
def jev_request_vector(state: dict) -> RiskVector {
    t0 = time.perf_counter();
    hits = scam_keywords_hit(str(state.get("reference_text", "")));
    ratio = float(state.get("amount_ratio", 1.0) as float);
    level = 0;
    if ratio >= 3.0 {
        level = 1;
    }
    if ratio >= 10.0 {
        level = 2;
    }
    if state.get("first_time_action", False) {
        level = 3;
    }
    coached = 0.6 if hits else 0.0;
    coached = _clamp01(coached + float(state.get("pressure", 0) as float) / 250.0);
    return RiskVector(
        coached=coached,
        routine_level=level,
        scam_type=scam_type_of(hits),
        decision=_decision_for(max(coached, level / 3.0)),
        ms=_ms_since(t0),
        source="fallback"
    );
}

"""Coercion Sentinel live meter: telemetry signals -> coached score."""
def jev_pressure(telemetry: dict, request: dict) -> RiskVector {
    t0 = time.perf_counter();
    score = 0.0;
    if telemetry.get("on_call", False) {
        score += 0.30;
    }
    if telemetry.get("remote_app", False) {
        score += 0.25;
    }
    if telemetry.get("pasted_account", False) {
        score += 0.15;
    }
    if int(telemetry.get("hesitation_ms", 0)) >= 8000 {
        score += 0.10;
    }
    if int(telemetry.get("backtracks", 0)) >= 3 {
        score += 0.08;
    }
    if telemetry.get("typing_change", False) {
        score += 0.07;
    }
    if telemetry.get("new_payee", False) {
        score += 0.05;
    }
    hits = scam_keywords_hit(str(request.get("reference_text", "")));
    if hits {
        score += 0.20;
    }
    coached = _clamp01(score);
    return RiskVector(
        coached=coached,
        routine_level=0,
        scam_type=scam_type_of(hits),
        decision=_decision_for(coached),
        ms=_ms_since(t0),
        source="fallback"
    );
}

"""Pattern name that matches the state, or "NONE"."""
def jev_pattern(state: dict, pattern_names: list[str]) -> str {
    kind = scam_type_of(scam_keywords_hit(str(state.get("reference_text", ""))));
    if kind == "NONE" {
        return "NONE";
    }
    # Fallback: a learned pattern whose name mentions the same scam words
    clues = {"FAKE_POLICE_SAFE_ACCOUNT": ["cid", "police", "safe account"]}.get(kind, [kind.lower()]);
    for name in pattern_names {
        for c in clues {
            if c in name.lower() {
                return name;
            }
        }
    }
    return "NONE";
}

"""True if word is in text (whole word for English, substring for si/ta)."""
def _has_word(low: str, w: str) -> bool {
    if w.isascii() {
        return re.search(r"\b" + re.escape(w) + r"\b", low) is not None;
    }
    return w in low;
}

"""Read the elder's reply (any language): COACHED / NOT_COACHED / UNSURE."""
def jev_read_reply(text: str) -> str {
    low = text.lower();
    # si / ta words: to be checked by a native speaker
    coached = ["yes", "cid", "police", "he says", "told me", "safe account", "ඔව්", "පොලිසිය", "ஆம்", "காவல்துறை"];
    not_coached = ["no", "nobody", "my own", "නැහැ", "නෑ", "இல்லை"];
    for w in coached {
        if _has_word(low, w) {
            return "COACHED";
        }
    }
    for w in not_coached {
        if _has_word(low, w) {
            return "NOT_COACHED";
        }
    }
    return "UNSURE";
}

"""Mule score 0..1 per account dict {id, opened_days_ago, kind, elder_senders, fast_onward}."""
def jev_mule_scores(accounts: list[dict]) -> dict {
    scores: dict[str, float] = {};
    for a in accounts {
        s = 0.0;
        if int(a.get("opened_days_ago", 9999)) < 30 {
            s += 0.4;
        }
        if a.get("kind", "") == "MULE_SUSPECT" {
            s += 0.2;
        }
        if int(a.get("elder_senders", 0)) >= 2 {
            s += 0.3;
        }
        if a.get("fast_onward", False) {
            s += 0.1;
        }
        scores[str(a.get("id", ""))] = _clamp01(s);
    }
    return scores;
}
