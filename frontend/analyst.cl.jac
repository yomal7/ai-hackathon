# Bank fraud analyst cards inside the War Room (C): Approve freeze / Keep open -> analyst_answer.
import from .i18n { t, ops_lang }
import from .ui { Card, Badge, Button }
import from .theme { INK, SIGNAL, DISPLAY }

sv import from ..walkers.api { analyst_answer }


"""One analyst alert with its two buttons."""
def:pub AnalystCard(alert: dict[str, any]) -> JsxElement {
    has sending: bool = False;

    alert_id = alert["id"] as str;

    async def answer(choice: str) {
        sending = True;
        root spawn analyst_answer(alert_id=alert_id, answer=choice);
        sending = False;
    }

    return <Card dark={True} accent="#B19CFF" title={t("screen.analyst", ops_lang())}>
        <strong style={{"fontFamily": DISPLAY, "fontSize": "18px", "lineHeight": "1.35", "display": "block"}}>{alert["title"]}</strong>
        <ul style={{"margin": "8px 0", "paddingLeft": "18px", "fontSize": "14px", "color": "#CFCBC1"}}>
            {for (i, line) in enumerate(alert["lines"] as list[str]) {
                <li key={str(i)}>{line}</li>
            }}
        </ul>
        {if alert["status"] == "ANSWERED" {
            <Badge text={alert["answer"] as str} color="#5BD48A" />
        } else {
            <div style={{"display": "grid", "gridTemplateColumns": "1fr 1fr", "gap": "8px"}}>
                <Button label={t("analyst.approve", ops_lang())} kind="primary" icon="snow" dark={True} busy={sending}
                    onClick={lambda { answer("APPROVE"); }} />
                <Button label={t("analyst.keep_open", ops_lang())} kind="plain" dark={True} disabled={sending}
                    onClick={lambda { answer("KEEP_OPEN"); }} />
            </div>
        }}
    </Card>;
}

"""All analyst alerts from the War Room data."""
def:pub AnalystPanel(alerts: list[dict[str, any]]) -> JsxElement {
    mine = [a for a in alerts if a["kind"] == "ANALYST"];
    return <div style={{"display": "flex", "flexDirection": "column", "gap": "10px"}}>
        {if len(mine) == 0 {
            <Card dark={True} title={t("screen.analyst", ops_lang())}><span>{t("analyst.none", ops_lang())}</span></Card>
        }}
        {for a in mine {
            <AnalystCard key={a["id"]} alert={a} />
        }}
    </div>;
}
