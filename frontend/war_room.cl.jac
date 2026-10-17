# War Room: agent cards, ruling, counters, timeline. Placeholder written by A - C owns this file (C)
import from .i18n { t }

def:pub WarRoom(lang: str = "en") -> JsxElement {
    return <section>
        <p>{t("sim.banner", lang)}</p>
        <h2>{t("screen.war_room", lang)}</h2>
    </section>;
}
