# Shared UI pieces (C): Header, Card, Button, Bar, Badge, Label, Icon, Spinner + small helpers.
# Two skins of one design system (see theme.cl.jac): dark=False -> PAPER (people), dark=True -> INK (operators).
import from .i18n { t, LanguageSwitch }
import from .theme { FONT_URL, FONT_STACK, DISPLAY, MONO, BASE_CSS, PAPER, INK, SIGNAL, FILL, skin, signal_key }

# Hand-drawn 24x24 line icons (no emoji, no icon font).
glob ICONS: dict[str, str] = {
    "check": "M4 12.5l5 5L20 6.5",
    "x": "M6 6l12 12M18 6L6 18",
    "lock": "M6 11h12v9H6z M8.5 11V8a3.5 3.5 0 0 1 7 0v3",
    "speaker": "M4 9.5h4l5-4v13l-5-4H4z M16.5 9a4 4 0 0 1 0 6 M19 6.5a7.5 7.5 0 0 1 0 11",
    "snow": "M12 3v18 M4.2 7.5l15.6 9 M19.8 7.5l-15.6 9",
    "shield": "M12 3l7.5 3v5.5c0 4.6-3.2 8.3-7.5 9.5-4.3-1.2-7.5-4.9-7.5-9.5V6z",
    "alert": "M12 4l9 16H3z M12 10v4.5 M12 17.2v.3",
    "arrow": "M5 12h14 M13 6l6 6-6 6",
    "play": "M8 5.5v13l10.5-6.5z",
    "reset": "M4.5 12a7.5 7.5 0 1 0 2.2-5.3 M4.5 4.5v4h4",
    "home": "M4 11l8-6.5 8 6.5 M6.5 9.5V20h11V9.5",
    "send": "M4 12l16-8-6 16-2.5-6.5z",
    "user": "M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8z M4.5 20.5c1.2-4 4.1-6 7.5-6s6.3 2 7.5 6",
    "phone": "M6.5 3.5h3l1.5 4.5-2 1.5a11 11 0 0 0 5.5 5.5l1.5-2 4.5 1.5v3a2 2 0 0 1-2 2C10.6 19.5 4.5 13.4 4.5 5.5a2 2 0 0 1 2-2z",
    "clock": "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18z M12 7.5V12l3 2",
    "bank": "M3.5 9.5L12 4l8.5 5.5 M5.5 10v7 M10 10v7 M14 10v7 M18.5 10v7 M3.5 20h17"
};

"""Colour of a state / decision / status for the dark skin (text-safe)."""
def:pub color_of(name: str) -> str {
    return SIGNAL[signal_key(name)];
}

"""Fill colour of a state / decision for the paper skin (used behind ink text)."""
def:pub fill_of(name: str) -> str {
    return FILL[signal_key(name)];
}

"""Theme dict for dark (INK) or light (PAPER) screens."""
def:pub theme(dark: bool) -> dict {
    return skin(dark);
}

"""A JSON value from the API as a list of dicts (None -> [])."""
def:pub rows(value: object) -> list[dict[str, any]] {
    return (value or []) as list[dict[str, any]];
}

"""A JSON value from the API as a dict (None -> {})."""
def:pub obj(value: object) -> dict[str, any] {
    return (value or {}) as dict[str, any];
}

"""The API walker's own report ({} if none). It is the LAST one: reports of walkers it spawned come first."""
def:pub last_report(result: any) -> dict[str, any] {
    reports = rows(result.reports);
    return reports[len(reports) - 1] if len(reports) > 0 else {};
}

# Screens poll every second, but a big read can take longer. One request per screen at a time,
# so slow answers never pile up on the server.
glob INFLIGHT: dict[str, bool] = {};

"""Start a poll for `key`; False if the last one has not answered yet (skip this tick)."""
def:pub poll_begin(key: str) -> bool {
    if INFLIGHT[key] {
        return False;
    }
    INFLIGHT[key] = True;
    return True;
}

"""The poll for `key` has answered (or failed)."""
def:pub poll_end(key: str) {
    INFLIGHT[key] = False;
}

"""Wait ms milliseconds: `await pause(1200);` inside an async def."""
def:pub pause(ms: int) -> any {
    return new(Promise, lambda (resolve: any) { setTimeout(resolve, ms); });  # jac:ignore[E1053]
}

