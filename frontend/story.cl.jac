# Story screen (C): B's debrief in the chosen language + timeline (English). Paper skin.
import from react { useEffect }
import from .i18n { t, known_key }
import from .ui { Header, Card, Label, Spinner, rows, last_report }
import from .theme { PAPER, DISPLAY, MONO }

sv import from ..walkers.api { get_story }

glob NL: str = chr(10);

"""Display name of a timeline agent (the raw name if we have no text for it)."""
def agent_name(agent: str) -> str {
    return t("agent." + agent, "en") if known_key("agent." + agent) else agent;
}

def:pub Story() -> JsxElement {
    has data: dict[str, any] = {},
        lang: str = "en",
        loading: bool = True;

    async def load() {
        loading = True;
        fresh = last_report(root spawn get_story(language=lang));
        if fresh {
            data = fresh;
        }
        loading = False;
    }

    useEffect(lambda { load(); }, [lang]);

    lines = (data["debrief"] as str).split(NL) if data["debrief"] else [];
    timeline = rows(data["timeline"]);
    return <div style={{"background": PAPER["bg"], "minHeight": "100vh", "color": PAPER["text"]}}>
        <Header title={t("screen.story", lang)} lang={lang} onLang={lambda (code: str) { lang = code; }} />
        <main style={{"padding": "24px 16px 40px", "maxWidth": "880px", "margin": "0 auto", "display": "flex", "flexDirection": "column", "gap": "22px"}}>
            <Card title={t("story.debrief", lang)}>
                <div lang={lang} style={{"display": "flex", "flexDirection": "column", "gap": "12px"}}>
                    {if loading and len(lines) == 0 {
                        <div style={{"display": "flex", "gap": "10px", "alignItems": "center", "fontSize": "20px"}}><Spinner />{t("common.loading", lang)}</div>
                    }}
                    {for (i, line) in enumerate(lines) {
                        <p key={str(i)} style={{"fontFamily": DISPLAY if i == 0 else "inherit", "fontWeight": "800" if i == 0 else "400",
                                                "fontSize": "30px" if i == 0 else "22px", "lineHeight": "1.5", "margin": "0"}}>{line}</p>
                    }}
                </div>
            </Card>
            <Card title={t("story.timeline", "en")}>
                {for (i, row) in enumerate(timeline) {
                    <div key={str(i)} style={{"display": "grid", "gridTemplateColumns": "84px minmax(120px, 190px) 1fr", "gap": "12px",
                                              "padding": "9px 0", "borderTop": ("1px solid " + PAPER["soft"]) if i > 0 else "none",
                                              "alignItems": "baseline"}}>
                        <span style={{"fontFamily": MONO, "fontSize": "14px", "color": PAPER["muted"]}}>{row["time"]}</span>
                        <strong style={{"fontSize": "16px"}}>{agent_name(row["agent"] as str)}</strong>
                        <span style={{"fontSize": "16px", "lineHeight": "1.5"}}>{row["text"]}</span>
                    </div>
                }}
            </Card>
        </main>
    </div>;
}
