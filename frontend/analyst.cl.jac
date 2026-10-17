# Bank fraud analyst screen. Placeholder written by A - C owns this file (C)
import from .i18n { t }

def:pub AnalystScreen(lang: str = "en") -> JsxElement {
    return <section>
        <p>{t("sim.banner", lang)}</p>
        <h2>{t("screen.analyst", lang)}</h2>
    </section>;
}
