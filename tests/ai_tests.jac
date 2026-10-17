# Tests: AI functions (B). Smoke tests for the stubs written by A - B extends these.
import from ai.jev { jev_pressure, jev_request_vector, jev_pattern, jev_read_reply, jev_mule_scores }
import from ai.llm_calls { arbiter_decide, scam_questions, guardian_card, analyst_card, debrief }
import from ai.lang { detect_language, scam_keywords_hit }

test "detect language by script" {
    assert detect_language("ආරක්ෂිත ගිණුම") == "si";
    assert detect_language("பாதுகாப்பான கணக்கு") == "ta";
    assert detect_language("safe account ekata") == "en";
}

test "scam keywords in all languages" {
    assert "ආරක්ෂිත ගිණුම" in scam_keywords_hit("මුදල් ආරක්ෂිත ගිණුම වෙත");
    assert "பாதுகாப்பான கணக்கு" in scam_keywords_hit("பாதுகாப்பான கணக்கு");
    assert "safe account ekata" in scam_keywords_hit("Safe account ekata danna");
    assert scam_keywords_hit("I decided to pay the electricity bill") == [];
}

test "jev stubs return the fixed shapes" {
    high = jev_pressure({"on_call": True, "pasted_account": True, "hesitation_ms": 9000, "new_payee": True}, {"reference_text": "safe account"});
    assert high.coached >= 0.7 and high.decision == "HOLD" and high.source == "fallback";
    assert jev_pressure({}, {}).decision == "ALLOW";
    assert jev_request_vector({"amount_ratio": 700.0, "first_time_action": True}).routine_level == 3;
    assert jev_pattern({"reference_text": "CID case"}, ["Fake CID — safe account"]) == "Fake CID — safe account";
    assert jev_pattern({"reference_text": "electricity"}, ["Fake CID — safe account"]) == "NONE";
    assert jev_read_reply("Yes, he says he is CID") == "COACHED";
    assert jev_read_reply("I don't know") == "UNSURE";
    assert jev_mule_scores([{"id": "LDB-77821", "opened_days_ago": 9, "elder_senders": 2}])["LDB-77821"] >= 0.7;
}

test "llm stubs return the fixed shapes" {
    assert arbiter_decide([{"agent": "ROUTINE", "stance": "HOLD", "confidence": 0.8}], {})["decision"] == "HOLD";
    q = scam_questions("fake police", "ta");
    assert q["language"] == "ta" and 2 <= len(q["questions"] as list[str]) <= 3;
    card = guardian_card("x", [], "si");
    assert len(card["lines"] as list[str]) <= 3 and "REJECT" in card["options"];
    assert analyst_card("x", ["a", "b"])["language"] == "en";
    assert len(debrief({}, "en").split("\n")) == 4;
}
