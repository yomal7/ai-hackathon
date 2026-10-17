# Bank fraud analyst cards inside the War Room (C): Approve freeze / Keep open -> analyst_answer.
import from .i18n { t }
import from .ui { Card, Badge }

sv import from ..walkers.api { analyst_answer }

glob LANG: str = "en";

"""One analyst alert with its two buttons."""
def:pub AnalystCard(alert: dict[str, any]) -> JsxElement {
    has sending: bool = False;

    alert_id = alert["id"] as str;

    async def answer(choice: str) {
        sending = True;
        root spawn analyst_answer(alert_id=alert_id, answer=choice);
        sending = False;
    }

    button = {"flex": "1", "padding": "10px", "borderRadius": "10px", "fontWeight": "700", "cursor": "pointer"};
    return <Card dark={True} accent="#a78bfa" title={t("screen.analyst", LANG)}>
        <strong style={{"fontSize": "17px"}}>{alert["title"]}</strong>
        <ul style={{"margin": "8px 0", "paddingLeft": "18px", "fontSize": "14px", "color": "#cbd5e1"}}>
            {for (i, line) in enumerate(alert["lines"] as list[str]) {
                <li key={str(i)}>{line}</li>
            }}
        </ul>
        {if alert["status"] == "ANSWERED" {
            <Badge text={alert["answer"] as str} color="#22c55e" />
        } else {
            <div style={{"display": "flex", "gap": "8px"}}>
                <button disabled={sending} onClick={lambda (e: MouseEvent) { answer("APPROVE"); }}
                    style={{**button, "border": "none", "background": "#67e8f9", "color": "#0b1120"}}
                >{t("analyst.approve", LANG)}</button>
                <button disabled={sending} onClick={lambda (e: MouseEvent) { answer("KEEP_OPEN"); }}
                    style={{**button, "border": "1px solid #475569", "background": "transparent", "color": "#e2e8f0"}}
                >{t("analyst.keep_open", LANG)}</button>
            </div>
        }}
    </Card>;
}

"""All analyst alerts from the War Room data."""
def:pub AnalystPanel(alerts: list[dict[str, any]]) -> JsxElement {
    mine = [a for a in alerts if a["kind"] == "ANALYST"];
    return <div style={{"display": "flex", "flexDirection": "column", "gap": "10px"}}>
        {if len(mine) == 0 {
            <Card dark={True} title={t("screen.analyst", LANG)}><span>{t("analyst.none", LANG)}</span></Card>
        }}
        {for a in mine {
            <AnalystCard key={a["id"]} alert={a} />
        }}
    </div>;
}
