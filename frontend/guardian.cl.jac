# Guardian's phone (C): /guardian?id=g_dilshan. Card in the guardian's language + Reject / Approve / Call now.
# A new alert plays a short sound and vibrates (if the phone supports it). Locked hold -> Approve is disabled.
import from react { useEffect }
import from "@jac/runtime" { useLocation }
import from .i18n { t, tf }
import from .ui { Header, Card, Badge, theme, rows, last_report, query_param }
import from .phone { PhoneFrame }

sv import from ..walkers.api { get_guardian, guardian_answer, set_language }

# Buttons: answer -> i18n key + colour.
glob BUTTONS: list[dict[str, str]] = [
    {"answer": "REJECT", "key": "guardian.reject", "color": "#dc2626"},
    {"answer": "APPROVE", "key": "guardian.approve", "color": "#16a34a"},
    {"answer": "CALL", "key": "guardian.call", "color": "#2563eb"}
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

    return <Card accent={"#dc2626" if is_open else "#94a3b8"}>
        <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center", "gap": "8px", "marginBottom": "6px"}}>
            <span style={{"fontSize": "15px", "color": "#64748b"}}>{alert["elder"] and tf("guardian.for", lang, {"name": alert["elder"]})}</span>
            {fresh and is_open and <Badge text={t("guardian.new_alert", lang)} color="#dc2626" solid={True} />}
        </div>
        <h2 style={{"margin": "0 0 10px", "fontSize": "24px", "lineHeight": "1.3"}}>{alert["title"]}</h2>
        {for (i, line) in enumerate(alert["lines"] as list[str]) {
            <p key={str(i)} style={{"fontSize": "19px", "margin": "6px 0", "lineHeight": "1.4"}}>{line}</p>
        }}
        {if not is_open {
            <Badge text={tf("guardian.your_answer", lang, {"answer": answer_text(alert["answer"] as str, lang)})} color="#16a34a" />
        } else {
            <div style={{"display": "flex", "flexDirection": "column", "gap": "10px", "marginTop": "12px"}}>
                {for b in BUTTONS {
                    <button
                        key={b["answer"]}
                        disabled={sending or b["answer"] not in options}
                        onClick={lambda (e: MouseEvent) { answer(b["answer"]); }}
                        style={{"padding": "16px", "fontSize": "20px", "fontWeight": "700", "borderRadius": "14px", "border": "none",
                                "color": "#ffffff", "background": b["color"], "opacity": 1 if b["answer"] in options and not sending else 0.35,
                                "cursor": "pointer" if b["answer"] in options else "not-allowed"}}
                    >{t(b["key"], lang)}</button>
                }}
                {"APPROVE" not in options and <p style={{"fontSize": "15px", "color": "#64748b", "margin": "0"}}>{t("guardian.locked", lang)}</p>}
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
        got = last_report(root spawn get_guardian(guardian_id=guardian_id));
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
        <div style={{"padding": "16px", "display": "flex", "flexDirection": "column", "gap": "14px", "background": theme(False)["bg"]}}>
            {data["name"] and <p style={{"margin": "0", "color": "#64748b"}}>{data["name"]}</p>}
            {if len(alerts) == 0 {
                <Card><p style={{"fontSize": "20px", "margin": "0"}}>{t("guardian.no_alerts", lang)}</p></Card>
            }}
            {for a in alerts {
                <GuardianAlert key={a["id"]} alert={a} lang={lang} fresh={a["id"] in fresh_ids} onAnswered={load} />
            }}
        </div>
    </PhoneFrame>;
}
