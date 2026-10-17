# War Room (C): English, dark, big text. Polls get_war_room() every 1 s. Full design comes in M3.
import from react { useEffect }
import from .i18n { t, money }
import from .ui { Header, Card, Bar, Badge, theme, color_of, rows, obj, first_report }
import from .graph_view { GraphView }
import from .analyst { AnalystPanel }

sv import from ..walkers.api { get_war_room }

# The War Room is always English (judges' screen); people_saw shows the other languages.
glob LANG: str = "en";

"""System 1 / System 2 / Rule label for a proposal source."""
def source_label(source: str, ms: int) -> str {
    secs = f"{(ms / 1000):.2f} s";
    if source == "jev" {
        return t("war.system1", LANG) + " · " + secs;
    }
    if source == "llm" {
        return t("war.system2", LANG) + " · " + secs;
    }
    if source == "code" {
        return t("war.rule_src", LANG);
    }
    return t("war.fallback_src", LANG);
}

"""One number in the top counter row."""
def:pub Counter(label: str, value: str, color: str = "#e2e8f0") -> JsxElement {
    return <div style={{"display": "flex", "flexDirection": "column", "minWidth": "120px"}}>
        <span style={{"fontSize": "30px", "fontWeight": "800", "color": color}}>{value}</span>
        <span style={{"fontSize": "13px", "color": "#94a3b8", "textTransform": "uppercase"}}>{label}</span>
    </div>;
}

"""One Bank Council agent card."""
def:pub AgentCard(p: dict[str, any]) -> JsxElement {
    stance = p["stance"] as str;
    c = color_of(stance);
    return <Card dark={True} accent={c}>
        <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center", "gap": "8px"}}>
            <strong style={{"fontSize": "18px"}}>{t("agent." + (p["agent"] as str), LANG)}</strong>
            <Badge text={t("decision." + stance, LANG)} color={c} />
        </div>
        <div style={{"margin": "8px 0"}}><Bar value={p["confidence"] as float} color={c} dark={True} /></div>
        <div style={{"fontSize": "15px", "color": "#cbd5e1"}}>{p["reason"]}</div>
        <div style={{"fontSize": "12px", "color": "#64748b", "marginTop": "6px"}}>{source_label(p["source"] as str, p["ms"] as int)}</div>
    </Card>;
}

"""The Arbiter's ruling card."""
def:pub RulingCard(r: dict[str, any]) -> JsxElement {
    decision = r["decision"] as str;
    c = color_of(decision);
    detail = t("war.rule", LANG) + " " + (r["rule"] as str) + " · " + t("war.assurance", LANG) + " " + (r["assurance"] as str)
             + " · " + str(r["ms"]) + " ms";
    return <Card dark={True} accent={c} title={t("war.ruling", LANG)}>
        <div style={{"display": "flex", "gap": "10px", "alignItems": "center", "flexWrap": "wrap"}}>
            <span style={{"fontSize": "36px", "fontWeight": "800", "color": c}}>{t("decision." + decision, LANG)}</span>
            {r["locked"] and <Badge text={t("war.locked", LANG)} color="#ef4444" solid={True} />}
            {r["deadlock"] and <Badge text={t("war.deadlock", LANG)} color="#a78bfa" solid={True} />}
        </div>
        <div style={{"fontSize": "16px", "margin": "6px 0"}}>{r["why"]}</div>
        <div style={{"fontSize": "13px", "color": "#94a3b8"}}>{detail}</div>
    </Card>;
}

def:pub WarRoom() -> JsxElement {
    has room: dict[str, any] = {},
        failed: bool = False;

    async def load() {
        try {
            data = first_report(root spawn get_war_room());
            if data {
                room = data;
                failed = False;
            }
        } except Exception {
            failed = True;
        }
    }

    useEffect(lambda {
        load();
        timer = setInterval(lambda { load(); }, 1000);
        return lambda { clearInterval(timer); };
    }, []);

    th = theme(True);
    page = {"background": th["bg"], "color": th["text"], "minHeight": "100vh"};
    header = <Header title={t("screen.war_room", LANG)} lang={LANG} onLang={lambda (code: str) { }} dark={True} />;
    if not room["counters"] {
        return <div style={page}>
            {header}
            <p style={{"padding": "24px"}}>{t("common.error", LANG) if failed else t("common.loading", LANG)}</p>
        </div>;
    }
    counters = obj(room["counters"]);
    return <div style={page}>
        {header}
        <div style={{"display": "flex", "gap": "28px", "flexWrap": "wrap", "padding": "14px 20px", "borderBottom": "1px solid " + th["line"]}}>
            <Counter label={t("war.checked", LANG)} value={str(counters["checked"])} />
            <Counter label={t("war.blocked", LANG)} value={str(counters["blocked"])} color="#ef4444" />
            <Counter label={t("war.held", LANG)} value={str(counters["held"])} color="#f59e0b" />
            <Counter label={t("war.protected", LANG)} value={money(counters["protected_rs"])} color="#22c55e" />
            <Counter label={t("war.recovered", LANG)} value={money(counters["recovered_rs"])} color="#67e8f9" />
            <Counter label={t("war.human", LANG)} value={str(counters["human_needed"])} />
        </div>
        <div style={{"display": "grid", "gridTemplateColumns": "minmax(0, 5fr) minmax(0, 4fr) minmax(0, 3fr)", "gap": "16px", "padding": "16px 20px"}}>
            <GraphView graph={obj(room["graph"])} walk={obj(room["walk"])} />
            <div style={{"display": "flex", "flexDirection": "column", "gap": "10px"}}>
                {room["ruling"] and <RulingCard r={obj(room["ruling"])} />}
                {for p in rows(room["proposals"]) {
                    <AgentCard key={p["agent"]} p={p} />
                }}
            </div>
            <AnalystPanel alerts={rows(room["alerts"])} />
        </div>
    </div>;
}
