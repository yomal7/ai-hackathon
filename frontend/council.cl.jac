# War Room council column (C): request card with pressure, one card per agent, the Arbiter's ruling, deadlock view.
import from .i18n { t, money }
import from .ui { Card, Bar, Badge, color_of, pressure_color, rows }

glob LANG: str = "en";
glob RISKY: list[str] = ["STEP_UP", "HOLD", "BLOCK", "ASK_GUARDIAN", "FREEZE"];
glob LAYER_OF: dict[str, str] = {
    "COERCION": "1", "PLACE_TIME": "2", "ROUTINE": "2", "MULE_RING": "2", "PATTERN": "2", "ADVOCATE": "2",
    "SCAM_BREAKER": "2", "PATTERN_LEARNER": "3", "MONEY_TRACER": "3", "LIAISON_LDB": "3", "LIAISON_CDB": "3",
    "LIAISON_IDB": "3"
};
glob TEXT_FONT: str = "'Noto Sans Sinhala', 'Noto Sans Tamil', Inter, sans-serif";

"""System 1 (Jev) / System 2 (LLM) / Rule (code) + time, for an agent card."""
def:pub source_label(source: str, ms: int) -> str {
    secs = f"{(ms / 1000):.2f} s";
    if source == "jev" {
        return t("war.system1", LANG) + " · " + secs;
    }
    if source == "llm" {
        return t("war.system2", LANG) + " · " + secs;
    }
    if source == "code" {
        return t("war.rule_src", LANG) + " · " + str(ms) + " ms";
    }
    return t("war.fallback_src", LANG) + " · " + str(ms) + " ms";
}

"""What people saw, in their own language (hover on the language badge)."""
def:pub PeopleSaw(items: list[dict[str, any]]) -> JsxElement {
    return <div style={{
        "position": "absolute", "top": "100%", "right": "0", "zIndex": "20", "width": "380px", "marginTop": "6px",
        "background": "#0b1120", "border": "1px solid #38bdf8", "borderRadius": "12px", "padding": "12px",
        "boxShadow": "0 12px 30px rgba(0,0,0,0.5)"
    }}>
        <div style={{"fontSize": "12px", "color": "#94a3b8", "textTransform": "uppercase", "marginBottom": "6px"}}>{t("war.people_saw", LANG)}</div>
        {if len(items) == 0 {
            <div style={{"color": "#94a3b8"}}>{t("war.nobody_yet", LANG)}</div>
        }}
        {for (i, p) in enumerate(items) {
            <div key={str(i)} style={{"padding": "6px 0", "borderTop": "1px solid #1e293b" if i > 0 else "none"}}>
                <div style={{"fontSize": "13px", "color": "#38bdf8"}}>{(p["who"] as str) + " · " + t("lang." + (p["language"] as str), LANG)}</div>
                <div style={{"fontSize": "17px", "fontFamily": TEXT_FONT}}>{p["text"]}</div>
            </div>
        }}
    </div>;
}

