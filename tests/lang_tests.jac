"""Tests for ai/lang.jac (owner: Person B). Run: jac test tests/lang_tests.jac"""

import re;
import from ai.lang {
    FIXED, ANALYST_TEXT, SCAM_KEYWORDS, fixed_text, detect_language, scam_keywords_hit, scam_type_from_text
}

def placeholders(text: str) -> set[str] {
    return set(re.findall("\\{(\\w+)\\}", text));
}

test "every fixed text exists in si, ta and en" {
    for (key, texts) in FIXED.items() {
        for lang in ["si", "ta", "en"] {
            assert lang in texts, f"{key} has no {lang}";
            assert texts[lang].strip() != "", f"{key}/{lang} is empty";
        }
        assert len(texts) == 3, f"{key} has extra languages";
    }
}

test "each fixed text is written in the right script" {
    for (key, texts) in FIXED.items() {
        for lang in ["si", "ta", "en"] {
            assert detect_language(texts[lang]) == lang, f"{key}/{lang} is in the wrong script";
        }
    }
}

test "placeholders are the same in all 3 languages" {
    for (key, texts) in FIXED.items() {
        want = placeholders(texts["en"]);
        assert placeholders(texts["si"]) == want, f"{key}/si placeholders differ";
        assert placeholders(texts["ta"]) == want, f"{key}/ta placeholders differ";
    }
}

test "analyst texts are English" {
    for (_, text) in ANALYST_TEXT.items() {
        assert detect_language(text) == "en";
    }
}

test "fixed_text fills values and falls back to English" {
    assert fixed_text("gc_line_others", "en", {"others": 2}) == "2 other elders sent money to this account today.";
    assert "2" in fixed_text("gc_line_others", "ta", {"others": 2});
    assert fixed_text("sb_q1", "fr") == fixed_text("sb_q1", "en");
    assert "{name}" in fixed_text("gc_line_call", "si");       # missing value stays visible, no crash
    assert fixed_text("no_such_key", "si") == "no_such_key";
}

test "detect_language by script" {
    assert detect_language("ආරක්ෂිත ගිණුම") == "si";
    assert detect_language("பாதுகாப்பான கணக்கு") == "ta";
    assert detect_language("safe account ekata") == "en";       # Singlish
    assert detect_language("police case irukku") == "en";       # Tanglish
    assert detect_language("") == "en";
    assert detect_language("OK ඔව් ok") == "si";               # mixed text: native script wins
}

test "scam keywords hit in English" {
    hits = scam_keywords_hit("This is CID. Move money to a Government Account. Don't tell anyone.");
    assert "cid" in hits and "government account" in hits and "don't tell anyone" in hits;
    assert scam_keywords_hit("I will decide on the electricity bill") == [];   # "cid" inside "decide" is not a hit
}

test "scam keywords hit in Sinhala" {
    assert "ආරක්ෂිත ගිණුම" in scam_keywords_hit("ඔබේ මුදල් ආරක්ෂිත ගිණුමට දාන්න");
    assert "අත්අඩංගුවට" in scam_keywords_hit("අද ඔබව අත්අඩංගුවට ගන්නවා");
}

test "scam keywords hit in Tamil" {
    assert "பாதுகாப்பான கணக்கு" in scam_keywords_hit("பணத்தை பாதுகாப்பான கணக்குக்கு அனுப்புங்கள்");
    assert "கைது" in scam_keywords_hit("இன்று உங்களை கைது செய்வோம்");
}

test "scam keywords hit in Singlish and Tanglish" {
    assert "safe account ekata" in scam_keywords_hit("Salli safe account ekata danna");
    assert "police case eka" in scam_keywords_hit("oyage police case eka");
    assert "police case irukku" in scam_keywords_hit("unga mela police case irukku");
    assert "customs fee kattanum" in scam_keywords_hit("parcel vandhiruku, customs fee kattanum");
}

test "scam type from text in every language" {
    assert scam_type_from_text("ආරක්ෂිත ගිණුම") == "FAKE_POLICE_SAFE_ACCOUNT";
    assert scam_type_from_text("காவல்துறை சொன்னது") == "FAKE_POLICE_SAFE_ACCOUNT";
    assert scam_type_from_text("customs parcel fee") == "CUSTOMS_PARCEL_FEE";
    assert scam_type_from_text("ලොතරැයි ත්‍යාගය") == "LOTTERY_FEE";
    assert scam_type_from_text("CEB electricity bill") == "NONE";
}

test "keyword lists are not empty" {
    for (kind, words) in SCAM_KEYWORDS.items() {
        assert len(words) > 0, kind;
    }
}
