# Scam-Breaker card on the elder's phone (M4). Full screen, calm, in the elder's language.
# One question at a time -> scam_answer. Each question is spoken once (rate 0.9) with a "Repeat" button.
# No voice for si / ta on this device -> speak the English version and show the text extra large.
import from react { useEffect }
import from .i18n { t, tf }
import from .ui { Card }
import from .voice { useVoices, pick_voice, speak }

sv import from ..walkers.api { scam_answer }

glob ANSWER_KEYS: list[str] = ["breaker.yes", "breaker.no", "breaker.unsure"];

"""Index of the first unanswered question (-1 = all answered)."""
def first_open(answers: list[str]) -> int {
    for (i, a) in enumerate(answers) {
        if not a {
            return i;
        }
    }
    return -1;
}

"""request_id: what the phone watches ("latest:<cid>" works). onAnswered: reload the phone."""
def:pub ScamBreakerCard(sb: dict[str, any], request_id: str, lang: str, onAnswered: Callable[[], None]) -> JsxElement {
    has typed: str = "",
        sending: bool = False,
        said: str = "";               # what was spoken last, so every poll does not speak again

    voices = useVoices();
    questions = (sb["questions"] or []) as list[str];
    answers = (sb["answers"] or []) as list[str];
    spoken_en = (sb["spoken_en"] or []) as list[str];
    current = first_open(answers);
    native = bool(pick_voice(voices, lang));          # a voice in the elder's language exists
    warning = (sb["warning"] or "") as str;
    family = (sb["guardian_message"] or t("breaker.family_asked", lang)) as str;

    # Speak question i (or the warning when i < 0): own language if possible, else the English version.
    def say(i: int) {
        # No English version known -> stay silent; never read si / ta text with an English voice.
        if i >= 0 {
            text = questions[i] if native else (spoken_en[i] or "");
        } else {
            text = warning if native else ((sb["warning_en"] or "") as str);
        }
        if text {
            speak(text, lang if native else "en", voices);
        }
    }

    useEffect(lambda {
        key = request_id + ":" + str(current) + ":" + str(len(questions));
        if len(voices) > 0 and key != said {
            said = key;
            say(current);
        }
    }, [current, len(voices), len(questions)]);

    async def answer(text: str) {
        if sending or current < 0 or not text.strip() {
            return;
        }
        sending = True;
        root spawn scam_answer(request_id=request_id, q=current, answer=text.strip());
        typed = "";
        sending = False;
        onAnswered();
    }

    big = "34px" if not native else "28px";      # extra large text when the voice is English
    button = {"padding": "18px", "fontSize": "24px", "fontWeight": "700", "borderRadius": "16px", "border": "none",
              "cursor": "pointer", "width": "100%"};
    return <div style={{"display": "flex", "flexDirection": "column", "gap": "14px"}}>
        <Card accent="#f59e0b">
            <h2 style={{"margin": "0 0 6px", "fontSize": "26px"}}>{t("breaker.title", lang)}</h2>
            {warning and <p style={{"fontSize": "20px", "margin": "0", "lineHeight": "1.45"}}>{warning}</p>}
        </Card>
        {if current >= 0 {
            <Card>
                <p style={{"margin": "0 0 8px", "color": "#64748b", "fontSize": "16px"}}>
                    {tf("breaker.question_n", lang, {"n": current + 1, "total": len(questions)})}
                </p>
                <p style={{"fontSize": big, "fontWeight": "700", "margin": "0 0 12px", "lineHeight": "1.35"}}>{questions[current]}</p>
                {not native and <p style={{"fontSize": "14px", "color": "#92400e", "margin": "0 0 10px"}}>{t("breaker.voice_note", lang)}</p>}
                <button style={{**button, "background": "#e2e8f0", "color": "#0f172a", "fontSize": "18px", "padding": "10px"}}
                    onClick={lambda (e: MouseEvent) { say(current); }}>{"🔊 " + t("breaker.repeat", lang)}</button>
            </Card>
            <div style={{"display": "flex", "flexDirection": "column", "gap": "10px"}}>
                {for (i, key) in enumerate(ANSWER_KEYS) {
                    <button key={key} disabled={sending}
                        style={{**button, "color": "#ffffff", "opacity": 0.6 if sending else 1,
                                "background": ["#0f766e", "#334155", "#a16207"][i]}}
                        onClick={lambda (e: MouseEvent) { answer(t(key, lang)); }}>{t(key, lang)}</button>
                }}
            </div>
            <label style={{"display": "flex", "flexDirection": "column", "gap": "6px", "fontSize": "17px", "color": "#334155"}}>
                {t("breaker.type_answer", lang)}
                <div style={{"display": "flex", "gap": "8px"}}>
                    <input value={typed} disabled={sending}
                        style={{"padding": "14px", "fontSize": "20px", "borderRadius": "12px", "border": "2px solid #cbd5e1",
                                "flex": "1", "minWidth": "0"}}
                        onChange={lambda (e: ChangeEvent) { typed = e.target.value; }} />
                    <button disabled={sending or not typed.strip()}
                        style={{**button, "width": "auto", "fontSize": "18px", "background": "#0f766e", "color": "#ffffff"}}
                        onClick={lambda (e: MouseEvent) { answer(typed); }}>{t("breaker.send", lang)}</button>
                </div>
            </label>
        } else {
            <Card accent="#0f766e">
                <p style={{"fontSize": big, "fontWeight": "700", "margin": "0 0 10px", "lineHeight": "1.35"}}>{family}</p>
                <p style={{"fontSize": "20px", "margin": "0 0 12px"}}>{t("breaker.stay", lang)}</p>
                <button style={{**button, "background": "#e2e8f0", "color": "#0f172a", "fontSize": "18px", "padding": "10px"}}
                    onClick={lambda (e: MouseEvent) { say(-1); }}>{"🔊 " + t("breaker.repeat", lang)}</button>
            </Card>
        }}
    </div>;
}
