# Elder's banking app (C): calm, big text, big buttons. Phone frame on a laptop, full screen on a real phone.
# /phone?citizen=c_seeya (default) or c_kamala. Follows the citizen's latest request, so scenarios run from
# the control panel show up here too. While the Scam-Breaker is active it takes over the screen (M4).
import from react { useEffect }
import from "@jac/runtime" { useLocation }
import from .i18n { t, tf, money, known_key }
import from .ui { Header, Card, Bar, theme, pressure_color, pressure_key, last_report, query_param, only_digits }
import from .scam_breaker { ScamBreakerCard }

sv import from ..walkers.api { get_phone, set_language, start_request, telemetry_update, submit_request }

glob NAMES: dict[str, str] = {"c_seeya": "Seeya", "c_kamala": "Kamala"};

# The three things an elder can start: i18n key + default payee / reference.
glob ACTIONS: list[dict[str, str]] = [
    {"action": "BREAK_FD", "key": "phone.break_fd", "payee": "", "reference": ""},
    {"action": "TRANSFER", "key": "phone.transfer", "payee": "", "reference": ""},
    {"action": "BILL_PAY", "key": "phone.pay_bill", "payee": "LDB-10001", "reference": "Electricity bill"}
];

# Result screens: i18n key prefix + colour.
glob RESULTS: dict[str, dict[str, str]] = {
    "ALLOWED": {"key": "result.allowed", "color": "#22c55e"},
    "DONE": {"key": "result.allowed", "color": "#22c55e"},
    "BLOCKED": {"key": "result.blocked", "color": "#ef4444"},
    "HELD": {"key": "result.held", "color": "#f59e0b"},
    "STEP_UP": {"key": "result.step_up", "color": "#f59e0b"}
};

glob BIG_BUTTON: dict[str, str] = {"padding": "18px", "fontSize": "21px", "fontWeight": "700", "borderRadius": "16px",
                                  "border": "none", "cursor": "pointer", "width": "100%"};
glob INPUT: dict[str, str] = {"padding": "14px", "fontSize": "22px", "borderRadius": "12px", "border": "2px solid #cbd5e1",
                             "width": "100%", "boxSizing": "border-box"};

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
def:pub ResultCard(screen: str, lang: str, message: str, onHome: Callable[[], None]) -> JsxElement {
    result = RESULTS[screen];
    return <Card accent={result["color"]}>
        <h3 style={{"margin": "0 0 6px", "fontSize": "28px", "color": result["color"]}}>{t(result["key"] + ".title", lang)}</h3>
        <p style={{"fontSize": "22px", "margin": "0 0 14px"}}>{t(message, lang) if known_key(message) else t(result["key"] + ".body", lang)}</p>
        <button style={{**BIG_BUTTON, "background": "#e2e8f0", "color": "#0f172a"}} onClick={lambda (e: MouseEvent) { onHome(); }}>
            {t("result.back_home", lang)}
        </button>
    </Card>;
}

"""A labelled form field."""
def:pub Field(label: str, children: any = None) -> JsxElement {
    return <label style={{"display": "flex", "flexDirection": "column", "gap": "6px", "fontSize": "17px", "color": "#334155"}}>
        {label}
        {children}
    </label>;
}

