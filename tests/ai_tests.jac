"""Tests for ai/ stubs and fallbacks (owner: Person B). Run: jac test tests/ai_tests.jac"""

import os;
import time;
import from ai.types { RiskVector }
import from ai.jev { jev_request_vector, jev_pressure, jev_pattern, jev_read_reply, jev_mule_scores, jev_call, jev_last }
import from ai.llm_calls { scam_questions, guardian_card, analyst_card, debrief, arbiter_decide, learn_pattern }
import from ai.lang { detect_language, scam_keywords_hit, script_clean }
import from ai.llm_guard { text_ok, numbers_ok, run_llm }

# These tests check the code fallbacks, so they run with NO Jev or LLM key (no network).
with entry {
    for k in ["TYPESAFE_API_KEY", "GEMINI_API_KEY", "GOOGLE_API_KEY", "OPENAI_API_KEY", "ANTHROPIC_API_KEY"] {
        os.environ[k] = "";
    }
}

glob SEEYA_HABITS: list[dict] = [
    {"action": "BILL_PAY", "typical_amount": 4500, "hour_from": 9, "hour_to": 18, "count": 40},
    {"action": "TRANSFER", "typical_amount": 6000, "hour_from": 9, "hour_to": 18, "count": 12}
];

glob SCAM_TEL: dict = {"on_call": True, "remote_app": False, "pasted_account": True, "hesitation_ms": 6000,
                       "backtracks": 2, "typing_change": True, "new_payee": True};

def scam_state(ref: str) -> dict {
    return {"action": "BREAK_FD", "amount": 4200000, "reference_text": ref,
            "telemetry": SCAM_TEL, "habits": SEEYA_HABITS};
}

test "S1 normal bill is ALLOW, routine 0" {
    rv = jev_request_vector({"action": "BILL_PAY", "amount": 4500, "reference_text": "CEB electricity",
                             "telemetry": {"on_call": False}, "habits": SEEYA_HABITS});
    assert isinstance(rv, RiskVector);
    assert rv.source == "fallback";
    assert rv.decision == "ALLOW";
    assert rv.routine_level == 0;
    assert rv.coached < 0.3;
}

test "S3 Sinhala scam is HOLD, never-seen, fake police" {
    rv = jev_request_vector(scam_state("ආරක්ෂිත ගිණුම"));
    assert rv.coached >= 0.9;
    assert rv.routine_level == 3;
    assert rv.scam_type == "FAKE_POLICE_SAFE_ACCOUNT";
    assert rv.decision == "HOLD";
}

test "Sinhala and Tamil scam text alone gives coached >= 0.7" {
    for ref in ["ආරක්ෂිත ගිණුම", "பாதுகாப்பான கணக்கு", "safe account ekata"] {
        rv = jev_request_vector({"action": "TRANSFER", "amount": 5000, "reference_text": ref,
                                 "telemetry": {}, "habits": SEEYA_HABITS});
        assert rv.coached >= 0.7;
    }
}

test "pressure climbs as signals turn on" {
    req = {"action": "BREAK_FD", "amount": 4200000, "reference_text": ""};
    p0 = jev_pressure({"on_call": False}, req).coached;
    p1 = jev_pressure({"on_call": True}, req).coached;
    p2 = jev_pressure({"on_call": True, "pasted_account": True}, req).coached;
    p3 = jev_pressure(SCAM_TEL, {"action": "BREAK_FD", "amount": 4200000, "reference_text": "safe account"}).coached;
    assert p0 < p1 and p1 < p2 and p2 < p3;
    assert p3 <= 0.98;
}

test "S5 hospital at 1 AM is STEP_UP not HOLD" {
    rv = jev_request_vector({"action": "TRANSFER", "amount": 180000, "reference_text": "Kandy General Hospital",
                             "telemetry": {"on_call": False}, "habits": SEEYA_HABITS});
    assert rv.decision == "STEP_UP";
}

test "pattern match: empty list is NONE; Tamil S4 matches learned pattern" {
    assert jev_pattern({"reference_text": "பாதுகாப்பான கணக்கு"}, []) == "NONE";
    assert jev_pattern({"reference_text": "பாதுகாப்பான கணக்கு"}, ["Fake CID — safe account"]) == "Fake CID — safe account";
    assert jev_pattern({"reference_text": "CEB electricity"}, ["Fake CID — safe account"]) == "NONE";
}

test "read reply in 3 languages" {
    assert jev_read_reply("Yes, he says he is CID") == "COACHED";
    assert jev_read_reply("ඔව්") == "COACHED";
    assert jev_read_reply("ஆம்") == "COACHED";
    assert jev_read_reply("no") == "NOT_COACHED";
    assert jev_read_reply("නැහැ") == "NOT_COACHED";
    assert jev_read_reply("இல்லை") == "NOT_COACHED";
    assert jev_read_reply("I decide myself") == "UNSURE";
}

