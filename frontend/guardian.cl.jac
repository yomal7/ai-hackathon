# Guardian's phone: Approve / Reject / Call card. Placeholder written by A - C owns this file (C)
import from .i18n { t }

def:pub GuardianScreen(lang: str = "en") -> JsxElement {
    return <section>
        <p>{t("sim.banner", lang)}</p>
        <h2>{t("screen.guardian", lang)}</h2>
    </section>;
}
