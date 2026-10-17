# Guardian's phone (C): /guardian?id=g_dilshan. Card in the guardian's language + Reject / Approve / Call now.
# A new alert plays a short sound and vibrates (if the phone supports it). Locked hold -> Approve is disabled.
import from react { useEffect }
import from "@jac/runtime" { useLocation }
import from .i18n { t, tf }
import from .ui { Header, Card, Badge, Button, Icon, Spinner, theme, rows, last_report, query_param, poll_begin, poll_end }
import from .theme { PAPER, FILL, DISPLAY }
import from .phone { PhoneFrame }

sv import from ..walkers.api { get_guardian, guardian_answer, set_language }

# Buttons: answer -> i18n key + colour.
glob BUTTONS: list[dict[str, str]] = [
    {"answer": "REJECT", "key": "guardian.reject", "kind": "danger", "icon": "x"},
    {"answer": "APPROVE", "key": "guardian.approve", "kind": "safe", "icon": "check"},
    {"answer": "CALL", "key": "guardian.call", "kind": "plain", "icon": "phone"}
];

"""Short two-tone beep (Web Audio, no sound file) + vibration. Browsers may block sound until the first tap."""
def notify() {
    try {
        Ctx = window.AudioContext or window.webkitAudioContext;  # jac:ignore[E1030]
        ctx: any = new(Ctx);  # jac:ignore[E1053]
        now = ctx.currentTime as float;
        for (i, freq) in enumerate([880, 660]) {
            osc = ctx.createOscillator();
            gain = ctx.createGain();
            osc.frequency.value = freq;
            gain.gain.value = 0.15;
            osc.connect(gain);
            gain.connect(ctx.destination);
            at: float = now + i * 0.18;
            osc.start(at);
            osc.stop(at + 0.15);
        }
    } except Exception {
        console.warn("[guardian] sound blocked");
    }
    if navigator.vibrate {  # jac:ignore[E1030]
        navigator.vibrate([200, 100, 200]);  # jac:ignore[E1030]
    }
}

"""The guardian's answer in their language (REJECT -> the Reject button text)."""
def answer_text(answer: str, lang: str) -> str {
    for b in BUTTONS {
        if b["answer"] == answer {
            return t(b["key"], lang);
        }
    }
    return answer;
}

"""One guardian alert card with its buttons. A button not in options is disabled (locked hold)."""
def:pub GuardianAlert(alert: dict[str, any], lang: str, fresh: bool = False, onAnswered: Callable[[], None] = None) -> JsxElement {
    has sending: bool = False;

    alert_id = alert["id"] as str;
    options = alert["options"] as list[str];
    is_open = alert["status"] != "ANSWERED";

    async def answer(choice: str) {
        if sending {
            return;
        }
        sending = True;
        root spawn guardian_answer(alert_id=alert_id, answer=choice);
        sending = False;
        if onAnswered {
            onAnswered();
        }
    }

    return <Card accent={FILL["danger"] if is_open else PAPER["soft"]}>
        <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center", "gap": "8px", "marginBottom": "8px"}}>
            <span style={{"fontSize": "16px", "fontWeight": "700", "color": PAPER["muted"]}}>{alert["elder"] and tf("guardian.for", lang, {"name": alert["elder"]})}</span>
            {fresh and is_open and <Badge text={t("guardian.new_alert", lang)} color={FILL["mark"]} solid={True} dark={False} />}
        </div>
        <h2 style={{"margin": "0 0 10px", "fontFamily": DISPLAY, "fontSize": "27px", "fontWeight": "800", "lineHeight": "1.3"}}>{alert["title"]}</h2>
        {for (i, line) in enumerate(alert["lines"] as list[str]) {
            <p key={str(i)} style={{"fontSize": "20px", "margin": "8px 0", "lineHeight": "1.5", "paddingLeft": "12px",
                                    "borderLeft": "4px solid " + PAPER["line"]}}>{line}</p>
        }}
        {if not is_open {
            <div style={{"display": "inline-flex", "alignItems": "center", "gap": "8px", "marginTop": "10px", "background": FILL["safe"],
                         "border": "2px solid #16140F", "borderRadius": "8px", "padding": "6px 12px", "fontSize": "18px", "fontWeight": "700"}}>
                <Icon name="check" size={20} stroke={2.6} />
                {tf("guardian.your_answer", lang, {"answer": answer_text(alert["answer"] as str, lang)})}
            </div>
        } else {
            <div style={{"display": "flex", "flexDirection": "column", "gap": "12px", "marginTop": "16px"}}>
                {for b in BUTTONS {
                    <Button key={b["answer"]} label={t(b["key"], lang)} kind={b["kind"]} icon={b["icon"]} size="lg" full={True}
                        disabled={b["answer"] not in options} busy={sending} onClick={lambda { answer(b["answer"]); }} />
                }}
                {"APPROVE" not in options and <p style={{"display": "flex", "gap": "8px", "alignItems": "flex-start", "fontSize": "16px",
                                                         "lineHeight": "1.45", "margin": "0", "color": PAPER["muted"]}}>
                    <Icon name="lock" size={20} />{t("guardian.locked", lang)}
                </p>}
            </div>
        }}
    </Card>;
}

