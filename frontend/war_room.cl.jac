# War Room (C): THE star screen. English, dark, big text for a projector. Polls get_war_room() every 1 s.
# Cards appear one by one; the Mule Ring / Money Tracer walk moves hop by hop on the graph.
import from react { useEffect }
import from .i18n { t, money, known_key }
import from .ui { Header, Card, theme, rows, obj, last_report }
import from .graph_view { GraphView }
import from .council { CouncilColumn }
import from .war_panels { NormalVsRakshaka, SignalsFeed }
import from .analyst { AnalystPanel }

sv import from ..walkers.api { get_war_room }

glob LANG: str = "en";
glob CARD_MS: int = 450;     # one agent card every 0.45 s
glob HOP_MS: int = 700;      # one walk hop every 0.7 s
# Small inline animations (no CSS file of our own).
glob ANIMATIONS: str = "@keyframes rkIn { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: none; } }"
    + " @keyframes rkDash { to { stroke-dashoffset: -32; } }"
    + " @keyframes rkPulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.35; } }";

"""One number in the top counter row."""
def:pub Counter(label: str, value: str, color: str = "#e2e8f0") -> JsxElement {
    return <div style={{"display": "flex", "flexDirection": "column", "minWidth": "110px"}}>
        <span style={{"fontSize": "32px", "fontWeight": "800", "color": color, "transition": "color 0.4s"}}>{value}</span>
        <span style={{"fontSize": "13px", "color": "#94a3b8", "textTransform": "uppercase", "letterSpacing": "0.04em"}}>{label}</span>
    </div>;
}

"""One victim in the detection row: name, bar, seconds or 'missed'."""
def:pub DetectChip(name: str, seconds: any, longest: float, last: bool) -> JsxElement {
    missed = seconds is None;
    secs = 0.0 if missed else seconds as float;
    c = "#ef4444" if missed else ("#22c55e" if secs < 5 else "#f59e0b");
    bar = 100 if missed else max(6, round(secs / longest * 100));
    return <div style={{"display": "flex", "alignItems": "center", "gap": "6px"}}>
        <div style={{"display": "flex", "flexDirection": "column", "gap": "3px", "width": "86px"}}>
            <span style={{"fontSize": "14px", "fontWeight": "700"}}>{name}</span>
            <div style={{"height": "6px", "borderRadius": "4px", "background": "#1e293b"}}>
                <div style={{"height": "100%", "width": str(bar) + "%", "borderRadius": "4px", "background": c, "transition": "width 0.6s"}} />
            </div>
            <span style={{"fontSize": "13px", "color": c}}>{t("war.missed", LANG) if missed else f"{secs:.1f} s"}</span>
        </div>
        {not last and <span style={{"color": "#475569"}}>{"→"}</span>}
    </div>;
}

"""Detection time per victim: Mallika missed -> Rasheed missed -> Seeya 41 s -> Kamala 0.6 s."""
def:pub DetectTimes(times: list[dict[str, any]]) -> JsxElement {
    longest = 1.0;
    for d in times {
        if d["seconds"] is not None and (d["seconds"] as float) > longest {
            longest = d["seconds"] as float;
        }
    }
    return <div style={{"display": "flex", "flexDirection": "column", "gap": "4px", "minWidth": "300px"}}>
        <span style={{"fontSize": "13px", "color": "#94a3b8", "textTransform": "uppercase", "letterSpacing": "0.04em"}}>{t("war.detect_times", LANG)}</span>
        <div style={{"display": "flex", "gap": "6px", "alignItems": "flex-end"}}>
            {for (i, d) in enumerate(times) {
                <DetectChip key={str(i)} name={d["name"] as str} seconds={d["seconds"]} longest={longest} last={i == len(times) - 1} />
            }}
        </div>
    </div>;
}

"""Scenario banner from the latest 'Scenario S3: The scam call (REQ-0001)' timeline line."""
def scenario_title(timeline: list[dict[str, any]]) -> str {
    title = "";
    for row in timeline {
        text = row["text"] as str;
        if text.startswith("Scenario ") {
            title = text.replace("Scenario ", "");
        }
    }
    return title;
}

"""Display name of a timeline agent (the raw name if we have no text for it)."""
def agent_name(agent: str) -> str {
    return t("agent." + agent, LANG) if known_key("agent." + agent) else agent;
}

