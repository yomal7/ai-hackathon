# Demo control panel (C). Ink skin. Simulated device signals, scenarios S1-S5, reset, voices, QR codes for real phones.
import from react { useEffect }
import from "@jac/runtime" { Link }
import from "qrcode.react" { QRCodeSVG }
import from .i18n { t, tf, ops_lang, OPS }
import from .ui { Header, Card, Bar, Badge, Button, Icon, Label, theme, pressure_color, last_report, rows, pause, poll_begin, poll_end }
import from .theme { INK, SIGNAL, DISPLAY, MONO }
import from .voice { useVoices, pick_voice, speak }

sv import from ..walkers.api { run_scenario, reset_demo, telemetry_update, get_phone, submit_request }

glob SCENARIOS: list[str] = ["S1", "S2", "S3", "S4", "S5"];
glob LIVE: list[str] = ["S3", "S4"];    # replayed step by step so the pressure meter climbs on screen
glob STEP_MS: int = 1200;
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
glob CLEAR: dict[str, any] = {"on_call": False, "remote_app": False, "pasted_account": False, "typing_change": False,
                              "hesitation_ms": 0, "backtracks": 0};

"""Saved base address for QR codes (this page's address if none)."""
def saved_base() -> str {
    try {
        return localStorage.getItem(BASE_KEY) or window.location.origin;
    } except Exception {
        return window.location.origin;
    }
}

"""One on/off signal switch (a real switch, with ON / OFF in words)."""
def:pub Toggle(label: str, on: bool, onFlip: Callable[[], None]) -> JsxElement {
    return <button className="rk-btn" type="button" role="switch" aria-checked={on} onClick={lambda (e: MouseEvent) { onFlip(); }} style={{
        "display": "flex", "justifyContent": "space-between", "alignItems": "center", "gap": "12px", "width": "100%",
        "padding": "11px 14px", "borderRadius": "6px", "fontSize": "16px", "cursor": "pointer", "color": INK["text"],
        "border": "1px solid " + (SIGNAL["warn"] if on else INK["soft"]), "background": "#2E2614" if on else "#1D1C19"
    }}>
        <span style={{"textAlign": "left"}}>{label}</span>
        <span style={{"display": "inline-flex", "alignItems": "center", "gap": "8px", "fontFamily": MONO, "fontSize": "12px",
                      "fontWeight": "700", "color": SIGNAL["warn"] if on else INK["muted"]}}>
            {"ON" if on else "OFF"}
            <span style={{"width": "34px", "height": "18px", "borderRadius": "999px", "position": "relative", "display": "inline-block",
                          "background": SIGNAL["warn"] if on else "#3A3934", "transition": "background 0.2s"}}>
                <span style={{"position": "absolute", "top": "2px", "left": "18px" if on else "2px", "width": "14px", "height": "14px",
                              "borderRadius": "50%", "background": "#16140F" if on else INK["muted"], "transition": "left 0.2s"}} />
            </span>
        </span>
    </button>;
}

"""One slider signal (hesitation ms, backtracks)."""
def:pub Slider(label: str, value: int, top: int, step: int, onMove: Callable[[int], None]) -> JsxElement {
    return <label style={{"display": "flex", "flexDirection": "column", "gap": "6px", "fontSize": "15px"}}>
        <span style={{"display": "flex", "justifyContent": "space-between"}}>
            <span>{label}</span>
            <strong style={{"fontFamily": MONO}}>{str(value)}</strong>
        </span>
        <input type="range" min="0" max={str(top)} step={str(step)} value={str(value)} style={{"accentColor": INK["accent"]}}
            onChange={lambda (e: ChangeEvent) { onMove(int(e.target.value)); }} />
    </label>;
}

"""Voices for one language: how many, which one we will use, and a test button.
No voice for si / ta -> the test speaks the English sample (what the phone would do) and says so."""
def:pub VoiceRow(code: str, voices: list[dict[str, str]]) -> JsxElement {
    mine = [v for v in voices if v["lang"].lower().startswith(code)];
    chosen = pick_voice(voices, code);

    def test() {
        if chosen {
            speak(t("tele.voice_sample", code), code, voices);
        } else {
            speak(t("tele.voice_sample", "en"), "en", voices);
        }
    }

    return <div style={{"display": "grid", "gridTemplateColumns": "86px 1fr auto", "alignItems": "center", "gap": "12px",
                        "padding": "10px 0", "borderTop": "1px solid " + INK["line"]}}>
        <div style={{"display": "flex", "flexDirection": "column", "gap": "2px"}}>
            <strong>{t("tele.lang_name." + code, ops_lang())}</strong>
            <span style={{"fontFamily": MONO, "fontSize": "12px", "color": INK["muted"]}}>{tf("tele.voice_count", ops_lang(), {"n": len(mine)})}</span>
        </div>
        <span style={{"fontSize": "14px", "lineHeight": "1.4", "color": SIGNAL["safe"] if chosen else SIGNAL["warn"]}}>
            {t("tele.voice_used", ops_lang()) + ": " + (chosen["name"] if chosen else t("tele.no_voice", ops_lang()))}
        </span>
        <Button label={t("tele.test_voice", ops_lang())} icon="speaker" size="sm" dark={True} onClick={test} />
    </div>;
}