"""True if text is one or more digits 0-9 (str.isdigit() does not exist in the browser runtime)."""
def:pub only_digits(text: str) -> bool {
    if not text {
        return False;
    }
    for ch in text {
        if ch not in "0123456789" {
            return False;
        }
    }
    return True;
}

"""Load the fonts and the one small global stylesheet once."""
def:pub load_fonts() {
    if document.getElementById("rk-fonts") {
        return;
    }
    link: any = document.createElement("link");
    link.id = "rk-fonts";
    link.rel = "stylesheet";
    link.href = FONT_URL;
    document.head.appendChild(link);  # jac:ignore[E1030]
    css: any = document.createElement("style");
    css.id = "rk-base";
    css.textContent = BASE_CSS;
    document.head.appendChild(css);  # jac:ignore[E1030]
    icon: any = document.createElement("link");
    icon.rel = "icon";
    icon.href = "data:image/svg+xml," + encodeURIComponent("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'><rect width='24' height='24' rx='5' fill='#16140F'/><path d='M12 4.5l6 2.4v4.4c0 3.7-2.6 6.6-6 7.6-3.4-1-6-3.9-6-7.6V6.9z' fill='#FFE14A'/></svg>");  # jac:ignore[E1030]
    document.head.appendChild(icon);  # jac:ignore[E1030]
}

"""The client caches read-only walkers for 60 s. Our screens poll live data, so turn that cache off."""
def:pub no_read_cache() {
    globalThis.__jacCacheState__ = {  # jac:ignore[E1032]
        "cache": {}, "order": [], "pending": {},
        "config": {"maxEntries": 500, "defaultTtlMs": 0}
    };
}

"""True once no_read_cache() has run."""
def:pub read_cache_off() -> bool {
    return bool(globalThis.__jacCacheState__);  # jac:ignore[E1032]
}

"""A query-string value from the current URL ('' if missing)."""
def:pub query_param(search: str, name: str) -> str {
    params: any = new(URLSearchParams, search);  # jac:ignore[E1053]
    return (params.get(name) or "") as str;
}

# ---------------- components ----------------

"""A line icon. name: one of ICONS."""
def:pub Icon(name: str, size: int = 20, color: str = "currentColor", stroke: float = 2.2) -> JsxElement {
    return <svg viewBox="0 0 24 24" width={size} height={size} fill="none" stroke={color} strokeWidth={stroke}
        strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" style={{"flexShrink": "0", "display": "block"}}>
        <path d={ICONS[name] or ""} />
    </svg>;
}

"""A small turning ring while something is busy."""
def:pub Spinner(size: int = 16, color: str = "currentColor") -> JsxElement {
    return <span aria-hidden="true" style={{
        "width": str(size) + "px", "height": str(size) + "px", "borderRadius": "50%", "display": "inline-block", "flexShrink": "0",
        "border": "2.5px solid " + color, "borderRightColor": "transparent", "animation": "rkSpin 0.8s linear infinite"
    }} />;
}

"""Small label above a block (mono, upper case)."""
def:pub Label(text: str, dark: bool = False, color: str = "") -> JsxElement {
    th = skin(dark);
    return <div style={{"fontFamily": MONO, "fontSize": "11.5px" if dark else "12.5px", "fontWeight": "600", "letterSpacing": "0.09em",
                        "textTransform": "uppercase", "color": color or th["muted"], "marginBottom": "8px"}}>{text}</div>;
}

