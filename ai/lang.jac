"""Languages for Rakshaka (owner: Person B): script detection, scam keywords,
and fixed fallback texts in Sinhala (si), Tamil (ta) and English (en)."""

import re;

# ---------- language detection (plain code, by Unicode script) ----------

def detect_language(text: str) -> str {
    si = 0;
    ta = 0;
    for ch in (text or "") {
        c = ord(ch);
        if 0x0D80 <= c and c <= 0x0DFF { si += 1; }
        elif 0x0B80 <= c and c <= 0x0BFF { ta += 1; }
    }
    if si == 0 and ta == 0 { return "en"; }    # Singlish / Tanglish count as "en"
    return "si" if si >= ta else "ta";
}

def safe_lang(lang: str) -> str {
    return lang if lang in ["si", "ta", "en"] else "en";
}

# ---------- scam keywords, grouped by scam type ----------
# Sinhala / Tamil / Singlish / Tanglish lists: to be checked by a native speaker.
glob SCAM_KEYWORDS: dict[str, list[str]] = {
    "FAKE_POLICE_SAFE_ACCOUNT": [
        "safe account", "cid", "police", "arrest", "warrant", "don't tell anyone",
        "dont tell anyone", "government account",
        "ආරක්ෂිත ගිණුම", "පොලිසිය", "පොලිස්", "සීඅයිඩී", "අත්අඩංගුවට",          # si
        "பாதுகாப்பான கணக்கு", "காவல்துறை", "கைது", "போலீஸ்", "சிஐடி",            # ta
        "police case eka", "safe account ekata", "cid eken", "police case irukku"  # Singlish / Tanglish
    ],
    "CUSTOMS_PARCEL_FEE": [
        "customs", "parcel fee", "රේගුව", "சுங்கம்", "customs fee kattanum"
    ],
    "LOTTERY_FEE": ["lottery", "prize", "ලොතරැයි", "லாட்டரி"],
    "INVESTMENT_DOUBLE": ["double your money"],
    "FAKE_BANK_STAFF": ["bank officer", "bank staff", "verify your account"]
};

# Reply words for the Scam-Breaker. To be checked by a native speaker.
glob YES_WORDS: list[str] = ["yes", "yeah", "ow", "ou", "aam", "ama", "ඔව්", "ஆம்", "ஆமா", "ஆமாம்"];
glob NO_WORDS: list[str] = ["no", "nope", "nobody", "naha", "nae", "illai", "illa",
                            "නැහැ", "නෑ", "இல்லை", "இல்ல"];

def _is_latin(word: str) -> bool {
    return detect_language(word) == "en";
}

"""True if kw appears in text. Latin words must match whole words ("cid" not in "decide")."""
def has_word(text: str, kw: str) -> bool {
    low = (text or "").lower();
    if _is_latin(kw) {
        return re.search("(?<![a-z])" + re.escape(kw.lower()) + "(?![a-z])", low) is not None;
    }
    return kw in low;
}

def scam_keywords_hit(text: str) -> list[str] {
    hits: list[str] = [];
    for (_, words) in SCAM_KEYWORDS.items() {
        for kw in words {
            if has_word(text, kw) and kw not in hits { hits.append(kw); }
        }
    }
    return hits;
}

"""Scam type with the most keyword hits, or NONE."""
def scam_type_from_text(text: str) -> str {
    best = "NONE";
    best_n = 0;
    for (kind, words) in SCAM_KEYWORDS.items() {
        n = len([kw for kw in words if has_word(text, kw)]);
        if n > best_n { best = kind; best_n = n; }
    }
    return best;
}

def keywords_for(scam_type: str) -> list[str] {
    return SCAM_KEYWORDS.get(scam_type, []);
}