def:pub Phone() -> JsxElement {
    has data: dict[str, any] = {},
        lang: str = "en",
        lang_set: bool = False,
        step: str = "",              # "" = show the server screen | form | otp | checking
        action: str = "BREAK_FD",
        amount: str = "",
        payee: str = "",
        reference: str = "",
        otp: str = "",
        error: str = "",
        rid: str = "",               # this phone's own request ("" = follow the latest)
        dismissed: str = "",         # server screen the elder closed with "Back to home"
        opened_at: float = 0,        # form opened (ms) -> hesitation
        backtracks: int = 0,
        pasted: bool = False;

    citizen = query_param(useLocation().search as str, "citizen") or "c_seeya";
    watch = rid or "latest:" + citizen;

    async def load() {
        fresh = last_report(root spawn get_phone(request_id=watch));
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
        root spawn set_language(person_id=citizen, language=code);
    }

    def open_form(choice: dict[str, str]) {
        chosen = choice["action"];      # local: `action` keeps its old value until the next render
        action = chosen;
        amount = str(data["fd"]) if chosen == "BREAK_FD" else ("4500" if chosen == "BILL_PAY" else "");
        payee = choice["payee"];
        reference = choice["reference"];
        otp = "";
        error = "";
        backtracks = 0;
        pasted = False;
        opened_at = Date.now();
        step = "form";
    }

    async def mark_pasted() {
        pasted = True;
        root spawn telemetry_update(request_id="", signals={"pasted_account": True});
    }

    async def paste_account() {
        try {
            clip = await navigator.clipboard.readText();  # jac:ignore[E1030]
            payee = str(clip).strip();
        } except Exception {
            payee = payee;
        }
        mark_pasted();
    }

    def count_backspace(e: KeyboardEvent) {
        if e.key == "Backspace" {
            backtracks = backtracks + 1;
        }
    }

    async def go_otp() {
        value = int(amount.strip()) if only_digits(amount.strip()) else 0;
        if value <= 0 or not payee.strip() {
            error = t("form.missing", lang);
            return;
        }
        error = "";
        # Real signals measured on this phone, sent before the request so it starts with them.
        root spawn telemetry_update(request_id="", signals={"hesitation_ms": int(Date.now() - opened_at), "backtracks": backtracks});
        started = last_report(root spawn start_request(citizen_id=citizen, action=action, amount=value,
                                                        payee=payee.strip(), reference=reference));
        rid = started["request_id"] as str;
        step = "otp";
    }

    async def confirm() {
        if len(otp.strip()) != 6 or not only_digits(otp.strip()) {
            error = t("form.otp_wrong", lang);
            return;
        }
        error = "";
        step = "checking";
        root spawn submit_request(request_id=rid);
        dismissed = "";
        step = "";
        load();
    }

    def go_home() {
        dismissed = (data["screen"] or "") as str;
        rid = "";
        step = "";
    }

    useEffect(lambda {
        load();
        timer = setInterval(lambda { load(); }, 1000);
        return lambda { clearInterval(timer); };
    }, [watch]);

    if not data["screen"] {
        return <PhoneFrame><p style={{"padding": "24px"}}>{t("common.loading", lang)}</p></PhoneFrame>;
    }
    screen = data["screen"] as str;
    sb = (data["scam_breaker"] or {}) as dict[str, any];
    show_breaker = step == "" and bool(sb["active"]);
    show_result = step == "" and screen in RESULTS and screen != dismissed;
    title_key = [a["key"] for a in ACTIONS if a["action"] == action][0];
    return <PhoneFrame>
        <Header title={t("screen.phone", lang)} lang={lang} onLang={change_lang} />
        <PressureMeter value={data["pressure"] as int} lang={lang} />
        <div style={{"padding": "16px", "display": "flex", "flexDirection": "column", "gap": "14px"}}>
            {if step == "form" {
                <h2 style={{"margin": "4px 0", "fontSize": "26px"}}>{t(title_key, lang)}</h2>
                <Field label={t("form.amount", lang)}>
                    <input style={INPUT} inputMode="numeric" value={amount} onKeyDown={count_backspace}
                        onChange={lambda (e: ChangeEvent) { amount = e.target.value; }} />
                </Field>
                <Field label={t("form.account", lang)}>
                    <div style={{"display": "flex", "gap": "8px"}}>
                        <input style={INPUT} value={payee} placeholder={t("form.account_hint", lang)} onKeyDown={count_backspace}
                            onPaste={lambda (e: Event) { mark_pasted(); }}
                            onChange={lambda (e: ChangeEvent) { payee = e.target.value; }} />
                        <button style={{**BIG_BUTTON, "width": "auto", "fontSize": "16px", "background": "#e2e8f0"}}
                            onClick={lambda (e: MouseEvent) { paste_account(); }}>{t("form.paste", lang)}</button>
                    </div>
                </Field>
                <Field label={t("form.reference", lang)}>
                    <input style={INPUT} value={reference} onKeyDown={count_backspace}
                        onChange={lambda (e: ChangeEvent) { reference = e.target.value; }} />
                </Field>
                if error { <p style={{"color": "#b91c1c", "fontSize": "18px", "margin": "0"}}>{error}</p> }
                <button style={{**BIG_BUTTON, "background": "#0f766e", "color": "#ffffff"}}
                    onClick={lambda (e: MouseEvent) { go_otp(); }}>{t("transfer.continue", lang)}</button>
                <button style={{**BIG_BUTTON, "background": "transparent", "color": "#475569"}}
                    onClick={lambda (e: MouseEvent) { step = ""; }}>{t("form.cancel", lang)}</button>
            } elif step == "otp" or step == "checking" {
                <Card>
                    <p style={{"fontSize": "21px", "margin": "0"}}>{tf("form.summary", lang, {"amount": money(int(amount)), "payee": payee})}</p>
                </Card>
                <Field label={t("form.otp", lang)}>
                    <input style={{**INPUT, "letterSpacing": "8px", "textAlign": "center"}} inputMode="numeric" maxLength={6}
                        value={otp} onChange={lambda (e: ChangeEvent) { otp = e.target.value; }} />
                </Field>
                <p style={{"fontSize": "15px", "color": "#64748b", "margin": "0"}}>{t("form.otp_hint", lang)}</p>
                if error { <p style={{"color": "#b91c1c", "fontSize": "18px", "margin": "0"}}>{error}</p> }
                <button disabled={step == "checking"} style={{**BIG_BUTTON, "background": "#0f766e", "color": "#ffffff"}}
                    onClick={lambda (e: MouseEvent) { confirm(); }}>
                    {t("transfer.checking", lang) if step == "checking" else t("transfer.confirm", lang)}
                </button>
            } elif show_breaker {
                <ScamBreakerCard sb={sb} request_id={watch} lang={lang} onAnswered={load} />
            } elif show_result {
                <ResultCard screen={screen} lang={lang} message={(data["message"] or "") as str} onHome={go_home} />
            } else {
                <h2 style={{"margin": "4px 0", "fontSize": "26px"}}>{tf("phone.hello", lang, {"name": NAMES[citizen] or citizen})}</h2>
                <Card title={t("phone.balance", lang)}><div style={{"fontSize": "30px", "fontWeight": "800"}}>{money(data["balance"])}</div></Card>
                <Card title={t("phone.fd", lang)}><div style={{"fontSize": "30px", "fontWeight": "800"}}>{money(data["fd"])}</div></Card>
                <p style={{"fontSize": "19px", "margin": "6px 0 0"}}>{t("phone.choose", lang)}</p>
                for a in ACTIONS {
                    <button key={a["action"]} style={{**BIG_BUTTON, "background": "#ffffff", "color": "#0f172a", "border": "2px solid #0f766e"}}
                        onClick={lambda (e: MouseEvent) { open_form(a); }}>{t(a["key"], lang)}</button>
                }
            }}
        </div>
    </PhoneFrame>;
}
