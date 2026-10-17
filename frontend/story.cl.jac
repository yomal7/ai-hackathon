# Story screen (C): B's debrief in the chosen language + timeline (English). Final counters come in M5.
import from react { useEffect }
import from .i18n { t }
import from .ui { Header, Card, theme, rows, first_report }

sv import from ..walkers.api { get_story }

glob NL: str = chr(10);

def:pub Story() -> JsxElement {
    has data: dict[str, any] = {},
        lang: str = "en";

    async def load() {
        fresh = first_report(root spawn get_story(language=lang));
        if fresh {
            data = fresh;
        }
    }

    useEffect(lambda { load(); }, [lang]);

    th = theme(False);
    lines = (data["debrief"] as str).split(NL) if data["debrief"] else [];
    return <div style={{"background": th["bg"], "minHeight": "100vh", "color": th["text"]}}>
        <Header title={t("screen.story", lang)} lang={lang} onLang={lambda (code: str) { lang = code; }} />
        <div style={{"padding": "20px", "maxWidth": "860px", "margin": "0 auto", "display": "flex", "flexDirection": "column", "gap": "16px"}}>
            <Card title={t("story.debrief", lang)}>
                {for (i, line) in enumerate(lines) {
                    <p key={str(i)} style={{"fontSize": "24px", "margin": "8px 0"}}>{line}</p>
                }}
            </Card>
            <Card title={t("story.timeline", "en")}>
                {for (i, row) in enumerate(rows(data["timeline"])) {
                    <div key={str(i)} style={{"display": "flex", "gap": "12px", "padding": "6px 0", "borderBottom": "1px solid " + th["line"]}}>
                        <span style={{"color": th["muted"], "minWidth": "72px"}}>{row["time"]}</span>
                        <strong style={{"minWidth": "160px"}}>{t("agent." + (row["agent"] as str), "en")}</strong>
                        <span>{row["text"]}</span>
                    </div>
                }}
            </Card>
        </div>
    </div>;
}
