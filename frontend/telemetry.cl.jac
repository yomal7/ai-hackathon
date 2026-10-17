# Demo control panel (C): English. Simulated device signals, scenarios S1-S5, reset, voices, QR codes for real phones.
import from react { useEffect }
import from "@jac/runtime" { Link }
import from "qrcode.react" { QRCodeSVG }
import from .i18n { t, tf }
import from .ui { Header, Card, Bar, Badge, theme, pressure_color, first_report }
import from .voice { useVoices, pick_voice, speak }

sv import from ..walkers.api { run_scenario, reset_demo, telemetry_update, get_phone }

glob LANG: str = "en";
glob SCENARIOS: list[str] = ["S1", "S2", "S3", "S4", "S5"];
glob TOGGLES: list[dict[str, str]] = [
    {"signal": "on_call", "key": "tele.on_call"},
    {"signal": "remote_app", "key": "tele.remote_app"},
    {"signal": "pasted_account", "key": "tele.pasted"},
    {"signal": "typing_change", "key": "tele.typing_change"}
];
glob SCREENS: list[dict[str, str]] = [
    {"path": "/war-room", "key": "nav.war_room"},
    {"path": "/phone", "key": "nav.phone"},
    {"path": "/guardian?id=g_dilshan", "key": "nav.guardian"},
    {"path": "/story", "key": "nav.story"}
];
glob QR_LINKS: list[dict[str, str]] = [
    {"path": "/phone?citizen=c_seeya", "key": "tele.qr.phone_seeya"},
    {"path": "/guardian?id=g_dilshan", "key": "tele.qr.guardian_dilshan"},
    {"path": "/phone?citizen=c_kamala", "key": "tele.qr.phone_kamala"},
    {"path": "/guardian?id=g_priya", "key": "tele.qr.guardian_priya"}
];
glob ELDERS: list[dict[str, str]] = [{"id": "c_seeya", "name": "Seeya"}, {"id": "c_kamala", "name": "Kamala"}];
glob BASE_KEY: str = "rk_base_url";

"""Saved base address for QR codes (this page's address if none)."""
def saved_base() -> str {
    try {
        return localStorage.getItem(BASE_KEY) or window.location.origin;
    } except Exception {
        return window.location.origin;
    }
}

"""One on/off signal switch."""
def:pub Toggle(label: str, on: bool, onFlip: Callable[[], None]) -> JsxElement {
    return <button onClick={lambda (e: MouseEvent) { onFlip(); }} style={{
        "display": "flex", "justifyContent": "space-between", "alignItems": "center", "gap": "12px", "width": "100%",
        "padding": "12px 14px", "borderRadius": "12px", "fontSize": "16px", "cursor": "pointer", "color": "#e2e8f0",
        "border": "1px solid " + ("#f59e0b" if on else "#334155"), "background": "#3b2a0a" if on else "#1e293b"
    }}>
        <span>{label}</span>
        <Badge text={"ON" if on else "OFF"} color={"#f59e0b" if on else "#64748b"} solid={on} />
    </button>;
}

"""One slider signal (hesitation ms, backtracks)."""
def:pub Slider(label: str, value: int, top: int, step: int, onMove: Callable[[int], None]) -> JsxElement {
    return <label style={{"display": "flex", "flexDirection": "column", "gap": "4px", "fontSize": "15px"}}>
        <span style={{"display": "flex", "justifyContent": "space-between"}}><span>{label}</span><strong>{str(value)}</strong></span>
        <input type="range" min="0" max={str(top)} step={str(step)} value={str(value)}
            onChange={lambda (e: ChangeEvent) { onMove(int(e.target.value)); }} />
    </label>;
}

