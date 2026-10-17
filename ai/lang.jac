# Language helpers + fixed fallback texts in si / ta / en. STUB written by A - B owns and replaces this file (B)
import re;

# Scam keywords per scam type. Sinhala, Tamil, English, Singlish, Tanglish.
# Sinhala / Tamil words: to be checked by a native speaker.
glob SCAM_WORDS: dict[str, list[str]] = {
    "FAKE_POLICE_SAFE_ACCOUNT": [
        "safe account", "cid", "police", "arrest", "drug case", "government account",
        "police case eka", "safe account ekata",
        "ආරක්ෂිත ගිණුම", "පොලිසිය", "සීඅයිඩී", "අත්අඩංගුවට",
        "பாதுகாப்பான கணக்கு", "காவல்துறை", "கைது"
    ],
    "CUSTOMS_PARCEL_FEE": ["customs", "parcel", "customs fee kattanum", "රේගු", "சுங்க"],
    "LOTTERY_FEE": ["lottery", "prize", "ලොතරැයි", "லாட்டரி"],
    "FAKE_BANK_STAFF": ["bank officer", "verify your account", "share otp"],
    "INVESTMENT_DOUBLE": ["double your money", "guaranteed return"],
    "ROMANCE": ["my love", "send gift money"]
};

"""Script check in code: Sinhala or Tamil letters win, else English."""
def detect_language(text: str) -> str {
    for ch in text {
        code = ord(ch);
        if code >= 0x0D80 and code <= 0x0DFF {
            return "si";
        }
        if code >= 0x0B80 and code <= 0x0BFF {
            return "ta";
        }
    }
    return "en";
}

"""Keyword fallback for all 3 languages. Returns the keywords found."""
def scam_keywords_hit(text: str) -> list[str] {
    low = text.lower();
    hits: list[str] = [];
    for words in SCAM_WORDS.values() {
        for w in words {
            # ASCII words need whole-word match ("cid" must not hit "decided")
            found = (re.search(r"\b" + re.escape(w) + r"\b", low) is not None) if w.isascii() else (w in low);
            if found and w not in hits {
                hits.append(w);
            }
        }
    }
    return hits;
}

"""Which scam type the keyword hits point to, or NONE."""
def scam_type_of(hits: list[str]) -> str {
    for (kind, words) in SCAM_WORDS.items() {
        for h in hits {
            if h in words {
                return kind;
            }
        }
    }
    return "NONE";
}

"""Pick the text for a language, English if missing."""
def pick(texts: dict[str, any], language: str) -> any {
    return texts[language] if language in texts else texts["en"];
}

# ---- Fixed fallback texts (si / ta: to be checked by a native speaker) ----

glob SCAM_QUESTIONS: dict[str, list[str]] = {
    "en": [
        "Is someone on the phone telling you to make this transfer?",
        "Did the caller say they are from the police, CID or the bank?",
        "Did they tell you not to tell your family?"
    ],
    "si": [
        "මෙම මුදල් යැවීම කරන්න කියලා කවුරුහරි දැන් දුරකථනයෙන් ඔබට කියනවාද?",
        "ඇමතුම ගත් අය පොලිසියෙන්, සීඅයිඩී එකෙන් හෝ බැංකුවෙන් කියලා කිව්වාද?",
        "පවුලේ අයට නොකියන්න කියලා ඔවුන් ඔබට කිව්වාද?"
    ],
    "ta": [
        "இந்தப் பணப் பரிமாற்றத்தைச் செய்யுமாறு யாராவது தொலைபேசியில் சொல்கிறார்களா?",
        "அழைத்தவர் காவல்துறை, சிஐடி அல்லது வங்கியிலிருந்து என்று சொன்னாரா?",
        "குடும்பத்தினரிடம் சொல்ல வேண்டாம் என்று சொன்னார்களா?"
    ]
};

glob SCAM_WARNING: dict[str, str] = {
    "en": "Police and banks never ask you to move money to a 'safe account'.",
    "si": "පොලිසිය හෝ බැංකු කිසිවිටෙක 'ආරක්ෂිත ගිණුමකට' මුදල් යවන්න කියන්නේ නැහැ.",
    "ta": "காவல்துறையோ வங்கியோ ஒருபோதும் 'பாதுகாப்பான கணக்கிற்கு' பணம் அனுப்பச் சொல்லாது."
};

glob GUARDIAN_TITLE: dict[str, str] = {
    "en": "Urgent: please check this transfer",
    "si": "හදිසියි: කරුණාකර මෙම මුදල් යැවීම පරීක්ෂා කරන්න",
    "ta": "அவசரம்: இந்தப் பணப் பரிமாற்றத்தைச் சரிபார்க்கவும்"
};

glob GUARDIAN_LINES: dict[str, list[str]] = {
    "en": [
        "Your parent is trying to send a large amount to a new account.",
        "They may be on a call with a scammer right now.",
        "Reject to stop it, or call them now."
    ],
    "si": [
        "ඔබේ දෙමාපියන් නව ගිණුමකට විශාල මුදලක් යැවීමට උත්සාහ කරනවා.",
        "ඔවුන් දැන් වංචාකරුවෙකු සමඟ දුරකථනයෙන් කතා කරනවා විය හැකියි.",
        "නැවැත්වීමට ප්‍රතික්ෂේප කරන්න, නැත්නම් දැන්ම ඔවුන්ට කතා කරන්න."
    ],
    "ta": [
        "உங்கள் பெற்றோர் புதிய கணக்கிற்கு பெரிய தொகையை அனுப்ப முயல்கிறார்.",
        "அவர் இப்போது ஒரு மோசடிக்காரருடன் தொலைபேசியில் இருக்கலாம்.",
        "நிறுத்த நிராகரிக்கவும், அல்லது இப்போதே அவரை அழைக்கவும்."
    ]
};

glob DEBRIEF: dict[str, str] = {
    "en": "A caller pretended to be the police.\nHe asked for a transfer to a 'safe account'.\nRakshaka held the money and your family said no.\nYour savings are safe.",
    "si": "ඇමතුම ගත් අය පොලිසිය ලෙස රඟපෑවා.\n'ආරක්ෂිත ගිණුමකට' මුදල් යවන්න කිව්වා.\nරක්ෂක මුදල් නවත්වා ඔබේ පවුල එය ප්‍රතික්ෂේප කළා.\nඔබේ ඉතුරුම් ආරක්ෂිතයි.",
    "ta": "அழைத்தவர் காவல்துறை என்று நடித்தார்.\n'பாதுகாப்பான கணக்கிற்கு' பணம் அனுப்பச் சொன்னார்.\nரக்ஷகா பணத்தை நிறுத்தியது, உங்கள் குடும்பம் மறுத்தது.\nஉங்கள் சேமிப்பு பாதுகாப்பாக உள்ளது."
};
