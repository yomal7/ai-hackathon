# Rakshaka design tokens (C). One system, two skins:
#   PAPER - soft neo-brutalism for people (phone, guardian, story): warm paper, ink borders, hard shadows, big type.
#   INK   - minimal dark control room for operators (War Room, control panel): thin lines, mono labels, signal colours.
# Body font Lexend was designed for reading ease (good for elders) and has a plain zero (money must read clearly).

glob:pub FONT_URL: str = "https://fonts.googleapis.com/css2?family=Lexend:wght@400;500;700&family=Bricolage+Grotesque:opsz,wght@12..96,600;12..96,800&family=IBM+Plex+Mono:wght@400;600&family=Noto+Sans+Sinhala:wght@400;700&family=Noto+Sans+Tamil:wght@400;700&display=swap";
glob:pub FONT_STACK: str = "Lexend, 'Noto Sans Sinhala', 'Noto Sans Tamil', system-ui, sans-serif";
glob:pub DISPLAY: str = "'Bricolage Grotesque', 'Noto Sans Sinhala', 'Noto Sans Tamil', system-ui, sans-serif";
glob:pub MONO: str = "'IBM Plex Mono', ui-monospace, Menlo, monospace";

# Surfaces and text. Keys bg / card / text / muted / line / accent are used by every screen.
glob:pub PAPER: dict[str, str] = {
    "bg": "#F2EDE3", "card": "#FFFCF5", "sunk": "#E9E2D3", "text": "#16140F", "muted": "#5C574C",
    "line": "#16140F", "soft": "#D9D1C0", "accent": "#16140F", "shadow": "4px 4px 0 #16140F", "radius": "12px"
};
glob:pub INK: dict[str, str] = {
    "bg": "#0F0F0D", "card": "#181816", "sunk": "#121210", "text": "#EDEAE2", "muted": "#9C978C",
    "line": "#2C2B27", "soft": "#3A3934", "accent": "#FFE14A", "shadow": "none", "radius": "8px"
};

# Signal colours. Text-safe on the dark skin; on paper they are used as FILLS with ink text.
glob:pub SIGNAL: dict[str, str] = {
    "safe": "#5BD48A", "warn": "#F2B544", "danger": "#FF6A5C", "info": "#7AA2FF",
    "frozen": "#5FD0DC", "violet": "#B19CFF", "normal": "#77736A", "mark": "#FFE14A"
};
glob:pub FILL: dict[str, str] = {
    "safe": "#7BD88F", "warn": "#FFC94A", "danger": "#FF7A6B", "info": "#9DB9FF",
    "frozen": "#8FE3EC", "violet": "#C7B8FF", "normal": "#D9D1C0", "mark": "#FFE14A"
};

# One small global stylesheet: focus rings, press effect, animations, reduced motion. (Kept tiny on purpose.)
glob:pub BASE_CSS: str = "*{box-sizing:border-box}body{margin:0}"
    + " .rk-btn{transition:transform .12s ease,box-shadow .12s ease,background .2s ease}"
    + " .rk-btn:not(:disabled):hover{transform:translate(-1px,-1px)}"
    + " .rk-btn:not(:disabled):active{transform:translate(3px,3px);box-shadow:0 0 0 #16140F!important}"
    + " .rk-btn:disabled{cursor:not-allowed}"
    + " .rk-ink .rk-btn:not(:disabled):hover{transform:none;filter:brightness(1.15)}"
    + " .rk-ink .rk-btn:not(:disabled):active{transform:translateY(1px)}"
    + " :focus-visible{outline:3px solid #2F5BFF;outline-offset:2px}"
    + " .rk-ink :focus-visible{outline-color:#FFE14A}"
    + " input,button,textarea{font:inherit}"
    + " @keyframes rkIn{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:none}}"
    + " @keyframes rkDash{to{stroke-dashoffset:-32}}"
    + " @keyframes rkPulse{0%,100%{opacity:1}50%{opacity:.35}}"
    + " @keyframes rkStamp{0%{transform:scale(1.35) rotate(-5deg);opacity:0}60%{transform:scale(.97) rotate(-2deg);opacity:1}100%{transform:scale(1) rotate(-2deg)}}"
    + " @keyframes rkSpin{to{transform:rotate(360deg)}}"
    + " @keyframes rkShine{from{background-position:-200px 0}to{background-position:200px 0}}"
    + " @media (prefers-reduced-motion:reduce){*{animation:none!important;transition:none!important}}";

"""Surface tokens for a skin."""
def:pub skin(dark: bool) -> dict[str, str] {
    return INK if dark else PAPER;
}

"""Signal key for a state, decision or status name (normal if unknown)."""
def:pub signal_key(name: str) -> str {
    table = {
        "normal": "normal", "active": "info", "suspect": "warn", "mule": "danger", "blocked": "danger",
        "frozen": "frozen", "safe": "safe", "ALLOW": "safe", "ALLOWED": "safe", "DONE": "safe", "STEP_UP": "warn",
        "HOLD": "warn", "HELD": "warn", "ASK_GUARDIAN": "warn", "ASK_ANALYST": "violet", "WATCH": "normal",
        "BLOCK": "danger", "BLOCKED": "danger", "FREEZE": "frozen", "DRAFT": "normal", "CHECKING": "info",
        "OPEN": "normal", "AGREED": "info", "OBJECTED": "violet"
    };
    return table[name] or "normal";
}
