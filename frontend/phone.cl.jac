# Elder's banking app (C): calm, big text, big buttons. Phone frame on a laptop, full screen on a real phone.
# /phone?citizen=c_seeya (default) or c_kamala. Follows the citizen's latest request, so scenarios run from
# the control panel show up here too. While the Scam-Breaker is active it takes over the screen (M4).
# Paper skin (theme.cl.jac): warm paper, ink borders, hard shadows.
import from react { useEffect }
import from "@jac/runtime" { useLocation }
import from .i18n { t, tf, money, known_key }
import from .ui { Header, Card, Button, Icon, Label, Spinner, theme, pressure_fill, pressure_key, last_report, query_param, only_digits, poll_begin, poll_end }
import from .theme { PAPER, FILL, DISPLAY, MONO }
import from .scam_breaker { ScamBreakerCard }

sv import from ..walkers.api { get_phone, set_language, start_request, telemetry_update, submit_request }

glob NAMES: dict[str, str] = {"c_seeya": "Seeya", "c_kamala": "Kamala"};

# The three things an elder can start: i18n key + default payee / reference + icon.
glob ACTIONS: list[dict[str, str]] = [
    {"action": "BREAK_FD", "key": "phone.break_fd", "payee": "", "reference": "", "icon": "bank"},
    {"action": "TRANSFER", "key": "phone.transfer", "payee": "", "reference": "", "icon": "send"},
    {"action": "BILL_PAY", "key": "phone.pay_bill", "payee": "LDB-10001", "reference": "Electricity bill", "icon": "home"}
];

# Result screens: i18n key prefix + fill colour + icon.
glob RESULTS: dict[str, dict[str, str]] = {
    "ALLOWED": {"key": "result.allowed", "fill": "#7BD88F", "icon": "check"},
    "DONE": {"key": "result.allowed", "fill": "#7BD88F", "icon": "check"},
    "BLOCKED": {"key": "result.blocked", "fill": "#FF7A6B", "icon": "shield"},
    "HELD": {"key": "result.held", "fill": "#FFC94A", "icon": "clock"},
    "STEP_UP": {"key": "result.step_up", "fill": "#FFC94A", "icon": "alert"}
};

glob INPUT: dict[str, str] = {"padding": "14px", "fontSize": "22px", "borderRadius": "10px", "border": "2px solid #16140F",
                             "background": "#FFFCF5", "color": "#16140F", "width": "100%", "minWidth": "0"};

"""Phone-shaped frame on wide screens, plain full screen on a real phone."""
def:pub PhoneFrame(children: any = None) -> JsxElement {
    wide = window.innerWidth > 600;
    frame = {"width": "400px", "minHeight": "800px", "margin": "28px auto", "borderRadius": "38px",
             "border": "10px solid #16140F", "overflow": "hidden", "boxShadow": "10px 10px 0 #16140F"};
    page = {"background": "#E3DCCD", "backgroundImage": "radial-gradient(#C9C0AE 1px, transparent 1px)",
            "backgroundSize": "18px 18px", "minHeight": "100vh", "padding": "1px 0"};
    return <div style={page if wide else {"background": PAPER["bg"], "minHeight": "100vh"}}>
        <div style={frame if wide else {"minHeight": "100vh"}}>
            <div style={{"background": PAPER["bg"], "minHeight": "780px" if wide else "100vh", "color": PAPER["text"]}}>{children}</div>
        </div>
    </div>;
}

"""Live pressure meter: a chunky 10-segment bar + a word (calm / rising / high)."""
def:pub PressureMeter(value: int, lang: str) -> JsxElement {
    fill = pressure_fill(value);
    lit = round(value / 10);
    return <div style={{"padding": "12px 16px", "borderBottom": "2px solid #16140F", "background": PAPER["card"]}}>
        <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center", "marginBottom": "8px"}}>
            <span style={{"fontSize": "16px", "fontWeight": "700"}}>{t("pressure.label", lang)}</span>
            <span style={{"fontSize": "15px", "fontWeight": "700", "background": fill, "border": "2px solid #16140F",
                          "borderRadius": "6px", "padding": "0 8px"}}>{t(pressure_key(value), lang)}</span>
        </div>
        <div role="meter" aria-valuemin={0} aria-valuemax={100} aria-valuenow={value} style={{"display": "flex", "gap": "4px"}}>
            {for i in range(10) {
                <span key={str(i)} style={{"flex": "1", "height": "14px", "borderRadius": "3px", "border": "2px solid #16140F",
                                           "background": fill if i < lit else PAPER["sunk"], "transition": "background 0.3s ease"}} />
            }}
        </div>
    </div>;
}

