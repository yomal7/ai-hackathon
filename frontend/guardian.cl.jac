# Guardian's phone (C): /guardian?id=g_dilshan. Card in the guardian's language + Reject / Approve / Call now.
# M1 shell; sound, vibration and the full card design come in M4.
import from react { useEffect }
import from "@jac/runtime" { useLocation }
import from .i18n { t, tf }
import from .ui { Header, Card, Badge, theme, rows, last_report, query_param }
import from .phone { PhoneFrame }

sv import from ..walkers.api { get_guardian, guardian_answer, set_language }

# Buttons: answer -> i18n key + colour.
glob BUTTONS: list[dict[str, str]] = [
    {"answer": "REJECT", "key": "guardian.reject", "color": "#dc2626"},
    {"answer": "APPROVE", "key": "guardian.approve", "color": "#16a34a"},
    {"answer": "CALL", "key": "guardian.call", "color": "#2563eb"}
];

"""One guardian alert card with its buttons. A button not in options is disabled (locked hold)."""
def:pub GuardianAlert(alert: dict[str, any], lang: str) -> JsxElement {
    alert_id = alert["id"] as str;
    options = alert["options"] as list[str];

    async def answer(choice: str) {
        root spawn guardian_answer(alert_id=alert_id, answer=choice);
    }

    return <Card accent="#dc2626">
        <h2 style={{"margin": "0 0 10px", "fontSize": "24px"}}>{alert["title"]}</h2>
        {for (i, line) in enumerate(alert["lines"] as list[str]) {
            <p key={str(i)} style={{"fontSize": "19px", "margin": "6px 0"}}>{line}</p>
        }}
        {if alert["status"] == "ANSWERED" {
            <Badge text={tf("guardian.your_answer", lang, {"answer": alert["answer"]})} color="#16a34a" />
        } else {
            <div style={{"display": "flex", "flexDirection": "column", "gap": "10px", "marginTop": "12px"}}>
                {for b in BUTTONS {
                    <button
                        key={b["answer"]}
                        disabled={b["answer"] not in options}
                        onClick={lambda (e: MouseEvent) { answer(b["answer"]); }}
                        style={{"padding": "16px", "fontSize": "20px", "fontWeight": "700", "borderRadius": "14px", "border": "none",
                                "color": "#ffffff", "background": b["color"], "opacity": 1 if b["answer"] in options else 0.35,
                                "cursor": "pointer"}}
                    >{t(b["key"], lang)}</button>
                }}
                {"APPROVE" not in options and <p style={{"fontSize": "14px", "color": "#64748b", "margin": "0"}}>{t("guardian.locked", lang)}</p>}
            </div>
        }}
    </Card>;
}

def:pub GuardianScreen() -> JsxElement {
    has data: dict[str, any] = {},
        lang: str = "en",
        lang_set: bool = False;

    guardian_id = query_param(useLocation().search as str, "id") or "g_dilshan";

    async def load() {
        fresh = last_report(root spawn get_guardian(guardian_id=guardian_id));
        if fresh {
            data = fresh;
            if not lang_set {
                lang = fresh["language"] as str;
                lang_set = True;
            }
        }
    }

    async def change_lang(code: str) {
        lang = code;
        lang_set = True;
        root spawn set_language(person_id=guardian_id, language=code);
    }

    useEffect(lambda {
        load();
        timer = setInterval(lambda { load(); }, 1000);
        return lambda { clearInterval(timer); };
    }, [guardian_id]);

    alerts = rows(data["alerts"]);
    return <PhoneFrame>
        <Header title={t("screen.guardian", lang)} lang={lang} onLang={change_lang} />
        <div style={{"padding": "16px", "display": "flex", "flexDirection": "column", "gap": "14px", "background": theme(False)["bg"]}}>
            {data["name"] and <p style={{"margin": "0", "color": "#64748b"}}>{data["name"]}</p>}
            {if len(alerts) == 0 {
                <Card><p style={{"fontSize": "20px", "margin": "0"}}>{t("guardian.no_alerts", lang)}</p></Card>
            }}
            {for a in alerts {
                <GuardianAlert key={a["id"]} alert={a} lang={lang} />
            }}
        </div>
    </PhoneFrame>;
}
