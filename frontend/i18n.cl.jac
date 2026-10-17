# UI text for si / ta / en (C). All user-facing text goes through t(key, lang).
# Sinhala / Tamil strings: to be checked by a native speaker.
# For now only English is complete - a missing si/ta key falls back to English.
# Keep one entry per line: tests/i18n_tests.jac reads this file as text.

glob LANGS: list[str] = ["si", "ta", "en"];

glob EN: dict[str, str] = {
    "sim.banner": "Simulation — fictional data",
    "app.name": "Rakshaka",
    "app.tagline": "Stops scammers from emptying elders' bank accounts",
    "lang.si": "සිං",
    "lang.ta": "தமிழ்",
    "lang.en": "EN",
    "common.loading": "Loading…",
    "common.error": "Something went wrong. Please try again.",
    "common.back": "Back",
    "common.home": "Home",
    "common.close": "Close",
    "screen.phone": "My Bank",
    "screen.telemetry": "Demo control panel",
    "screen.war_room": "War Room",
    "screen.graph": "Trust graph",
    "screen.guardian": "Family check",
    "screen.analyst": "Fraud analyst",
    "screen.story": "What happened",
    "nav.phone": "Phone",
    "nav.telemetry": "Control",
    "nav.war_room": "War Room",
    "nav.guardian": "Guardian",
    "nav.story": "Story",
    "phone.hello": "Hello, {name}",
    "phone.balance": "Savings balance",
    "phone.fd": "Fixed deposit",
    "phone.break_fd": "Break fixed deposit",
    "phone.transfer": "Send money",
    "phone.pay_bill": "Pay a bill",
    "phone.choose": "What would you like to do?",
    "form.amount": "Amount (Rs)",
    "form.account": "To account number",
    "form.paste": "Paste",
    "form.reference": "Note (any language)",
    "form.otp": "OTP code",
    "form.otp_hint": "We sent a 6-digit code to your phone (demo: any 6 digits)",
    "form.missing": "Please fill in the amount and the account.",
    "form.otp_wrong": "Please enter the 6-digit code.",
    "form.cancel": "Cancel",
    "form.summary": "You are sending {amount} to {payee}.",
    "form.account_hint": "e.g. LDB-77821",
    "result.back_home": "Back to home",
    "phone.msg.scam_breaker": "Please answer a few short questions. We are checking this together with you.",
    "phone.msg.held": "We paused this transfer for a short safety check. Your money is safe.",
    "phone.msg.blocked_protected": "Stopped. Your family confirmed this was a scam. Your savings are safe.",
    "phone.msg.blocked": "This transfer was stopped to protect your savings.",
    "phone.msg.step_up": "We need one more check before this transfer can go.",
    "phone.msg.done": "Your money was sent.",
    "transfer.continue": "Continue",
    "transfer.confirm": "Confirm and send",
    "transfer.checking": "Checking your request…",
    "pressure.label": "Pressure",
    "pressure.calm": "Calm",
    "pressure.rising": "Rising",
    "pressure.high": "High",
    "result.allowed.title": "Done",
    "result.allowed.body": "Your money was sent.",
    "result.blocked.title": "Stopped",
    "result.blocked.body": "This transfer was stopped to protect your savings.",
    "result.held.title": "Please wait a moment",
    "result.held.body": "We paused this transfer for a short safety check. Your money is safe.",
    "result.step_up.title": "One more check",
    "result.step_up.body": "We need one more check before this transfer can go.",
    "breaker.title": "Let's check this together",
    "breaker.question_n": "Question {n} of {total}",
    "breaker.yes": "Yes",
    "breaker.no": "No",
    "breaker.unsure": "Not sure",
    "breaker.type_answer": "Or type your answer (any language)",
    "breaker.send": "Send",
    "breaker.repeat": "Repeat",
    "breaker.voice_note": "voice in English — text in your language",
    "breaker.family_asked": "Your son/daughter has been asked to check this.",
    "breaker.stay": "Please do not send money while someone is on the phone with you.",
    "guardian.for": "Family check for {name}",
    "guardian.reject": "Reject",
    "guardian.approve": "Approve",
    "guardian.call": "Call now",
    "guardian.locked": "Approve is turned off: the bank has locked this hold.",
    "guardian.no_alerts": "No alerts. All is calm.",
    "guardian.your_answer": "Your answer: {answer}",
    "guardian.new_alert": "New alert",
    "tele.note": "Simulated device signals — a real bank app's SDK provides these.",
    "tele.request": "Current request",
    "tele.none": "No request yet",
    "tele.signals": "Device signals",
    "tele.on_call": "On a phone call",
    "tele.remote_app": "Remote-access app open",
    "tele.pasted": "Account number pasted",
    "tele.hesitation": "Hesitation (ms)",
    "tele.backtracks": "Backtracks",
    "tele.scenarios": "Demo scenarios",
    "tele.reset": "Reset demo",
    "tele.voices": "Voices on this device",
    "tele.voice_used": "Will use",
    "tele.no_voice": "none — English voice + big text",
    "tele.open_phone": "Elder's phone",
    "tele.open_guardian": "Guardian's phone",
    "tele.typing_change": "Typing style changed",
    "tele.elder": "Elder",
    "tele.live": "Live phone",
    "tele.screen_now": "Phone screen",
    "tele.pressure_now": "Pressure",
    "tele.test_voice": "Test",
    "tele.voice_count": "{n} voices",
    "tele.voice_sample": "Your money is safe. Please do not send money while someone is on the phone with you.",
    "tele.lang_name.si": "Sinhala",
    "tele.lang_name.ta": "Tamil",
    "tele.lang_name.en": "English",
    "tele.qr_title": "Open on a real phone",
    "tele.base_url": "Address phones can reach (this laptop's Wi-Fi IP)",
    "tele.qr_hint": "Scan with a phone on the same Wi-Fi.",
    "tele.qr.phone_seeya": "Seeya's phone",
    "tele.qr.phone_kamala": "Kamala's phone",
    "tele.qr.guardian_dilshan": "Dilshan's phone",
    "tele.qr.guardian_priya": "Priya's phone",
    "scenario.S1": "S1 Normal day",
    "scenario.S2": "S2 Stolen password",
    "scenario.S3": "S3 The scam call",
    "scenario.S4": "S4 Network immunity",
    "scenario.S5": "S5 Hospital at 1 AM",
    "war.checked": "Requests checked",
    "war.blocked": "Blocked",
    "war.held": "Held",
    "war.protected": "Protected",
    "war.recovered": "Recovered",
    "war.human": "Human needed",
    "war.detect_times": "Detection time per victim",
    "war.missed": "missed",
    "war.council": "Bank Council",
    "war.ruling": "Arbiter ruling",
    "war.rule": "Rule",
    "war.assurance": "Assurance",
    "war.locked": "LOCKED",
    "war.deadlock": "DEADLOCK",
    "war.no_request": "Waiting for a request…",
    "war.normal_security": "Normal security",
    "war.rakshaka": "Rakshaka",
    "war.password": "Password",
    "war.otp": "OTP",
    "war.device": "Known device",
    "war.place": "Known place",
    "war.signals": "Signals between banks",
    "war.timeline": "Timeline",
    "war.people_saw": "What people saw",
    "war.pressure": "Pressure meter",
    "war.nobody_yet": "Nothing was shown to people yet.",
    "war.deadlock_title": "Council deadlock - both sides",
    "war.side_stop": "Wants to stop it",
    "war.side_go": "Wants to let it go",
    "war.no_lockout": "We protect elders without locking them out of their own money.",
    "war.normal_vs": "Normal security vs Rakshaka",
    "war.rakshaka_sees": "Also reads the pressure, the routine and the mule ring.",
    "war.owner_coerced": "Password and OTP are right - the owner himself is being pushed by a scammer.",
    "war.no_signals": "No signals between banks yet.",
    "war.hop": "hop",
    "walk.MULE_RING": "Mule Ring walk",
    "walk.MONEY_TRACE": "Money Tracer follows the money",
    "signal.ACCOUNT_FLAGGED": "Account flagged",
    "signal.FREEZE_REQUEST": "Freeze request",
    "signal.SESSION_REVOKED": "Session revoked",
    "action.BILL_PAY": "Bill payment",
    "action.TRANSFER": "Transfer",
    "action.BREAK_FD": "FD break",
    "action.LOGIN": "Login",
    "status.DRAFT": "DRAFT",
    "status.CHECKING": "CHECKING",
    "status.ALLOWED": "ALLOWED",
    "status.STEP_UP": "STEP-UP",
    "status.HELD": "HELD",
    "status.BLOCKED": "BLOCKED",
    "agent.SYSTEM": "System",
    "agent.GUARDIAN": "Guardian",
    "agent.ANALYST": "Analyst",
    "tele.step": "{name}: step {n} of {total}",
    "war.system1": "System 1",
    "war.system2": "System 2",
    "war.rule_src": "Rule",
    "war.fallback_src": "Fallback",
    "layer.1": "Phone Shield",
    "layer.2": "Bank Council",
    "layer.3": "Fraud Network",
    "agent.COERCION": "Coercion Sentinel",
    "agent.PLACE_TIME": "Place & Time",
    "agent.ROUTINE": "Routine",
    "agent.MULE_RING": "Mule Ring",
    "agent.PATTERN": "Pattern",
    "agent.ADVOCATE": "Citizen Advocate",
    "agent.SCAM_BREAKER": "Scam-Breaker",
    "agent.ARBITER": "Guardian Arbiter",
    "agent.PATTERN_LEARNER": "Pattern Learner",
    "agent.MONEY_TRACER": "Money Tracer",
    "agent.LIAISON_LDB": "Liaison · Lanka Demo Bank",
    "agent.LIAISON_CDB": "Liaison · Ceylon Demo Bank",
    "agent.LIAISON_IDB": "Liaison · Island Demo Bank",
    "decision.ALLOW": "ALLOW",
    "decision.STEP_UP": "STEP-UP",
    "decision.HOLD": "HOLD",
    "decision.BLOCK": "BLOCK",
    "decision.ASK_GUARDIAN": "ASK GUARDIAN",
    "decision.ASK_ANALYST": "ASK ANALYST",
    "decision.FREEZE": "FREEZE",
    "decision.WATCH": "WATCH",
    "analyst.approve": "Approve freeze",
    "analyst.keep_open": "Keep open",
    "analyst.none": "No cases need an analyst.",
    "story.debrief": "What happened",
    "story.timeline": "Every agent action",
    "story.counters": "Final numbers",
    "state.normal": "Normal",
    "state.active": "Active",
    "state.suspect": "Suspect",
    "state.mule": "Mule",
    "state.blocked": "Blocked",
    "state.frozen": "Frozen",
    "state.safe": "Safe"
};