"""Voices for one language: how many, which one we will use, and a test button."""
def:pub VoiceRow(code: str, voices: list[dict[str, str]]) -> JsxElement {
    mine = [v for v in voices if v["lang"].lower().startswith(code)];
    chosen = pick_voice(voices, code);
    return <div style={{"display": "flex", "alignItems": "center", "gap": "12px", "padding": "8px 0", "borderBottom": "1px solid #1e293b"}}>
        <strong style={{"minWidth": "70px"}}>{t("tele.lang_name." + code, LANG)}</strong>
        <span style={{"minWidth": "80px", "color": "#94a3b8"}}>{tf("tele.voice_count", LANG, {"n": len(mine)})}</span>
        <span style={{"flex": "1", "color": "#22c55e" if chosen else "#f59e0b"}}>
            {t("tele.voice_used", LANG) + ": " + (chosen["name"] + " (" + chosen["lang"] + ")" if chosen else t("tele.no_voice", LANG))}
        </span>
        <button onClick={lambda (e: MouseEvent) { speak(t("tele.voice_sample", code), code, voices); }}
            style={{"padding": "6px 12px", "borderRadius": "8px", "border": "1px solid #334155", "background": "#1e293b", "color": "#e2e8f0", "cursor": "pointer"}}
        >{t("tele.test_voice", LANG)}</button>
    </div>;
}