"""Button for both skins. kind: plain | primary | safe | warn | danger | ghost. size: sm | md | lg.
busy=True shows a spinner and blocks double clicks."""
def:pub Button(label: str = "", onClick: any = None, kind: str = "plain", dark: bool = False, disabled: bool = False,
               busy: bool = False, full: bool = False, size: str = "md", icon: str = "", active: bool = False,
               title: str = "", children: any = None) -> JsxElement {
    off = disabled or busy;
    pad = {"sm": "6px 12px", "md": "11px 16px", "lg": "16px 20px"}[size];
    font = {"sm": "15px", "md": "17px", "lg": "23px"}[size];
    tall = {"sm": "36px", "md": "48px", "lg": "64px"}[size];
    look: dict[str, any] = {};
    if dark {
        bg = {"primary": INK["accent"], "safe": SIGNAL["safe"], "danger": "transparent", "warn": SIGNAL["warn"],
              "ghost": "transparent", "plain": "#22211E"}[kind];
        fg = {"primary": "#16140F", "safe": "#16140F", "danger": SIGNAL["danger"], "warn": "#16140F",
              "ghost": INK["muted"], "plain": INK["text"]}[kind];
        rim = SIGNAL["danger"] if kind == "danger" else (INK["accent"] if active else ("transparent" if kind in ["primary", "safe", "warn"] else INK["soft"]));
        look = {"background": "#2A2925" if active and kind == "plain" else bg, "color": fg, "border": "1px solid " + rim,
                "borderRadius": "6px", "fontFamily": FONT_STACK, "fontWeight": "700"};
    } else {
        bg = {"primary": PAPER["text"], "safe": FILL["safe"], "danger": FILL["danger"], "warn": FILL["warn"],
              "ghost": "transparent", "plain": PAPER["card"]}[kind];
        fg = PAPER["card"] if kind == "primary" else PAPER["text"];
        look = {"background": FILL["mark"] if active else bg, "color": fg,
                "border": "2px solid " + ("transparent" if kind == "ghost" else PAPER["line"]),
                "borderRadius": "10px", "boxShadow": "none" if (off or kind == "ghost") else "3px 3px 0 " + PAPER["line"],
                "fontFamily": DISPLAY, "fontWeight": "700"};
    }
    return <button className="rk-btn" type="button" disabled={off} title={title} aria-busy={busy}
        onClick={lambda (e: MouseEvent) { if onClick and not off { onClick(); } }}
        style={{**look, "display": "inline-flex", "alignItems": "center", "justifyContent": "center", "gap": "10px",
                "padding": pad, "fontSize": font, "minHeight": tall, "width": "100%" if full else "auto",
                "cursor": "pointer", "opacity": 0.45 if disabled else 1, "lineHeight": "1.25", "textAlign": "center"}}>
        {busy and <Spinner size={16 if size != "lg" else 20} />}
        {not busy and icon and <Icon name={icon} size={18 if size != "lg" else 24} />}
        {label and <span>{label}</span>}
        {children}
    </button>;
}

"""Screen header: brand, title, simulation label, extra items, language switch.
Paper: ink rule under a warm bar. Ink: sticky frosted bar (the one glass surface)."""
def:pub Header(title: str, lang: str, onLang: Callable[[str], None], dark: bool = False, children: any = None) -> JsxElement {
    th = skin(dark);
    bar: dict[str, any] = {};
    sim: dict[str, any] = {};
    if dark {
        bar = {"position": "sticky", "top": "0", "zIndex": "30", "background": "rgba(15,15,13,0.78)",
               "backdropFilter": "blur(14px)", "WebkitBackdropFilter": "blur(14px)", "borderBottom": "1px solid " + th["line"],
               "padding": "10px 20px"};
        sim = {"fontFamily": MONO, "fontSize": "11px", "letterSpacing": "0.08em", "textTransform": "uppercase",
               "color": SIGNAL["warn"], "border": "1px solid " + SIGNAL["warn"], "borderRadius": "4px", "padding": "2px 8px"};
    } else {
        bar = {"background": th["bg"], "borderBottom": "2px solid " + th["line"], "padding": "12px 16px"};
        sim = {"fontSize": "13px", "fontWeight": "700", "background": FILL["mark"], "border": "2px solid " + th["line"],
               "borderRadius": "6px", "padding": "1px 8px", "transform": "rotate(-1.5deg)", "display": "inline-block"};
    }
    return <header style={{**bar, "display": "flex", "alignItems": "center", "justifyContent": "space-between",
                           "flexWrap": "wrap", "gap": "10px", "color": th["text"]}}>
        <div style={{"display": "flex", "alignItems": "center", "gap": "10px", "flexWrap": "wrap"}}>
            <span style={{"width": "32px", "height": "32px", "borderRadius": "7px", "display": "inline-flex", "alignItems": "center",
                          "justifyContent": "center", "background": INK["accent"] if dark else PAPER["text"]}}>
                <Icon name="shield" size={19} color={"#16140F" if dark else FILL["mark"]} stroke={2.4} />
            </span>
            <strong style={{"fontFamily": DISPLAY, "fontSize": "21px", "fontWeight": "800", "letterSpacing": "-0.01em"}}>{t("app.name", lang)}</strong>
            <span style={{"color": th["muted"], "fontSize": "20px"}}>{"/"}</span>
            <span style={{"fontFamily": DISPLAY, "fontSize": "19px", "fontWeight": "600"}}>{title}</span>
            <span style={sim}>{t("sim.banner", lang)}</span>
        </div>
        <div style={{"display": "flex", "alignItems": "center", "gap": "14px", "flexWrap": "wrap"}}>
            {children}
            <LanguageSwitch lang={lang} onChange={onLang} dark={dark} />
        </div>
    </header>;
}