# Sinhala - to be checked by a native speaker. Missing keys use English for now.
glob SI: dict[str, str] = {
    "sim.banner": "අනුකරණය — කල්පිත දත්ත",
    "app.name": "රක්ෂක",
    "tele.voice_sample": "ඔබේ මුදල් ආරක්ෂිතයි. කවුරුහරි දුරකථනයෙන් කතා කරන අතරතුර මුදල් යවන්න එපා."
};

# Tamil - to be checked by a native speaker. Missing keys use English for now.
glob TA: dict[str, str] = {
    "sim.banner": "உருவகப்படுத்தல் — கற்பனைத் தரவு",
    "app.name": "ரக்ஷகா",
    "tele.voice_sample": "உங்கள் பணம் பாதுகாப்பாக உள்ளது. யாராவது தொலைபேசியில் பேசும்போது பணம் அனுப்ப வேண்டாம்."
};

glob _warned: dict[str, bool] = {};

"""Text for a UI key. Missing in that language -> English + one console warning."""
def:pub t(key: str, lang: str) -> str {
    table = SI if lang == "si" else (TA if lang == "ta" else EN);
    if key in table {
        return table[key];
    }
    if lang != "en" and not _warned[lang + ":" + key] {
        _warned[lang + ":" + key] = True;
        console.warn("[i18n] missing " + lang + " text for " + key);
    }
    if key in EN {
        return EN[key];
    }
    console.warn("[i18n] unknown key " + key);
    return key;
}