"""Latest timeline lines, newest first."""
def:pub Timeline(timeline: list[dict[str, any]]) -> JsxElement {
    latest = [timeline[len(timeline) - 1 - i] for i in range(min(10, len(timeline)))];
    return <Card dark={True} title={t("war.timeline", LANG)}>
        {for (i, row) in enumerate(latest) {
            <div key={(row["time"] as str) + str(len(timeline) - i)} style={{"display": "flex", "gap": "12px", "padding": "4px 0", "fontSize": "15px",
                                                              "borderTop": "1px solid #1e293b" if i > 0 else "none",
                                                              "animation": "rkIn 0.4s ease-out" if i == 0 else "none"}}>
                <span style={{"color": "#64748b", "minWidth": "70px"}}>{row["time"]}</span>
                <strong style={{"minWidth": "150px", "color": "#38bdf8"}}>{agent_name(row["agent"] as str)}</strong>
                <span style={{"color": "#cbd5e1", "fontFamily": "'Noto Sans Sinhala', 'Noto Sans Tamil', Inter, sans-serif"}}>{row["text"]}</span>
            </div>
        }}
    </Card>;
}

def:pub WarRoom() -> JsxElement {
    has room: dict[str, any] = {},
        failed: bool = False,
        shown: int = 0,          # agent cards revealed so far (+1 = the ruling)
        hop: int = 0;            # walk hops animated so far

    async def load() {
        try {
            data = last_report(root spawn get_war_room());
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

    request_key = (obj(room["request"])["id"] or "") as str;
    total = len(rows(room["proposals"])) + (1 if room["ruling"] else 0);
    walk = obj(room["walk"]);
    walk_key = ((walk["kind"] or "") as str) + ":" + str(len((walk["path"] or []) as list[str])) + ":" + request_key;
    walk_target = (walk["step"] or 0) as int;

    # A new request: start the card reveal again. A new walk: start the hops again.
    useEffect(lambda { shown = 0; }, [request_key]);
    useEffect(lambda { hop = 0; }, [walk_key]);
    # Reveal the next card / hop a moment after the last one (each render reads fresh values).
    useEffect(lambda {
        if shown < total {
            timer = setTimeout(lambda { shown = shown + 1; }, CARD_MS);
            return lambda { clearTimeout(timer); };
        }
        return lambda { };
    }, [shown, total]);
    useEffect(lambda {
        if hop < walk_target {
            timer = setTimeout(lambda { hop = hop + 1; }, HOP_MS);
            return lambda { clearTimeout(timer); };
        }
        return lambda { };
    }, [hop, walk_target]);

    th = theme(True);
    page = {"background": th["bg"], "color": th["text"], "minHeight": "100vh"};
    if not room["counters"] {
        return <div style={page}>
            <Header title={t("screen.war_room", LANG)} lang={LANG} onLang={lambda (code: str) { }} dark={True} />
            <p style={{"padding": "24px", "fontSize": "20px"}}>{t("common.error", LANG) if failed else t("common.loading", LANG)}</p>
        </div>;
    }
    counters = obj(room["counters"]);
    timeline = rows(room["timeline"]);
    banner = scenario_title(timeline);
    return <div style={page}>
        <style>{ANIMATIONS}</style>
        <Header title={t("screen.war_room", LANG)} lang={LANG} onLang={lambda (code: str) { }} dark={True}>
            {banner and <span key={banner} style={{"fontSize": "20px", "fontWeight": "800", "color": "#fde047", "animation": "rkIn 0.5s ease-out"}}>{banner}</span>}
        </Header>
        <div style={{"display": "flex", "gap": "26px", "flexWrap": "wrap", "alignItems": "flex-end", "padding": "14px 20px",
                     "borderBottom": "1px solid " + th["line"]}}>
            <Counter label={t("war.checked", LANG)} value={str(counters["checked"])} />
            <Counter label={t("war.blocked", LANG)} value={str(counters["blocked"])} color="#ef4444" />
            <Counter label={t("war.held", LANG)} value={str(counters["held"])} color="#f59e0b" />
            <Counter label={t("war.protected", LANG)} value={money(counters["protected_rs"])} color="#22c55e" />
            <Counter label={t("war.recovered", LANG)} value={money(counters["recovered_rs"])} color="#67e8f9" />
            <Counter label={t("war.human", LANG)} value={str(counters["human_needed"])} color="#a78bfa" />
            <DetectTimes times={rows(counters["detect_times"])} />
        </div>
        <div style={{"display": "grid", "gridTemplateColumns": "minmax(0, 1.5fr) minmax(0, 1fr) minmax(0, 0.85fr)", "gap": "16px",
                     "padding": "16px 20px", "alignItems": "start"}}>
            <GraphView graph={obj(room["graph"])} walk={walk} hop={hop} />
            <CouncilColumn room={room} shown={shown} />
            <div style={{"display": "flex", "flexDirection": "column", "gap": "12px"}}>
                <NormalVsRakshaka normal={obj(room["normal_security"])} ruling={room["ruling"]} />
                <SignalsFeed signals={rows(room["signals"])} />
                <AnalystPanel alerts={rows(room["alerts"])} />
            </div>
        </div>
        <div style={{"padding": "0 20px 20px"}}><Timeline timeline={timeline} /></div>
    </div>;
}
