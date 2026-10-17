# Scam-Breaker card on the elder's phone (M4). Full screen, calm, in the elder's language.
# One question at a time -> scam_answer. Each question is spoken once (rate 0.9) with a "Repeat" button.
# No voice for si / ta on this device -> speak the English version and show the text extra large.
import from react { useEffect }
import from .i18n { t, tf }
import from .ui { Card, Button, Icon, Label }
import from .theme { PAPER, FILL, DISPLAY }
import from .voice { useVoices, pick_voice, speak }

sv import from ..walkers.api { scam_answer }

# Answer buttons: i18n key + button kind (colour is never the only signal: the word is always there).
glob ANSWERS: list[dict[str, str]] = [
    {"key": "breaker.yes", "kind": "danger", "icon": "check"},
    {"key": "breaker.no", "kind": "safe", "icon": "x"},
    {"key": "breaker.unsure", "kind": "warn", "icon": "alert"}
];

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
    # No English version known -> stay silent; never read si / ta text with an English voice.
    def say(i: int) {
        text = "";                    # declared here: a name first set inside if / else is not visible after it in JS
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

    big = "34px" if not native else "29px";      # extra large text when the voice is English
    return <div style={{"display": "flex", "flexDirection": "column", "gap": "16px"}}>
        <div style={{"background": FILL["warn"], "border": "2px solid #16140F", "borderRadius": "12px", "boxShadow": "4px 4px 0 #16140F",
                     "padding": "16px 18px"}}>
            <div style={{"display": "flex", "alignItems": "center", "gap": "10px", "marginBottom": "6px"}}>
                <Icon name="shield" size={26} stroke={2.6} />
                <h2 style={{"margin": "0", "fontFamily": DISPLAY, "fontSize": "26px", "fontWeight": "800", "lineHeight": "1.2"}}>{t("breaker.title", lang)}</h2>
            </div>
            {warning and <p style={{"fontSize": "20px", "margin": "0", "lineHeight": "1.55"}}>{warning}</p>}
        </div>
        {if current >= 0 {
            <Card>
                <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center", "gap": "8px"}}>
                    <Label text={tf("breaker.question_n", lang, {"n": current + 1, "total": len(questions)})} />
                    <div style={{"display": "flex", "gap": "4px", "marginBottom": "8px"}}>
                        {for (i, q) in enumerate(questions) {
                            <span key={str(i)} style={{"width": "22px", "height": "8px", "borderRadius": "3px", "border": "2px solid #16140F",
                                                       "background": "#16140F" if i <= current else PAPER["card"]}} />
                        }}
                    </div>
                </div>
                <p style={{"fontFamily": DISPLAY, "fontSize": big, "fontWeight": "800", "margin": "0 0 14px", "lineHeight": "1.4"}}>{questions[current]}</p>
                {not native and <p style={{"fontSize": "15px", "margin": "0 0 12px", "display": "inline-block", "background": FILL["mark"],
                                          "border": "2px solid #16140F", "borderRadius": "6px", "padding": "2px 8px"}}>{t("breaker.voice_note", lang)}</p>}
                <Button label={t("breaker.repeat", lang)} icon="speaker" onClick={lambda { say(current); }} />
            </Card>
            <div style={{"display": "flex", "flexDirection": "column", "gap": "12px"}}>
                {for a in ANSWERS {
                    <Button key={a["key"]} label={t(a["key"], lang)} kind={a["kind"]} icon={a["icon"]} size="lg" full={True}
                        busy={sending} onClick={lambda { answer(t(a["key"], lang)); }} />
                }}
            </div>
            <label style={{"display": "flex", "flexDirection": "column", "gap": "8px", "fontSize": "18px", "fontWeight": "700"}}>
                {t("breaker.type_answer", lang)}
                <div style={{"display": "flex", "gap": "8px"}}>
                    <input value={typed} disabled={sending}
                        style={{"padding": "14px", "fontSize": "20px", "borderRadius": "10px", "border": "2px solid #16140F",
                                "background": PAPER["card"], "flex": "1", "minWidth": "0"}}
                        onChange={lambda (e: ChangeEvent) { typed = e.target.value; }} />
                    <Button label={t("breaker.send", lang)} kind="primary" icon="send" disabled={not typed.strip()} busy={sending}
                        onClick={lambda { answer(typed); }} />
                </div>
            </label>
        } else {
            <Card accent={FILL["safe"]}>
                <div style={{"display": "flex", "gap": "12px", "alignItems": "flex-start"}}>
                    <span style={{"width": "48px", "height": "48px", "borderRadius": "50%", "background": "#16140F", "display": "inline-flex",
                                  "alignItems": "center", "justifyContent": "center", "flexShrink": "0"}}>
                        <Icon name="user" size={26} color={FILL["safe"]} stroke={2.6} />
                    </span>
                    <p style={{"fontFamily": DISPLAY, "fontSize": big, "fontWeight": "800", "margin": "0", "lineHeight": "1.4"}}>{family}</p>
                </div>
                <p style={{"fontSize": "20px", "lineHeight": "1.55", "margin": "14px 0"}}>{t("breaker.stay", lang)}</p>
                <Button label={t("breaker.repeat", lang)} icon="speaker" onClick={lambda { say(-1); }} />
            </Card>
        }}
    </div>;
}
