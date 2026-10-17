# Elder's banking app (C): calm, big text, big buttons. Phone frame on a laptop, full screen on a phone.
# M1 shell: home + live pressure + current result. The transfer form comes in M2, Scam-Breaker in M4.
import from react { useEffect }
import from "@jac/runtime" { useLocation }
import from .i18n { t, tf, money }
import from .ui { Header, Card, Bar, theme, pressure_color, pressure_key, first_report, query_param }

sv import from ..walkers.api { get_phone, set_language }

glob CITIZEN: str = "c_seeya";
glob NAMES: dict[str, str] = {"c_seeya": "Seeya", "c_kamala": "Kamala"};

# Result screens: i18n key prefix + colour.
glob RESULTS: dict[str, dict[str, str]] = {
    "ALLOWED": {"key": "result.allowed", "color": "#22c55e"},
    "BLOCKED": {"key": "result.blocked", "color": "#ef4444"},
    "HELD": {"key": "result.held", "color": "#f59e0b"},
    "STEP_UP": {"key": "result.step_up", "color": "#f59e0b"}
};

"""Phone-shaped frame on wide screens, plain full screen on a real phone."""
def:pub PhoneFrame(children: any = None) -> JsxElement {
    wide = window.innerWidth > 600;
    frame = {"width": "390px", "minHeight": "780px", "margin": "24px auto", "borderRadius": "36px",
             "border": "10px solid #0f172a", "overflow": "hidden", "boxShadow": "0 20px 50px rgba(0,0,0,0.25)"};
    return <div style={{"background": "#cbd5e1" if wide else theme(False)["bg"], "minHeight": "100vh", "padding": "1px 0"}}>
        <div style={frame if wide else {"minHeight": "100vh"}}>
            <div style={{"background": theme(False)["bg"], "minHeight": "100%"}}>{children}</div>
        </div>
    </div>;
}

"""Small live pressure meter at the top."""
def:pub PressureMeter(value: int, lang: str) -> JsxElement {
    c = pressure_color(value);
    return <div style={{"padding": "10px 16px", "background": "#ffffff", "borderBottom": "1px solid #e2e8f0"}}>
        <div style={{"display": "flex", "justifyContent": "space-between", "fontSize": "14px", "marginBottom": "4px"}}>
            <span>{t("pressure.label", lang)}</span>
            <strong style={{"color": c}}>{t(pressure_key(value), lang)}</strong>
        </div>
        <Bar value={value / 100} color={c} height={10} />
    </div>;
}

"""Result card (allowed / blocked / held / step-up) in the elder's language."""
def:pub ResultCard(screen: str, lang: str) -> JsxElement {
    result = RESULTS[screen];
    return <Card accent={result["color"]}>
        <h3 style={{"margin": "0 0 6px", "fontSize": "26px", "color": result["color"]}}>{t(result["key"] + ".title", lang)}</h3>
        <p style={{"fontSize": "22px", "margin": "0"}}>{t(result["key"] + ".body", lang)}</p>
    </Card>;
}

def:pub Phone() -> JsxElement {
    has data: dict[str, any] = {},
        lang: str = "en",
        lang_set: bool = False;

    request_id = query_param(useLocation().search as str, "request");

    async def load() {
        fresh = first_report(root spawn get_phone(request_id=request_id));
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
        root spawn set_language(person_id=CITIZEN, language=code);
    }

    useEffect(lambda {
        load();
        timer = setInterval(lambda { load(); }, 1000);
        return lambda { clearInterval(timer); };
    }, [request_id]);

    if not data["screen"] {
        return <PhoneFrame><p style={{"padding": "24px"}}>{t("common.loading", lang)}</p></PhoneFrame>;
    }
    screen = data["screen"] as str;
    big_number = {"fontSize": "30px", "fontWeight": "800"};
    return <PhoneFrame>
        <Header title={t("screen.phone", lang)} lang={lang} onLang={change_lang} />
        <PressureMeter value={data["pressure"] as int} lang={lang} />
        <div style={{"padding": "16px", "display": "flex", "flexDirection": "column", "gap": "14px"}}>
            <h2 style={{"margin": "4px 0", "fontSize": "26px"}}>{tf("phone.hello", lang, {"name": NAMES[CITIZEN]})}</h2>
            {screen in RESULTS and <ResultCard screen={screen} lang={lang} />}
            <Card title={t("phone.balance", lang)}><div style={big_number}>{money(data["balance"])}</div></Card>
            <Card title={t("phone.fd", lang)}><div style={big_number}>{money(data["fd"])}</div></Card>
        </div>
    </PhoneFrame>;
}