# ---------- fixed fallback texts (si / ta / en) ----------
# All si / ta strings: to be checked by a native speaker.
glob FIXED: dict[str, dict[str, str]] = {
    # Scam-Breaker questions
    "sb_q1": {
        "en": "Is someone on the phone telling you to do this?",
        "si": "දැන් කවුරුහරි දුරකථනයෙන් ඔබට මෙය කරන්න කියනවාද?",
        "ta": "யாராவது இப்போது தொலைபேசியில் இதைச் செய்யச் சொல்கிறார்களா?"
    },
    "sb_q2": {
        "en": "Did they say they are police, CID or bank staff?",
        "si": "ඔවුන් පොලිසියෙන්, සීඅයිඩී එකෙන් හෝ බැංකුවෙන් කියලා කිව්වාද?",
        "ta": "அவர்கள் தங்களை காவல்துறை, சிஐடி அல்லது வங்கி ஊழியர் என்று சொன்னார்களா?"
    },
    "sb_q3": {
        "en": "Did they tell you not to tell your family?",
        "si": "මේ ගැන පවුලේ අයට කියන්න එපා කියලා ඔවුන් කිව්වාද?",
        "ta": "இதைப் பற்றி உங்கள் குடும்பத்தினரிடம் சொல்ல வேண்டாம் என்று சொன்னார்களா?"
    },
    "sb_warning": {
        "en": "Police and banks never ask you to move money to a safe account. Please stop and talk to your family.",
        "si": "පොලිසිය හෝ බැංකු කිසිම දවසක ඔබේ මුදල් 'ආරක්ෂිත ගිණුමකට' දාන්න කියන්නේ නැහැ. කරුණාකර නවතින්න, ඔබේ පවුලේ අය එක්ක කතා කරන්න.",
        "ta": "காவல்துறையோ வங்கியோ ஒருபோதும் பணத்தை 'பாதுகாப்பான கணக்கிற்கு' மாற்றச் சொல்லாது. தயவுசெய்து நிறுத்தி, உங்கள் குடும்பத்தினருடன் பேசுங்கள்."
    },
    "sb_guardian_asked": {
        "en": "We have asked {guardian} to check this payment with you. Please wait.",
        "si": "මෙම ගෙවීම ඔබ සමඟ පරීක්ෂා කරන්න අපි {guardian}ට කිව්වා. කරුණාකර ටිකක් ඉන්න.",
        "ta": "இந்தப் பணப்பரிமாற்றத்தை உங்களுடன் சரிபார்க்க {guardian} அவர்களிடம் கேட்டுள்ளோம். தயவுசெய்து காத்திருங்கள்."
    },
    # Guardian card
    "parent_father": {"en": "father", "si": "තාත්තා", "ta": "அப்பா"},
    "parent_mother": {"en": "mother", "si": "අම්මා", "ta": "அம்மா"},
    "gc_title": {
        "en": "Please check: your {parent} is sending Rs {amount}",
        "si": "කරුණාකර බලන්න: ඔබේ {parent} රු. {amount}ක් යවන්න හදනවා",
        "ta": "தயவுசெய்து பாருங்கள்: உங்கள் {parent} ரூ. {amount} அனுப்புகிறார்"
    },
    "gc_title_generic": {
        "en": "Please check a payment from your family",
        "si": "කරුණාකර ඔබේ පවුලේ අයෙකුගේ ගෙවීමක් බලන්න",
        "ta": "தயவுசெய்து உங்கள் குடும்பத்தினரின் ஒரு பணப்பரிமாற்றத்தைப் பாருங்கள்"
    },
    "gc_line_call": {
        "en": "{name} is trying to send Rs {amount} to a new account while on a phone call.",
        "si": "{name} දුරකථන ඇමතුමක සිටිමින් අලුත් ගිණුමකට රු. {amount}ක් යවන්න හදනවා.",
        "ta": "{name} தொலைபேசியில் பேசிக்கொண்டே புதிய கணக்கிற்கு ரூ. {amount} அனுப்ப முயல்கிறார்."
    },
    "gc_line_others": {
        "en": "{others} other elders sent money to this account today.",
        "si": "අද තවත් වැඩිහිටියන් {others} දෙනෙක් මේ ගිණුමට මුදල් යැව්වා.",
        "ta": "இன்று மேலும் {others} முதியவர்கள் இந்தக் கணக்கிற்கு பணம் அனுப்பியுள்ளனர்."
    },
    "gc_line_paused": {
        "en": "The bank has paused it for safety.",
        "si": "ආරක්ෂාව සඳහා බැංකුව එය නතර කර තිබෙනවා.",
        "ta": "பாதுகாப்பிற்காக வங்கி இதை நிறுத்தி வைத்துள்ளது."
    },
    "opt_reject": {"en": "Reject", "si": "ප්‍රතික්ෂේප කරන්න", "ta": "நிராகரிக்கவும்"},
    "opt_approve": {"en": "Approve", "si": "අනුමත කරන්න", "ta": "அனுமதிக்கவும்"},
    "opt_call": {"en": "Call now", "si": "දැන් කතා කරන්න", "ta": "இப்போதே அழைக்கவும்"},
    # Debrief (4 lines)
    "db_1": {
        "en": "A caller pretending to be police told {name} to move Rs {amount} to a 'safe account'.",
        "si": "පොලිසිය ලෙස පෙනී සිටි අයෙක් රු. {amount}ක් 'ආරක්ෂිත ගිණුමකට' දාන්න කියා {name}ට කිව්වා.",
        "ta": "காவல்துறை போல நடித்த ஒருவர் ரூ. {amount} பணத்தை 'பாதுகாப்பான கணக்கிற்கு' மாற்றச் சொல்லி {name} அவர்களிடம் கூறினார்."
    },
    "db_2": {
        "en": "Rakshaka noticed the pressure and paused the payment in {seconds} seconds.",
        "si": "රක්ෂක එම පීඩනය හඳුනාගෙන තත්පර {seconds}කින් ගෙවීම නතර කළා.",
        "ta": "ரக்ஷகா அந்த அழுத்தத்தைக் கவனித்து {seconds} வினாடிகளில் பணப்பரிமாற்றத்தை நிறுத்தியது."
    },
    "db_3": {
        "en": "{guardian} checked and said no. Rs {amount} stayed safe.",
        "si": "{guardian} පරීක්ෂා කර එය ප්‍රතික්ෂේප කළා. රු. {amount} ආරක්ෂිතව තිබෙනවා.",
        "ta": "{guardian} சரிபார்த்து வேண்டாம் என்றார். ரூ. {amount} பாதுகாப்பாக உள்ளது."
    },
    "db_4": {
        "en": "The bank network learned this scam and recovered Rs {recovered} for another elder.",
        "si": "බැංකු ජාලය මෙම වංචාව ඉගෙනගෙන තවත් වැඩිහිටියෙකුට රු. {recovered}ක් නැවත ලබා දුන්නා.",
        "ta": "வங்கி வலையமைப்பு இந்த மோசடியைக் கற்றுக்கொண்டு இன்னொரு முதியவருக்கு ரூ. {recovered} மீட்டுக் கொடுத்தது."
    }
};

# Analyst card texts: English only (the analyst reads English).
glob ANALYST_TEXT: dict[str, str] = {
    "ac_title": "Please review: {summary}",
    "ac_no_evidence": "No extra evidence was given.",
    "opt_approve_freeze": "Approve freeze",
    "opt_keep_open": "Keep open"
};

"""Fixed text for key in lang (si/ta/en), with {placeholders} filled from values.
Missing values stay visible as "{key}" instead of crashing."""
def fixed_text(key: str, lang: str, values: dict | None = None) -> str {
    texts = FIXED.get(key, {});
    out = texts.get(safe_lang(lang), texts.get("en", key));
    for (k, v) in (values or {}).items() {
        out = out.replace("{" + str(k) + "}", str(v));
    }
    return out;
}

"""Rs amount with thousands commas: 4200000 -> "4,200,000"."""
def fmt_rs(amount: float) -> str {
    return f"{int(round(amount)):,}";
}