"""Result card (allowed / blocked / held / step-up) in the elder's language, stamped in."""
def:pub ResultCard(screen: str, lang: str, message: str, onHome: Callable[[], None]) -> JsxElement {
    result = RESULTS[screen];
    return <Card accent={result["fill"]}>
        <div style={{"display": "flex", "alignItems": "center", "gap": "14px", "marginBottom": "10px"}}>
            <span style={{"width": "56px", "height": "56px", "borderRadius": "50%", "background": "#16140F", "display": "inline-flex",
                          "alignItems": "center", "justifyContent": "center", "flexShrink": "0"}}>
                <Icon name={result["icon"]} size={30} color={result["fill"]} stroke={2.6} />
            </span>
            <h2 style={{"margin": "0", "fontFamily": DISPLAY, "fontSize": "34px", "lineHeight": "1.1", "fontWeight": "800",
                        "animation": "rkStamp 0.4s ease-out both"}}>{t(result["key"] + ".title", lang)}</h2>
        </div>
        <p style={{"fontSize": "21px", "lineHeight": "1.5", "margin": "0 0 16px"}}>{t(message, lang) if known_key(message) else t(result["key"] + ".body", lang)}</p>
        <Button label={t("result.back_home", lang)} icon="home" full={True} size="lg" onClick={onHome} />
    </Card>;
}

"""A labelled form field."""
def:pub Field(label: str, children: any = None) -> JsxElement {
    return <label style={{"display": "flex", "flexDirection": "column", "gap": "6px", "fontSize": "18px", "fontWeight": "700"}}>
        {label}
        {children}
    </label>;
}