def:pub Telemetry() -> JsxElement {
    has last: str = "",
        signals: dict[str, any] = {"on_call": False, "remote_app": False, "pasted_account": False, "typing_change": False,
                                   "hesitation_ms": 0, "backtracks": 0},
        pressure: int = 0,
        screen: str = "",
        elder: str = "c_seeya",
        base: str = "";

    voices = useVoices();

    async def load() {
        phone = first_report(root spawn get_phone(request_id="latest:" + elder));
        if phone {
            pressure = phone["pressure"] as int;
            screen = phone["screen"] as str;
        }
    }

    useEffect(lambda {
        base = saved_base();
        load();
        timer = setInterval(lambda { load(); }, 1000);
        return lambda { clearInterval(timer); };
    }, [elder]);

    async def send(signal: str, value: any) {
        # Build with [] - a {signal: value} literal compiles to the fixed key "signal" in JS.
        change: dict[str, any] = {};
        change[signal] = value;
        signals = {**signals, **change};
        sent = first_report(root spawn telemetry_update(request_id="", signals=change));
        pressure = sent["pressure"] as int;
    }

    async def run(name: str) {
        started = first_report(root spawn run_scenario(name=name));
        last = t("scenario." + name, LANG) + " → " + (started["request_id"] as str);
    }

    async def reset() {
        root spawn reset_demo();
        signals = {"on_call": False, "remote_app": False, "pasted_account": False, "typing_change": False, "hesitation_ms": 0, "backtracks": 0};
        last = t("tele.reset", LANG) + " ✓";
        load();
    }

    def save_base(value: str) {
        base = value;
        try {
            localStorage.setItem(BASE_KEY, value);
        } except Exception {
            base = value;
        }
    }

    th = theme(True);
    button = {"padding": "12px 16px", "borderRadius": "10px", "border": "1px solid #334155", "background": "#1e293b",
              "color": "#e2e8f0", "fontSize": "16px", "cursor": "pointer"};
    grid = {"display": "grid", "gridTemplateColumns": "repeat(auto-fit, minmax(340px, 1fr))", "gap": "14px",
            "padding": "16px 20px", "alignItems": "start"};
    return <div style={{"background": th["bg"], "color": th["text"], "minHeight": "100vh"}}>
        <Header title={t("screen.telemetry", LANG)} lang={LANG} onLang={lambda (code: str) { }} dark={True}>
            <nav style={{"display": "flex", "gap": "12px"}}>
                {for s in SCREENS {
                    <Link key={s["path"]} to={s["path"]} style={{"color": th["accent"]}}>{t(s["key"], LANG)}</Link>
                }}
            </nav>
        </Header>
        <p style={{"color": "#fbbf24", "margin": "12px 20px 0", "fontSize": "15px"}}>{t("tele.note", LANG)}</p>
        <div style={grid}>
            <Card dark={True} title={t("tele.live", LANG)}>
                <div style={{"display": "flex", "gap": "8px", "marginBottom": "10px"}}>
                    {for p in ELDERS {
                        <button key={p["id"]} onClick={lambda (e: MouseEvent) { elder = p["id"]; }}
                            style={{**button, "padding": "6px 12px", "borderColor": th["accent"] if elder == p["id"] else "#334155"}}
                        >{p["name"]}</button>
                    }}
                </div>
                <div style={{"display": "flex", "justifyContent": "space-between", "fontSize": "15px"}}>
                    <span>{t("tele.screen_now", LANG) + ": " + (screen or "-")}</span>
                    <strong style={{"color": pressure_color(pressure)}}>{t("tele.pressure_now", LANG) + " " + str(pressure)}</strong>
                </div>
                <div style={{"marginTop": "8px"}}><Bar value={pressure / 100} color={pressure_color(pressure)} height={14} dark={True} /></div>
            </Card>
            <Card dark={True} title={t("tele.signals", LANG)}>
                <div style={{"display": "flex", "flexDirection": "column", "gap": "8px"}}>
                    {for tg in TOGGLES {
                        <Toggle key={tg["signal"]} label={t(tg["key"], LANG)} on={bool(signals[tg["signal"]])}
                            onFlip={lambda { send(tg["signal"], not signals[tg["signal"]]); }} />
                    }}
                    <Slider label={t("tele.hesitation", LANG)} value={signals["hesitation_ms"] as int} top={15000} step={500}
                        onMove={lambda (v: int) { send("hesitation_ms", v); }} />
                    <Slider label={t("tele.backtracks", LANG)} value={signals["backtracks"] as int} top={10} step={1}
                        onMove={lambda (v: int) { send("backtracks", v); }} />
                </div>
            </Card>
            <Card dark={True} title={t("tele.scenarios", LANG)}>
                <div style={{"display": "flex", "gap": "10px", "flexWrap": "wrap"}}>
                    {for s in SCENARIOS {
                        <button key={s} style={button} onClick={lambda (e: MouseEvent) { run(s); }}>{t("scenario." + s, LANG)}</button>
                    }}
                    <button style={{**button, "borderColor": "#ef4444", "color": "#fca5a5"}} onClick={lambda (e: MouseEvent) { reset(); }}>{t("tele.reset", LANG)}</button>
                </div>
                {last and <p style={{"color": th["muted"], "marginBottom": "0"}}>{last}</p>}
            </Card>
            <Card dark={True} title={t("tele.voices", LANG)}>
                {for code in ["si", "ta", "en"] {
                    <VoiceRow key={code} code={code} voices={voices} />
                }}
            </Card>
            <Card dark={True} title={t("tele.qr_title", LANG)}>
                <label style={{"display": "flex", "flexDirection": "column", "gap": "6px", "fontSize": "14px", "color": th["muted"]}}>
                    {t("tele.base_url", LANG)}
                    <input value={base} onChange={lambda (e: ChangeEvent) { save_base(e.target.value); }}
                        style={{"padding": "8px", "borderRadius": "8px", "border": "1px solid #334155", "background": "#0b1120", "color": "#e2e8f0", "fontSize": "15px"}} />
                </label>
                <p style={{"color": th["muted"], "fontSize": "13px"}}>{t("tele.qr_hint", LANG)}</p>
                <div style={{"display": "grid", "gridTemplateColumns": "repeat(2, 1fr)", "gap": "14px"}}>
                    {for q in QR_LINKS {
                        <div key={q["path"]} style={{"display": "flex", "flexDirection": "column", "alignItems": "center", "gap": "6px"}}>
                            <div style={{"background": "#ffffff", "padding": "8px", "borderRadius": "8px"}}>
                                <QRCodeSVG value={base + q["path"]} size={120} />
                            </div>
                            <strong style={{"fontSize": "14px"}}>{t(q["key"], LANG)}</strong>
                            <a href={base + q["path"]} target="_blank" style={{"color": th["accent"], "fontSize": "11px", "wordBreak": "break-all"}}>{base + q["path"]}</a>
                        </div>
                    }}
                </div>
            </Card>
        </div>
    </div>;
}
