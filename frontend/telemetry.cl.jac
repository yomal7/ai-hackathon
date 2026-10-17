# Demo control panel (C): English. Scenario buttons + reset now; signal toggles, voices and QR codes come in M2.
import from "@jac/runtime" { Link }
import from .i18n { t }
import from .ui { Header, Card, theme, first_report }

sv import from ..walkers.api { run_scenario, reset_demo }

glob LANG: str = "en";
glob SCENARIOS: list[str] = ["S1", "S2", "S3", "S4", "S5"];
glob SCREENS: list[dict[str, str]] = [
    {"path": "/war-room", "key": "nav.war_room"},
    {"path": "/phone", "key": "nav.phone"},
    {"path": "/guardian?id=g_dilshan", "key": "nav.guardian"},
    {"path": "/story", "key": "nav.story"}
];

def:pub Telemetry() -> JsxElement {
    has last: str = "";

    async def run(name: str) {
        started = first_report(root spawn run_scenario(name=name));
        last = name + " → " + (started["request_id"] as str);
    }

    async def reset() {
        root spawn reset_demo();
        last = t("tele.reset", LANG) + " ✓";
    }

    th = theme(True);
    button = {"padding": "12px 16px", "borderRadius": "10px", "border": "1px solid #334155", "background": "#1e293b",
              "color": "#e2e8f0", "fontSize": "16px", "cursor": "pointer"};
    return <div style={{"background": th["bg"], "color": th["text"], "minHeight": "100vh"}}>
        <Header title={t("screen.telemetry", LANG)} lang={LANG} onLang={lambda (code: str) { }} dark={True}>
            <nav style={{"display": "flex", "gap": "12px"}}>
                {for s in SCREENS {
                    <Link key={s["path"]} to={s["path"]} style={{"color": th["accent"]}}>{t(s["key"], LANG)}</Link>
                }}
            </nav>
        </Header>
        <div style={{"padding": "16px 20px", "display": "flex", "flexDirection": "column", "gap": "14px", "maxWidth": "900px"}}>
            <p style={{"color": "#fbbf24", "margin": "0"}}>{t("tele.note", LANG)}</p>
            <Card dark={True} title={t("tele.scenarios", LANG)}>
                <div style={{"display": "flex", "gap": "10px", "flexWrap": "wrap"}}>
                    {for s in SCENARIOS {
                        <button key={s} style={button} onClick={lambda (e: MouseEvent) { run(s); }}>{t("scenario." + s, LANG)}</button>
                    }}
                    <button style={{**button, "borderColor": "#ef4444", "color": "#fca5a5"}} onClick={lambda (e: MouseEvent) { reset(); }}>{t("tele.reset", LANG)}</button>
                </div>
                {last and <p style={{"color": th["muted"], "marginBottom": "0"}}>{last}</p>}
            </Card>
        </div>
    </div>;
}
