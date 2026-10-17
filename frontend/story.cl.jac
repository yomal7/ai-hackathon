# Story / debrief screen. Placeholder written by A - C owns this file (C)
import from .i18n { t }

def:pub Story(lang: str = "en") -> JsxElement {
    return <section>
        <p>{t("sim.banner", lang)}</p>
        <h2>{t("screen.story", lang)}</h2>
    </section>;
}