"""The request being checked: who, what, how much, the live pressure meter, and the language badge."""
def:pub RequestCard(req: dict[str, any], pressure: dict[str, any], people: list[dict[str, any]]) -> JsxElement {
    has hover: bool = False;

    value = (pressure["value"] or 0) as int;
    c = pressure_color(value);
    status = req["status"] as str;
    return <Card dark={True} accent="#38bdf8">
        <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "flex-start", "gap": "8px"}}>
            <div>
                <div style={{"fontSize": "13px", "color": "#94a3b8"}}>{(req["id"] as str) + " · " + t("action." + (req["action"] as str), LANG)}</div>
                <div style={{"fontSize": "22px", "fontWeight": "800"}}>{req["citizen"]}</div>
                <div style={{"fontSize": "20px"}}>{money(req["amount"]) + " → " + (req["payee"] as str)}</div>
            </div>
            <div style={{"display": "flex", "flexDirection": "column", "alignItems": "flex-end", "gap": "6px"}}>
                <div style={{"position": "relative"}} onMouseEnter={lambda (e: MouseEvent) { hover = True; }}
                    onMouseLeave={lambda (e: MouseEvent) { hover = False; }}>
                    <span style={{"cursor": "help", "padding": "3px 12px", "borderRadius": "999px", "background": "#1e3a5f",
                                  "border": "1px solid #38bdf8", "fontSize": "16px"}}>{t("lang." + (req["language"] as str), LANG)}</span>
                    {hover and <PeopleSaw items={people} />}
                </div>
                <Badge text={t("status." + status, LANG)} color={color_of(status)} />
            </div>
        </div>
        <div style={{"marginTop": "12px", "display": "flex", "justifyContent": "space-between", "fontSize": "14px", "color": "#94a3b8"}}>
            <span>{t("war.pressure", LANG)}</span>
            <strong style={{"fontSize": "22px", "color": c}}>{str(value)}</strong>
        </div>
        <Bar value={value / 100} color={c} height={12} dark={True} />
        <div style={{"display": "flex", "flexWrap": "wrap", "gap": "6px", "marginTop": "8px"}}>
            {for (i, reason) in enumerate((pressure["reasons"] or []) as list[str]) {
                <span key={str(i)} style={{"fontSize": "13px", "padding": "2px 8px", "borderRadius": "6px", "background": "#1e293b",
                                           "fontFamily": TEXT_FONT}}>{reason}</span>
            }}
        </div>
    </Card>;
}

"""One agent card: name, layer, stance, confidence bar, reason, System 1 / System 2 / Rule."""
def:pub AgentCard(p: dict[str, any], fresh: bool = False) -> JsxElement {
    stance = p["stance"] as str;
    agent = p["agent"] as str;
    c = color_of(stance);
    return <div style={{"animation": "rkIn 0.45s ease-out" if fresh else "none"}}>
        <Card dark={True} accent={c}>
            <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center", "gap": "8px"}}>
                <div>
                    <strong style={{"fontSize": "18px"}}>{t("agent." + agent, LANG)}</strong>
                    <span style={{"fontSize": "12px", "color": "#64748b", "marginLeft": "8px"}}>{t("layer." + (LAYER_OF[agent] or "2"), LANG)}</span>
                </div>
                <Badge text={t("decision." + stance, LANG)} color={c} />
            </div>
            <div style={{"display": "flex", "alignItems": "center", "gap": "8px", "margin": "8px 0"}}>
                <div style={{"flex": "1"}}><Bar value={p["confidence"] as float} color={c} dark={True} /></div>
                <span style={{"fontSize": "13px", "color": "#94a3b8", "minWidth": "36px"}}>{str(round((p["confidence"] as float) * 100)) + "%"}</span>
            </div>
            <div style={{"fontSize": "15px", "color": "#cbd5e1", "fontFamily": TEXT_FONT}}>{p["reason"]}</div>
            <div style={{"fontSize": "12px", "color": "#64748b", "marginTop": "6px"}}>{source_label(p["source"] as str, p["ms"] as int)}</div>
        </Card>
    </div>;
}

"""The Arbiter's ruling: decision, rule, assurance, ms, LOCKED / DEADLOCK."""
def:pub RulingCard(r: dict[str, any]) -> JsxElement {
    decision = r["decision"] as str;
    c = color_of(decision);
    detail = t("war.rule", LANG) + " " + (r["rule"] as str) + " · " + t("war.assurance", LANG) + " " + (r["assurance"] as str)
             + " · " + str(r["ms"]) + " ms";
    return <div style={{"animation": "rkIn 0.5s ease-out"}}>
        <Card dark={True} accent={c} title={t("agent.ARBITER", LANG)}>
            <div style={{"display": "flex", "gap": "10px", "alignItems": "center", "flexWrap": "wrap"}}>
                <span style={{"fontSize": "40px", "fontWeight": "800", "color": c, "letterSpacing": "0.02em"}}>{t("decision." + decision, LANG)}</span>
                {r["locked"] and <Badge text={"🔒 " + t("war.locked", LANG)} color="#ef4444" solid={True} />}
                {r["deadlock"] and <Badge text={t("war.deadlock", LANG)} color="#a78bfa" solid={True} />}
            </div>
            <div style={{"fontSize": "16px", "margin": "6px 0", "fontFamily": TEXT_FONT}}>{r["why"]}</div>
            <div style={{"fontSize": "13px", "color": "#94a3b8"}}>{detail}</div>
        </Card>
    </div>;
}

