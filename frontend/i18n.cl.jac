# UI text for si / ta / en: t(key, lang). Placeholder written by A - C owns this file (C)

"""Text for a UI key in a language (si / ta / en). Falls back to English, then to the key."""
def:pub t(key: str, lang: str) -> str {
    # si / ta strings: to be checked by a native speaker
    texts: dict[str, dict[str, str]] = {
        "sim.banner": {"en": "Simulation — fictional data", "si": "අනුකරණය — කල්පිත දත්ත", "ta": "உருவகப்படுத்தல் — கற்பனைத் தரவு"},
        "app.name": {"en": "Rakshaka", "si": "රක්ෂක", "ta": "ரக்ஷகா"},
        "screen.phone": {"en": "Phone", "si": "දුරකථනය", "ta": "தொலைபேசி"},
        "screen.telemetry": {"en": "Phone signals", "si": "දුරකථන සංඥා", "ta": "தொலைபேசி சமிக்ஞைகள்"},
        "screen.war_room": {"en": "War Room", "si": "යුද කාමරය", "ta": "போர் அறை"},
        "screen.graph": {"en": "Agent graph", "si": "නියෝජිත ප්‍රස්ථාරය", "ta": "முகவர் வரைபடம்"},
        "screen.guardian": {"en": "Guardian", "si": "භාරකරු", "ta": "பாதுகாவலர்"},
        "screen.analyst": {"en": "Fraud analyst", "si": "වංචා විශ්ලේෂක", "ta": "மோசடி ஆய்வாளர்"},
        "screen.story": {"en": "Story", "si": "කතාව", "ta": "கதை"}
    };
    if key not in texts {
        return key;
    }
    row = texts[key];
    return row[lang] if lang in row else row["en"];
}