def:pub Telemetry() -> JsxElement {
    has last: str = "",
        lang: str = "en",
        running: str = "",           # scenario being run ("" = none) -> spinner + other buttons wait
        signals: dict[str, any] = CLEAR,
        pressure: int = 0,
        screen: str = "",
        elder: str = "c_seeya",
        base: str = "";

    OPS["lang"] = lang;
    voices = useVoices();

    async def load() {
        if not poll_begin("telemetry") {
            return;
        }
        try {
            phone = last_report(root spawn get_phone(request_id="latest:" + elder));
            if phone {
                pressure = phone["pressure"] as int;
                screen = phone["screen"] as str;
            }
        } except Exception {
            console.warn("[telemetry] load failed");
        }
        poll_end("telemetry");
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
        sent = last_report(root spawn telemetry_update(request_id="", signals=change));
        pressure = sent["pressure"] as int;
    }

    async def run(name: str) {
        if running {
            return;
        }
        running = name;
        title = t("scenario." + name, lang);
        last = title + " …";
        if name not in LIVE {
            started = last_report(root spawn run_scenario(name=name));
            last = title + " → " + (started["request_id"] as str);
            running = "";
            return;
        }
        # Live: build the request, send the phone's signals one by one, then call the Bank Council.
        started = last_report(root spawn run_scenario(name=name, live=True));
        rid = started["request_id"] as str;
        steps = rows(started["steps"]);
        for (i, step) in enumerate(steps) {
            last = tf("tele.step", lang, {"name": title, "n": i + 1, "total": len(steps)});
            await pause(STEP_MS);
            sent = last_report(root spawn telemetry_update(request_id=rid, signals=step));
            pressure = sent["pressure"] as int;
        }
        await pause(STEP_MS);
        root spawn submit_request(request_id=rid);
        last = title + " → " + rid;
        running = "";
    }

    async def reset() {
        if running {
            return;
        }
        running = "reset";
        root spawn reset_demo();
        signals = CLEAR;
        last = t("tele.reset", lang) + " ✓";
        running = "";
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

    grid = {"display": "grid", "gridTemplateColumns": "repeat(auto-fit, minmax(340px, 1fr))", "gap": "16px",
            "padding": "18px 24px 32px", "alignItems": "start"};
    return <div className="rk-ink" style={{"background": INK["bg"], "color": INK["text"], "minHeight": "100vh"}}>
        <Header title={t("screen.telemetry", lang)} lang={lang} onLang={lambda (code: str) { lang = code; }} dark={True}>
            <nav style={{"display": "flex", "gap": "4px"}}>
                {for s in SCREENS {
                    <Link key={s["path"]} to={s["path"]} style={{"color": INK["text"], "textDecoration": "none", "fontSize": "15px",
                                                                "padding": "6px 10px", "borderRadius": "6px", "border": "1px solid " + INK["line"]}}>
                        {t(s["key"], lang)}
                    </Link>
                }}
            </nav>
        </Header>
        <p style={{"display": "flex", "alignItems": "center", "gap": "8px", "color": SIGNAL["warn"], "margin": "14px 24px 0", "fontSize": "15px"}}>
            <Icon name="alert" size={18} />{t("tele.note", lang)}
        </p>
        <div style={grid}>
            <Card dark={True} title={t("tele.live", lang)}>
                <div role="group" style={{"display": "inline-flex", "border": "1px solid " + INK["soft"], "borderRadius": "6px", "overflow": "hidden",
                                          "marginBottom": "14px"}}>
                    {for (i, p) in enumerate(ELDERS) {
                        <button key={p["id"]} type="button" aria-pressed={elder == p["id"]} onClick={lambda (e: MouseEvent) { elder = p["id"]; }}
                            style={{"padding": "8px 16px", "fontSize": "15px", "fontWeight": "700", "cursor": "pointer", "border": "none",
                                    "borderLeft": ("1px solid " + INK["soft"]) if i > 0 else "none",
                                    "background": INK["accent"] if elder == p["id"] else "transparent",
                                    "color": "#16140F" if elder == p["id"] else INK["text"]}}
                        >{p["name"]}</button>
                    }}
                </div>
                <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "baseline", "marginBottom": "8px"}}>
                    <span style={{"fontSize": "15px", "color": INK["muted"]}}>
                        {t("tele.screen_now", lang) + ": "}<strong style={{"fontFamily": MONO, "color": INK["text"]}}>{screen or "-"}</strong>
                    </span>
                    <span style={{"fontFamily": DISPLAY, "fontSize": "30px", "fontWeight": "800", "color": pressure_color(pressure),
                                  "fontVariantNumeric": "tabular-nums"}}>{str(pressure)}</span>
                </div>
                <Bar value={pressure / 100} color={pressure_color(pressure)} height={10} dark={True} />
                <div style={{"fontFamily": MONO, "fontSize": "11.5px", "color": INK["muted"], "marginTop": "6px", "textTransform": "uppercase",
                             "letterSpacing": "0.08em"}}>{t("tele.pressure_now", lang)}</div>
            </Card>
            <Card dark={True} title={t("tele.signals", lang)}>
                <div style={{"display": "flex", "flexDirection": "column", "gap": "8px"}}>
                    {for tg in TOGGLES {
                        <Toggle key={tg["signal"]} label={t(tg["key"], lang)} on={bool(signals[tg["signal"]])}
                            onFlip={lambda { send(tg["signal"], not signals[tg["signal"]]); }} />
                    }}
                    <div style={{"marginTop": "6px", "display": "flex", "flexDirection": "column", "gap": "12px"}}>
                        <Slider label={t("tele.hesitation", lang)} value={signals["hesitation_ms"] as int} top={15000} step={500}
                            onMove={lambda (v: int) { send("hesitation_ms", v); }} />
                        <Slider label={t("tele.backtracks", lang)} value={signals["backtracks"] as int} top={10} step={1}
                            onMove={lambda (v: int) { send("backtracks", v); }} />
                    </div>
                </div>
            </Card>
            <Card dark={True} title={t("tele.scenarios", lang)}>
                <div style={{"display": "flex", "flexDirection": "column", "gap": "8px"}}>
                    {for s in SCENARIOS {
                        <Button key={s} label={t("scenario." + s, lang)} icon="play" dark={True} full={True}
                            kind={"primary" if s == "S3" else "plain"} busy={running == s} disabled={bool(running) and running != s}
                            onClick={lambda { run(s); }} />
                    }}
                    <Button label={t("tele.reset", lang)} icon="reset" kind="danger" dark={True} full={True}
                        busy={running == "reset"} disabled={bool(running) and running != "reset"} onClick={reset} />
                </div>
                {last and <p role="status" style={{"fontFamily": MONO, "fontSize": "13px", "color": INK["muted"], "margin": "12px 0 0"}}>{last}</p>}
            </Card>
            <Card dark={True} title={t("tele.voices", lang)}>
                {for code in ["si", "ta", "en"] {
                    <VoiceRow key={code} code={code} voices={voices} />
                }}
            </Card>
            <Card dark={True} title={t("tele.qr_title", lang)}>
                <label style={{"display": "flex", "flexDirection": "column", "gap": "6px", "fontSize": "14px", "color": INK["muted"]}}>
                    {t("tele.base_url", lang)}
                    <input value={base} onChange={lambda (e: ChangeEvent) { save_base(e.target.value); }}
                        style={{"padding": "9px 10px", "borderRadius": "6px", "border": "1px solid " + INK["soft"], "background": INK["sunk"],
                                "color": INK["text"], "fontSize": "15px", "fontFamily": MONO}} />
                </label>
                <p style={{"color": INK["muted"], "fontSize": "13px"}}>{t("tele.qr_hint", lang)}</p>
                <div style={{"display": "grid", "gridTemplateColumns": "repeat(2, 1fr)", "gap": "16px"}}>
                    {for q in QR_LINKS {
                        <div key={q["path"]} style={{"display": "flex", "flexDirection": "column", "alignItems": "center", "gap": "6px"}}>
                            <div style={{"background": "#FFFCF5", "padding": "8px", "borderRadius": "4px"}}>
                                <QRCodeSVG value={base + q["path"]} size={120} bgColor="#FFFCF5" fgColor="#16140F" />
                            </div>
                            <strong style={{"fontSize": "14px"}}>{t(q["key"], lang)}</strong>
                            <a href={base + q["path"]} target="_blank" style={{"color": SIGNAL["info"], "fontFamily": MONO, "fontSize": "11px",
                                                                               "wordBreak": "break-all", "textAlign": "center"}}>{base + q["path"]}</a>
                        </div>
                    }}
                </div>
            </Card>
        </div>
    </div>;
}