"""Strongest proposal on one side: risky (wants to stop) or ALLOW (wants to let it go)."""
def strongest(proposals: list[dict[str, any]], risky: bool) -> dict[str, any] {
    best: dict[str, any] = {};
    for p in proposals {
        is_risky = (p["stance"] as str) in RISKY;
        if is_risky == risky and (not best or (p["confidence"] as float) > (best["confidence"] as float)) {
            best = p;
        }
    }
    return best;
}

"""The Citizen Advocate's proposal ({} if none): it is the voice that argues against a lockout."""
def advocate_of(proposals: list[dict[str, any]]) -> dict[str, any] {
    for p in proposals {
        if p["agent"] == "ADVOCATE" and (p["stance"] as str) not in RISKY {
            return p;
        }
    }
    return {};
}

"""DEADLOCK: both sides side by side (the Advocate speaks for 'let it go' when it took that side)."""
def:pub DeadlockCard(proposals: list[dict[str, any]]) -> JsxElement {
    stop = strongest(proposals, True);
    go = advocate_of(proposals) or strongest(proposals, False);
    return <Card dark={True} accent="#a78bfa" title={t("war.deadlock_title", LANG)}>
        <div style={{"display": "grid", "gridTemplateColumns": "1fr 1fr", "gap": "10px"}}>
            {for (side, p, c) in [("war.side_stop", stop, "#f59e0b"), ("war.side_go", go, "#22c55e")] {
                <div key={side} style={{"border": "1px solid " + c, "borderRadius": "10px", "padding": "10px"}}>
                    <div style={{"fontSize": "12px", "color": c, "textTransform": "uppercase"}}>{t(side, LANG)}</div>
                    {if p {
                        <strong style={{"fontSize": "16px"}}>{t("agent." + (p["agent"] as str), LANG)}</strong>
                        <div style={{"fontSize": "14px", "color": "#cbd5e1", "fontFamily": TEXT_FONT}}>{p["reason"]}</div>
                    }}
                </div>
            }}
        </div>
        <p style={{"margin": "10px 0 0", "fontSize": "15px", "color": "#c4b5fd"}}>{t("war.no_lockout", LANG)}</p>
    </Card>;
}

"""The council column: request, ruling, deadlock, then agent cards revealed one by one (shown = how many)."""
def:pub CouncilColumn(room: dict[str, any], shown: int) -> JsxElement {
    proposals = rows(room["proposals"]);
    visible = proposals[:shown];
    ruling = room["ruling"];
    show_ruling = ruling and shown > len(proposals);
    return <div style={{"display": "flex", "flexDirection": "column", "gap": "10px"}}>
        {if room["request"] {
            <RequestCard req={room["request"] as dict[str, any]} pressure={room["pressure"] as dict[str, any]}
                people={rows(room["people_saw"])} />
        } else {
            <Card dark={True}><span style={{"fontSize": "18px", "color": "#94a3b8"}}>{t("war.no_request", LANG)}</span></Card>
        }}
        {show_ruling and <RulingCard r={ruling as dict[str, any]} />}
        {show_ruling and (ruling as dict[str, any])["deadlock"] and <DeadlockCard proposals={proposals} />}
        <div style={{"fontSize": "13px", "color": "#94a3b8", "textTransform": "uppercase", "letterSpacing": "0.05em", "marginTop": "4px"}}>
            {t("war.council", LANG) + " · " + str(len(visible)) + "/" + str(len(proposals))}
        </div>
        {for (i, p) in enumerate(visible) {
            <AgentCard key={p["agent"]} p={p} fresh={i == shown - 1} />
        }}
    </div>;
}