"""True if English text exists for this key (for names that come from the server, like timeline agents)."""
def:pub known_key(key: str) -> bool {
    return key in EN;
}

"""t() with {name} style values filled in."""
def:pub tf(key: str, lang: str, values: dict) -> str {
    text = t(key, lang);
    for name in Object.keys(values) {
        text = text.replace("{" + name + "}", String(values[name]));
    }
    return text;
}

"""Rs 4,200,000 - the same format in every language."""
def:pub money(amount: object) -> str {
    n: int = round((amount or 0) as float);
    sign = "-" if n < 0 else "";
    digits = str(abs(n));
    out = "";
    count = 0;
    i = len(digits) - 1;
    while i >= 0 {
        if count > 0 and count % 3 == 0 {
            out = "," + out;
        }
        out = digits[i] + out;
        count = count + 1;
        i = i - 1;
    }
    return "Rs " + sign + out;
}

glob MONTHS: list[str] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

"""'2026-10-17' -> '17 Oct'."""
def:pub day_month(date_text: str) -> str {
    parts = date_text.split("-");
    if len(parts) < 3 {
        return date_text;
    }
    return str(int(parts[2])) + " " + MONTHS[int(parts[1]) - 1];
}

"""Language switch: සිං | தமிழ் | EN."""
def:pub LanguageSwitch(lang: str, onChange: Callable[[str], None], dark: bool = False) -> JsxElement {
    return <div style={{"display": "inline-flex", "gap": "4px", "fontSize": "15px"}}>
        {for code in LANGS {
            <button
                key={code}
                onClick={lambda (e: MouseEvent) { onChange(code); }}
                style={{
                    "padding": "4px 10px",
                    "borderRadius": "999px",
                    "cursor": "pointer",
                    "border": "1px solid " + ("#475569" if dark else "#cbd5e1"),
                    "background": ("#38bdf8" if dark else "#0f766e") if code == lang else "transparent",
                    "color": ("#0f172a" if dark else "#ffffff") if code == lang else ("#e2e8f0" if dark else "#334155"),
                    "fontWeight": "700" if code == lang else "400"
                }}
            >{t("lang." + code, "en")}</button>
        }}
    </div>;
}