"""One balance tile on the home screen."""
def:pub Balance(label: str, amount: any) -> JsxElement {
    return <Card>
        <Label text={label} />
        <div style={{"fontFamily": DISPLAY, "fontSize": "34px", "fontWeight": "800", "fontVariantNumeric": "tabular-nums",
                     "letterSpacing": "-0.01em"}}>{money(amount)}</div>
    </Card>;
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
        busy: bool = False,          # waiting for start_request
        rid: str = "",               # this phone's own request ("" = follow the latest)
        dismissed: str = "",         # server screen the elder closed with "Back to home"
        opened_at: float = 0,        # form opened (ms) -> hesitation
        backtracks: int = 0,
        pasted: bool = False;

    citizen = query_param(useLocation().search as str, "citizen") or "c_seeya";
    watch = rid or "latest:" + citizen;

    async def load() {
        if not poll_begin("phone") {
            return;
        }
        try {
            fresh = last_report(root spawn get_phone(request_id=watch));
            if fresh {
                data = fresh;
                if not lang_set {
                    lang = fresh["language"] as str;
                    lang_set = True;
                }
            }
        } except Exception {
            console.warn("[phone] load failed");
        }
        poll_end("phone");
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
        busy = True;
        # Real signals measured on this phone, sent before the request so it starts with them.
        root spawn telemetry_update(request_id="", signals={"hesitation_ms": int(Date.now() - opened_at), "backtracks": backtracks});
        started = last_report(root spawn start_request(citizen_id=citizen, action=action, amount=value,
                                                        payee=payee.strip(), reference=reference));
        busy = False;
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
        return <PhoneFrame>
            <div style={{"padding": "40px 24px", "display": "flex", "alignItems": "center", "gap": "12px", "fontSize": "22px", "fontWeight": "700"}}>
                <Spinner size={22} />{t("common.loading", lang)}
            </div>
        </PhoneFrame>;
    }
    screen = data["screen"] as str;
    sb = (data["scam_breaker"] or {}) as dict[str, any];
    show_breaker = step == "" and bool(sb["active"]);
    show_result = step == "" and screen in RESULTS and screen != dismissed;
    title_key = [a["key"] for a in ACTIONS if a["action"] == action][0];
    err = error and <p role="alert" style={{"background": FILL["danger"], "border": "2px solid #16140F", "borderRadius": "8px",
                                            "padding": "8px 12px", "fontSize": "18px", "fontWeight": "700", "margin": "0"}}>{error}</p>;
    return <PhoneFrame>
        <Header title={t("screen.phone", lang)} lang={lang} onLang={change_lang} />
        <PressureMeter value={data["pressure"] as int} lang={lang} />
        <div lang={lang} style={{"padding": "18px 16px 28px", "display": "flex", "flexDirection": "column", "gap": "16px"}}>
            {if step == "form" {
                <h2 style={{"margin": "0", "fontFamily": DISPLAY, "fontSize": "30px", "fontWeight": "800"}}>{t(title_key, lang)}</h2>
                <Field label={t("form.amount", lang)}>
                    <input style={{**INPUT, "fontFamily": DISPLAY, "fontWeight": "700"}} inputMode="numeric" value={amount} onKeyDown={count_backspace}
                        onChange={lambda (e: ChangeEvent) { amount = e.target.value; }} />
                </Field>
                <Field label={t("form.account", lang)}>
                    <div style={{"display": "flex", "gap": "8px"}}>
                        <input style={{**INPUT, "fontFamily": MONO, "fontSize": "20px"}} value={payee} placeholder={t("form.account_hint", lang)}
                            onKeyDown={count_backspace}
                            onPaste={lambda (e: Event) { mark_pasted(); }}
                            onChange={lambda (e: ChangeEvent) { payee = e.target.value; }} />
                        <Button label={t("form.paste", lang)} onClick={paste_account} />
                    </div>
                </Field>
                <Field label={t("form.reference", lang)}>
                    <input style={INPUT} value={reference} onKeyDown={count_backspace}
                        onChange={lambda (e: ChangeEvent) { reference = e.target.value; }} />
                </Field>
                err;
                <Button label={t("transfer.continue", lang)} kind="primary" size="lg" full={True} icon="arrow" busy={busy} onClick={go_otp} />
                <Button label={t("form.cancel", lang)} kind="ghost" full={True} onClick={lambda { step = ""; }} />
            } elif step == "otp" or step == "checking" {
                <Card>
                    <p style={{"fontSize": "21px", "lineHeight": "1.5", "margin": "0"}}>{tf("form.summary", lang, {"amount": money(int(amount)), "payee": payee})}</p>
                </Card>
                <Field label={t("form.otp", lang)}>
                    <input style={{**INPUT, "fontFamily": MONO, "letterSpacing": "10px", "textAlign": "center", "fontSize": "28px"}}
                        inputMode="numeric" maxLength={6} value={otp} onChange={lambda (e: ChangeEvent) { otp = e.target.value; }} />
                </Field>
                <p style={{"fontSize": "16px", "color": PAPER["muted"], "margin": "0"}}>{t("form.otp_hint", lang)}</p>
                err;
                <Button label={t("transfer.checking", lang) if step == "checking" else t("transfer.confirm", lang)}
                    kind="primary" size="lg" full={True} icon="check" busy={step == "checking"} onClick={confirm} />
            } elif show_breaker {
                <ScamBreakerCard sb={sb} request_id={watch} lang={lang} onAnswered={load} />
            } elif show_result {
                <ResultCard screen={screen} lang={lang} message={(data["message"] or "") as str} onHome={go_home} />
            } else {
                <h2 style={{"margin": "0", "fontFamily": DISPLAY, "fontSize": "32px", "fontWeight": "800", "lineHeight": "1.15"}}>
                    {tf("phone.hello", lang, {"name": NAMES[citizen] or citizen})}
                </h2>
                <Balance label={t("phone.balance", lang)} amount={data["balance"]} />
                <Balance label={t("phone.fd", lang)} amount={data["fd"]} />
                <p style={{"fontSize": "20px", "fontWeight": "700", "margin": "6px 0 0"}}>{t("phone.choose", lang)}</p>
                for a in ACTIONS {
                    <Button key={a["action"]} label={t(a["key"], lang)} icon={a["icon"]} size="lg" full={True}
                        onClick={lambda { open_form(a); }} />
                }
            }}
        </div>
    </PhoneFrame>;
}
