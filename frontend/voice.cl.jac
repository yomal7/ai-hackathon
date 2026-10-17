# Browser speech (C): find a voice for si / ta / en and speak. Used by the control panel (M2) and Scam-Breaker (M4).
import from react { useEffect }

# Voice language tags to try, best first.
glob:pub VOICE_TAGS: dict[str, list[str]] = {
    "si": ["si-lk", "si"],
    "ta": ["ta-lk", "ta-in", "ta"],
    "en": ["en-gb", "en-in", "en-us", "en"]
};

"""The browser's speech engine (None if the browser has none)."""
def synth() -> any {
    return window.speechSynthesis;  # jac:ignore[E1030]
}

"""All voices the browser has now, as [{name, lang}]."""
def:pub list_voices() -> list[dict[str, str]] {
    engine = synth();
    if not engine {
        return [];
    }
    found: list[dict[str, str]] = [];
    for v in engine.getVoices() {
        found.append({"name": str(v.name), "lang": str(v.lang).replace("_", "-")});
    }
    return found;
}

"""The best voice for a language ({} if none). Natural / online voices win."""
def:pub pick_voice(voices: list[dict[str, str]], lang: str) -> dict[str, str] {
    for tag in VOICE_TAGS[lang] or [] {
        matches = [v for v in voices if v["lang"].lower().startswith(tag)];
        natural = [v for v in matches if "Natural" in v["name"]];
        if len(natural) > 0 {
            return natural[0];
        }
        if len(matches) > 0 {
            return matches[0];
        }
    }
    return {};
}

"""Voices of the browser, refreshed when the browser finishes loading them."""
def:pub useVoices() -> list[dict[str, str]] {
    has voices: list[dict[str, str]] = [];

    useEffect(lambda {
        engine = synth();
        if engine {
            voices = list_voices();
            engine.onvoiceschanged = lambda { voices = list_voices(); };
        }
        return lambda { if engine { engine.onvoiceschanged = None; } };
    }, []);
    return voices;
}

"""Speak text at rate 0.9 in the language's voice. No voice for it -> English voice; returns False then."""
def:pub speak(text: str, lang: str, voices: list[dict[str, str]]) -> bool {
    engine = synth();
    if not engine {
        return False;
    }
    chosen = pick_voice(voices, lang);
    native = bool(chosen);              # a voice in the asked language exists
    if not native {
        chosen = pick_voice(voices, "en");
    }
    utter: any = new(SpeechSynthesisUtterance, text);  # jac:ignore[E1053]
    utter.rate = 0.9;
    utter.lang = chosen["lang"] or "en-GB";
    for v in engine.getVoices() {
        if v.name == chosen["name"] {
            utter.voice = v;
        }
    }
    engine.cancel();
    engine.speak(utter);
    return native;
}