test "mule scores: new fast account high, old shop low" {
    s = jev_mule_scores([
        {"id": "CDB-40213", "kind": "PERSONAL", "opened_days_ago": 12, "distinct_senders": 3, "from_flagged": True},
        {"id": "LDB-55555", "kind": "SHOP", "opened_days_ago": 3000, "distinct_senders": 40, "minutes_to_move_on": 20}
    ]);
    assert s["CDB-40213"] >= 0.8;
    assert s["LDB-55555"] <= 0.3;
}

test "LLM stubs return fixed texts in the asked language" {
    q = scam_questions("x", "si");
    assert q["language"] == "si" and len(list(q["questions"])) == 3;
    assert detect_language(str(q["questions"][0])) == "si";
    assert detect_language(str(scam_questions("x", "ta")["warning"])) == "ta";
    c = guardian_card("x", [], "si", {"name": "Siriwardena", "parent": "father", "amount": 4200000, "others": 2});
    assert len(list(c["lines"])) == 3 and "4,200,000" in c["title"];
    assert [o["value"] for o in c["options"]] == ["REJECT", "APPROVE", "CALL"];
    assert len(list(guardian_card("x", [], "ta")["lines"])) <= 3;
    a = analyst_card("Freeze CDB-40213?", ["e1", "e2", "e3", "e4"]);
    assert a["language"] == "en" and len(list(a["lines"])) == 3;
    assert len(debrief({"name": "Seeya", "amount": 4200000}, "ta").split("\n")) == 4;
}

test "arbiter stub and pattern learner" {
    assert arbiter_decide([{"agent": "ROUTINE", "stance": "HOLD", "confidence": 0.7}], {})["decision"] == "HOLD";
    assert arbiter_decide([{"agent": "ADVOCATE", "stance": "ALLOW", "confidence": 0.8}], {})["decision"] == "STEP_UP";
    p = learn_pattern("on call, safe account, CID", ["Yes, he says he is CID"]);
    assert p.name == "Fake CID — safe account";
    assert "பாதுகாப்பான கணக்கு" in p.phrases and "ආරක්ෂිත ගිණුම" in p.phrases;
}

test "keywords in every language" {
    assert "safe account" in scam_keywords_hit("move to SAFE ACCOUNT now");
    assert len(scam_keywords_hit("police case eka")) > 0;
    assert scam_keywords_hit("I decide to pay CEB") == [];
}

test "no key: every Jev function returns its type with source fallback" {
    os.environ["TYPESAFE_API_KEY"] = "";
    assert jev_call({"a": 1}, {"q": {"type": "noul", "instructions": "x?"}}) is None;
    rv = jev_request_vector(scam_state("safe account"));
    assert isinstance(rv, RiskVector) and rv.source == "fallback";
    assert jev_pressure(SCAM_TEL, {"action": "BREAK_FD", "amount": 4200000}).source == "fallback";
    assert isinstance(jev_pattern({"reference_text": "x"}, ["Fake CID — safe account"]), str);
    assert jev_last("jev_pattern")["source"] == "fallback";
    assert jev_read_reply("yes") in ["COACHED", "NOT_COACHED", "UNSURE"];
    assert jev_last("jev_read_reply")["source"] == "fallback";
    s = jev_mule_scores([{"id": "A-1", "opened_days_ago": 5}]);
    assert isinstance(s["A-1"], float) and jev_last("jev_mule_scores")["source"] == "fallback";
    assert jev_mule_scores([]) == {};
}

test "timeout: a slow Jev answer falls back fast" {
    os.environ["TYPESAFE_API_KEY"] = "test-dummy-key";
    os.environ["JEV_TIMEOUT_MS"] = "1";
    t0 = time.perf_counter();
    rv = jev_request_vector(scam_state("timeout test " + str(t0)));   # unique state: never cached
    ms = int((time.perf_counter() - t0) * 1000);
    os.environ["TYPESAFE_API_KEY"] = "";
    os.environ["JEV_TIMEOUT_MS"] = "800";
    assert rv.source == "fallback";
    assert rv.decision == "HOLD";
    assert ms < 300, f"took {ms} ms";
}

test "LLM answer checks: language, length, script, numbers" {
    assert text_ok("ඔබ දැන් දුරකථනයෙන් කතා කරනවාද?", "si");
    assert not text_ok("Are you on the phone?", "si");                 # wrong language
    assert not text_ok("", "en") and not text_ok(None, "en");
    assert not text_ok("x" * 300, "en", 220);                           # too long
    assert not script_clean("ரக்ஷகா രക്ഷ", "ta");                        # Malayalam inside Tamil
    assert script_clean("ரக்ஷகா 1 நொடியில்", "ta");
    assert numbers_ok("Rs 4,200,000 and 2 elders", "amount 4200000, others 2");
    assert not numbers_ok("Rs 5,000,000", "amount 4200000");             # LLM invented a number
}

def _never_called() -> dict {
    return {"a": 1};
}

test "no LLM key: run_llm returns None and functions use fixed text" {
    assert run_llm("x", {"a": 1}, _never_called) is None;
    assert scam_questions("x", "ta")["source"] == "fallback";
    assert arbiter_decide([], {})["source"] == "fallback";
}
