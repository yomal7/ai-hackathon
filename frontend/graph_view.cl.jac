# War Room graph canvas with walk animation. Placeholder written by A - C owns this file (C)
import from .i18n { t }

def:pub GraphView(lang: str = "en") -> JsxElement {
    return <section>
        <p>{t("sim.banner", lang)}</p>
        <h2>{t("screen.graph", lang)}</h2>
    </section>;
}
