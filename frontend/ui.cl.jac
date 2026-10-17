# Shared small UI pieces (C): theme, fonts, Header, Card, Bar, Badge.
import from .i18n { t, LanguageSwitch }

glob FONT_URL: str = "https://fonts.googleapis.com/css2?family=Inter:wght@400;600;800&family=Noto+Sans+Sinhala:wght@400;600;800&family=Noto+Sans+Tamil:wght@400;600;800&display=swap";
glob:pub FONT_STACK: str = "Inter, 'Noto Sans Sinhala', 'Noto Sans Tamil', system-ui, sans-serif";

# Colours for node / decision states (same on every screen).
glob COLORS: dict[str, str] = {
    "normal": "#94a3b8",
    "active": "#3b82f6",
    "suspect": "#f59e0b",
    "mule": "#ef4444",
    "blocked": "#dc2626",
    "frozen": "#67e8f9",
    "safe": "#22c55e",
    "ALLOW": "#22c55e",
    "STEP_UP": "#f59e0b",
    "HOLD": "#f59e0b",
    "ASK_GUARDIAN": "#f59e0b",
    "ASK_ANALYST": "#a78bfa",
    "WATCH": "#94a3b8",
    "BLOCK": "#ef4444",
    "FREEZE": "#67e8f9"
};

# Light theme (phone, guardian, story) and dark theme (War Room, control panel).
glob LIGHT: dict[str, str] = {"bg": "#f1f5f9", "card": "#ffffff", "text": "#0f172a", "muted": "#64748b", "line": "#e2e8f0", "accent": "#0f766e"};
glob DARK: dict[str, str] = {"bg": "#0b1120", "card": "#111a2e", "text": "#e2e8f0", "muted": "#94a3b8", "line": "#1e293b", "accent": "#38bdf8"};

"""Colour for a state or decision name (grey if unknown)."""
def:pub color_of(name: str) -> str {
    return COLORS[name] or "#94a3b8";
}

"""Theme dict for dark or light screens."""
def:pub theme(dark: bool) -> dict {
    return DARK if dark else LIGHT;
}

"""A JSON value from the API as a list of dicts (None -> [])."""
def:pub rows(value: object) -> list[dict[str, any]] {
    return (value or []) as list[dict[str, any]];
}

"""A JSON value from the API as a dict (None -> {})."""
def:pub obj(value: object) -> dict[str, any] {
    return (value or {}) as dict[str, any];
}

"""First report of a walker spawn as a dict ({} if none)."""
def:pub first_report(result: any) -> dict[str, any] {
    reports = rows(result.reports);
    return reports[0] if len(reports) > 0 else {};
}

"""Load Noto Sans Sinhala / Tamil + Inter once."""
def:pub load_fonts() {
    if document.getElementById("rk-fonts") {
        return;
    }
    link: any = document.createElement("link");
    link.id = "rk-fonts";
    link.rel = "stylesheet";
    link.href = FONT_URL;
    document.head.appendChild(link);  # jac:ignore[E1030]
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

"""Screen header: title + simulation label + language switch."""
def:pub Header(title: str, lang: str, onLang: Callable[[str], None], dark: bool = False, children: any = None) -> JsxElement {
    th = theme(dark);
    return <header style={{
        "display": "flex", "alignItems": "center", "justifyContent": "space-between",
        "flexWrap": "wrap", "gap": "8px", "padding": "10px 16px",
        "borderBottom": "1px solid " + th["line"], "background": th["card"], "color": th["text"]
    }}>
        <div style={{"display": "flex", "alignItems": "baseline", "gap": "12px", "flexWrap": "wrap"}}>
            <strong style={{"fontSize": "20px", "color": th["accent"]}}>{t("app.name", lang)}</strong>
            <span style={{"fontSize": "20px", "fontWeight": "600"}}>{title}</span>
            <span style={{
                "fontSize": "12px", "padding": "2px 8px", "borderRadius": "999px",
                "background": "#fef3c7", "color": "#92400e", "fontWeight": "600"
            }}>{t("sim.banner", lang)}</span>
        </div>
        <div style={{"display": "flex", "alignItems": "center", "gap": "12px"}}>
            {children}
            <LanguageSwitch lang={lang} onChange={onLang} dark={dark} />
        </div>
    </header>;
}

"""A rounded box with an optional title."""
def:pub Card(title: str = "", dark: bool = False, accent: str = "", children: any = None) -> JsxElement {
    th = theme(dark);
    return <section style={{
        "background": th["card"], "color": th["text"], "borderRadius": "14px",
        "padding": "14px 16px", "border": "1px solid " + th["line"],
        "borderLeft": ("5px solid " + accent) if accent else ("1px solid " + th["line"]),
        "transition": "all 0.4s ease"
    }}>
        {title and <h3 style={{"margin": "0 0 8px", "fontSize": "15px", "color": th["muted"], "textTransform": "uppercase", "letterSpacing": "0.05em"}}>{title}</h3>}
        {children}
    </section>;
}

"""Horizontal bar, value 0..1."""
def:pub Bar(value: float, color: str = "#3b82f6", height: int = 8, dark: bool = False) -> JsxElement {
    pct = Math.max(0, Math.min(1, value)) * 100;
    return <div style={{"background": theme(dark)["line"], "borderRadius": "999px", "height": str(height) + "px", "overflow": "hidden"}}>
        <div style={{"width": str(pct) + "%", "height": "100%", "background": color, "borderRadius": "999px", "transition": "width 0.6s ease"}} />
    </div>;
}

"""Small coloured label."""
def:pub Badge(text: str, color: str = "#64748b", solid: bool = False) -> JsxElement {
    return <span style={{
        "display": "inline-block", "padding": "2px 10px", "borderRadius": "999px",
        "fontSize": "13px", "fontWeight": "700", "letterSpacing": "0.03em",
        "border": "1px solid " + color,
        "background": color if solid else "transparent",
        "color": "#0b1120" if solid else color
    }}>{text}</span>;
}

"""Pressure 0-100 -> colour (green, amber, red)."""
def:pub pressure_color(value: int) -> str {
    if value >= 70 {
        return "#ef4444";
    }
    if value >= 40 {
        return "#f59e0b";
    }
    return "#22c55e";
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