def:pub GuardianScreen() -> JsxElement {
    has data: dict[str, any] = {},
        lang: str = "en",
        lang_set: bool = False,
        seen: list[str] = [],          # alert ids already on screen
        fresh_ids: list[str] = [],     # alerts that arrived while the screen was open
        loaded: bool = False;

    guardian_id = query_param(useLocation().search as str, "id") or "g_dilshan";

    async def load() {
        if not poll_begin("guardian") {
            return;
        }
        got: dict[str, any] = {};
        try {
            got = last_report(root spawn get_guardian(guardian_id=guardian_id));
        } except Exception {
            console.warn("[guardian] load failed");
        }
        poll_end("guardian");
        if not got {
            return;
        }
        data = got;
        if not lang_set {
            lang = got["language"] as str;
            lang_set = True;
        }
        arrived: list[str] = [];
        for a in rows(got["alerts"]) {
            if a["id"] not in seen {
                arrived.append(a["id"] as str);
            }
        }
        if len(arrived) > 0 {
            seen = seen + arrived;
            if loaded {                # not on the first load: only alerts that come in while we watch
                fresh_ids = fresh_ids + arrived;
                notify();
            }
        }
        loaded = True;
    }

    async def change_lang(code: str) {
        lang = code;
        lang_set = True;
        root spawn set_language(person_id=guardian_id, language=code);
    }

    useEffect(lambda {
        seen = [];
        fresh_ids = [];
        loaded = False;
        load();
        timer = setInterval(lambda { load(); }, 1000);
        return lambda { clearInterval(timer); };
    }, [guardian_id]);

    alerts = rows(data["alerts"]);
    return <PhoneFrame>
        <Header title={t("screen.guardian", lang)} lang={lang} onLang={change_lang} />
        <div lang={lang} style={{"padding": "18px 16px 28px", "display": "flex", "flexDirection": "column", "gap": "16px"}}>
            {data["name"] and <p style={{"margin": "0", "display": "flex", "alignItems": "center", "gap": "8px", "fontSize": "18px", "fontWeight": "700"}}>
                <Icon name="user" size={20} />{data["name"]}
            </p>}
            {if len(alerts) == 0 {
                <Card accent={FILL["safe"]}>
                    <div style={{"display": "flex", "alignItems": "center", "gap": "12px"}}>
                        <Icon name="shield" size={30} stroke={2.4} />
                        <p style={{"fontSize": "22px", "fontWeight": "700", "margin": "0"}}>{t("guardian.no_alerts", lang)}</p>
                    </div>
                </Card>
            }}
            {for a in alerts {
                <GuardianAlert key={a["id"]} alert={a} lang={lang} fresh={a["id"] in fresh_ids} onAnswered={load} />
            }}
        </div>
    </PhoneFrame>;
}