"""A block with an optional title. accent: a colour strip on top (paper: thick, ink: thin)."""
def:pub Card(title: str = "", dark: bool = False, accent: str = "", children: any = None) -> JsxElement {
    th = skin(dark);
    look: dict[str, any] = {};
    if dark {
        look = {"background": th["card"], "border": "1px solid " + th["line"], "borderRadius": th["radius"],
                "borderTop": ("2px solid " + accent) if accent else ("1px solid " + th["line"]), "padding": "14px 16px"};
    } else {
        look = {"background": th["card"], "border": "2px solid " + th["line"], "borderRadius": th["radius"],
                "boxShadow": th["shadow"], "padding": "16px 18px",
                "borderTop": ("10px solid " + accent) if accent else ("2px solid " + th["line"])};
    }
    return <section style={{**look, "color": th["text"], "transition": "border-color 0.4s ease"}}>
        {title and <Label text={title} dark={dark} />}
        {children}
    </section>;
}

"""Horizontal bar, value 0..1."""
def:pub Bar(value: float, color: str = "#7AA2FF", height: int = 8, dark: bool = False) -> JsxElement {
    pct = Math.max(0, Math.min(1, value)) * 100;
    track: dict[str, any] = {"background": "#26251F", "borderRadius": "2px"} if dark
            else {"background": PAPER["sunk"], "border": "2px solid " + PAPER["line"], "borderRadius": "6px"};
    return <div style={{**track, "height": str(height) + "px", "overflow": "hidden"}}>
        <div style={{"width": str(pct) + "%", "height": "100%", "background": color, "transition": "width 0.5s ease"}} />
    </div>;
}

"""Small label chip. Paper: ink border + fill. Ink: thin coloured outline, mono."""
def:pub Badge(text: str, color: str = "#77736A", solid: bool = False, dark: bool = True) -> JsxElement {
    look: dict[str, any] = {};
    if dark {
        look = {"fontFamily": MONO, "fontSize": "11.5px", "letterSpacing": "0.06em", "textTransform": "uppercase",
                "border": "1px solid " + color, "borderRadius": "4px", "padding": "2px 8px",
                "background": color if solid else "transparent", "color": "#16140F" if solid else color};
    } else {
        look = {"fontSize": "14px", "border": "2px solid " + PAPER["line"], "borderRadius": "6px", "padding": "1px 8px",
                "background": color if solid else PAPER["card"], "color": PAPER["text"]};
    }
    return <span style={{**look, "display": "inline-flex", "alignItems": "center", "gap": "4px", "fontWeight": "700",
                         "whiteSpace": "nowrap"}}>{text}</span>;
}

"""Pressure 0-100 -> colour on the dark skin (green, amber, red)."""
def:pub pressure_color(value: int) -> str {
    if value >= 70 {
        return SIGNAL["danger"];
    }
    if value >= 40 {
        return SIGNAL["warn"];
    }
    return SIGNAL["safe"];
}

"""Pressure 0-100 -> fill colour on the paper skin."""
def:pub pressure_fill(value: int) -> str {
    if value >= 70 {
        return FILL["danger"];
    }
    if value >= 40 {
        return FILL["warn"];
    }
    return FILL["safe"];
}

"""Pressure 0-100 -> i18n key."""
def:pub pressure_key(value: int) -> str {
    if value >= 70 {
        return "pressure.high";
    }
    if value >= 40 {
        return "pressure.rising";
    }
    return "pressure.calm";
}
