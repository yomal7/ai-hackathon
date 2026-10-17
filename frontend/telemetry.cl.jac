# Simulated phone signals panel (on call, remote app, ...). Placeholder written by A - C owns this file (C)
import from .i18n { t }

def:pub Telemetry(lang: str = "en") -> JsxElement {
    return <section>
        <p>{t("sim.banner", lang)}</p>
        <h2>{t("screen.telemetry", lang)}</h2>
    </section>;
}
