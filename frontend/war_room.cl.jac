# War Room (C): THE star screen. Ink skin: dark, calm, big numbers for a projector. Polls get_war_room() every 1 s.
# Cards appear one by one; the Mule Ring / Money Tracer walk moves hop by hop on the graph.
import from react { useEffect }
import from .i18n { t, money, known_key, ops_lang, OPS }
import from .ui { Header, Card, Label, Spinner, theme, rows, obj, last_report, poll_begin, poll_end }
import from .theme { INK, SIGNAL, DISPLAY, MONO }
import from .graph_view { GraphView }
import from .council { CouncilColumn }
import from .war_panels { NormalVsRakshaka, SignalsFeed }
import from .analyst { AnalystPanel }

sv import from ..walkers.api { get_war_room }

glob CARD_MS: int = 450;     # one agent card every 0.45 s
glob HOP_MS: int = 700;      # one walk hop every 0.7 s

"""One number in the top stats strip."""
def:pub Counter(label: str, value: str, color: str = "#EDEAE2") -> JsxElement {
    return <div style={{"display": "flex", "flexDirection": "column", "gap": "2px", "padding": "4px 22px 4px 0", "minWidth": "120px"}}>
        <span style={{"fontFamily": DISPLAY, "fontSize": "36px", "fontWeight": "800", "lineHeight": "1.05", "color": color,
                      "fontVariantNumeric": "tabular-nums", "letterSpacing": "-0.02em", "transition": "color 0.4s"}}>{value}</span>
        <span style={{"fontFamily": MONO, "fontSize": "11.5px", "color": INK["muted"], "textTransform": "uppercase", "letterSpacing": "0.09em"}}>{label}</span>
    </div>;
}

"""One victim in the detection row: name, bar, seconds or 'missed'."""
def:pub DetectChip(name: str, seconds: any, longest: float, last: bool) -> JsxElement {
    missed = seconds is None;
    secs = 0.0 if missed else seconds as float;
    c = SIGNAL["danger"] if missed else (SIGNAL["safe"] if secs < 5 else SIGNAL["warn"]);
    bar = 100 if missed else max(6, round(secs / longest * 100));
    return <div style={{"display": "flex", "alignItems": "center", "gap": "8px"}}>
        <div style={{"display": "flex", "flexDirection": "column", "gap": "4px", "width": "92px"}}>
            <span style={{"fontSize": "15px", "fontWeight": "700"}}>{name}</span>
            <div style={{"height": "4px", "background": "#26251F"}}>
                <div style={{"height": "100%", "width": str(bar) + "%", "background": c, "transition": "width 0.6s"}} />
            </div>
            <span style={{"fontFamily": MONO, "fontSize": "12.5px", "color": c}}>{t("war.missed", ops_lang()) if missed else f"{secs:.1f} s"}</span>
        </div>
        {not last and <span style={{"color": INK["soft"], "fontSize": "18px"}}>{"→"}</span>}
    </div>;
}

"""Detection time per victim: Mallika missed -> Rasheed missed -> Seeya -> Kamala."""
def:pub DetectTimes(times: list[dict[str, any]]) -> JsxElement {
    longest = 1.0;
    for d in times {
        if d["seconds"] is not None and (d["seconds"] as float) > longest {
            longest = d["seconds"] as float;
        }
    }
    return <div style={{"display": "flex", "flexDirection": "column", "gap": "6px", "minWidth": "300px", "paddingLeft": "22px",
                        "borderLeft": "1px solid " + INK["line"]}}>
        <span style={{"fontFamily": MONO, "fontSize": "11.5px", "color": INK["muted"], "textTransform": "uppercase", "letterSpacing": "0.09em"}}>{t("war.detect_times", ops_lang())}</span>
        <div style={{"display": "flex", "gap": "8px", "alignItems": "flex-end"}}>
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
    return t("agent." + agent, ops_lang()) if known_key("agent." + agent) else agent;
}

"""Latest timeline lines, newest first."""
def:pub Timeline(timeline: list[dict[str, any]]) -> JsxElement {
    latest = [timeline[len(timeline) - 1 - i] for i in range(min(10, len(timeline)))];
    return <Card dark={True} title={t("war.timeline", ops_lang())}>
        {for (i, row) in enumerate(latest) {
            <div key={(row["time"] as str) + str(len(timeline) - i)} style={{"display": "grid", "gridTemplateColumns": "78px 180px 1fr", "gap": "12px",
                                                              "padding": "6px 0", "fontSize": "15px", "alignItems": "baseline",
                                                              "borderTop": "1px solid " + INK["line"] if i > 0 else "none",
                                                              "animation": "rkIn 0.4s ease-out" if i == 0 else "none"}}>
                <span style={{"fontFamily": MONO, "fontSize": "13px", "color": INK["muted"]}}>{row["time"]}</span>
                <strong style={{"color": INK["text"]}}>{agent_name(row["agent"] as str)}</strong>
                <span style={{"color": "#CFCBC1", "lineHeight": "1.5"}}>{row["text"]}</span>
            </div>
        }}
    </Card>;
}

def:pub WarRoom() -> JsxElement {
    has room: dict[str, any] = {},
        lang: str = "en",
        failed: bool = False,
        shown: int = 0,          # agent cards revealed so far (+1 = the ruling)
        hop: int = 0;            # walk hops animated so far

    OPS["lang"] = lang;          # every panel below reads this while it renders

    async def load() {
        if not poll_begin("war_room") {
            return;
        }
        try {
            data = last_report(root spawn get_war_room());
            if data {
                room = data;
                failed = False;
            }
        } except Exception {
            failed = True;
        }
        poll_end("war_room");
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

    page = {"background": INK["bg"], "color": INK["text"], "minHeight": "100vh"};
    header = <Header title={t("screen.war_room", lang)} lang={lang} onLang={lambda (code: str) { lang = code; }} dark={True}>
        {room["timeline"] and scenario_title(rows(room["timeline"])) and
            <span key={scenario_title(rows(room["timeline"]))} style={{"fontFamily": DISPLAY, "fontSize": "18px", "fontWeight": "800",
                  "background": SIGNAL["mark"], "color": "#16140F", "padding": "3px 12px", "borderRadius": "4px",
                  "animation": "rkIn 0.5s ease-out"}}>{scenario_title(rows(room["timeline"]))}</span>}
    </Header>;
    if not room["counters"] {
        return <div className="rk-ink" style={page}>
            {header}
            <p style={{"padding": "32px 24px", "fontSize": "20px", "display": "flex", "gap": "12px", "alignItems": "center"}}>
                {not failed and <Spinner size={20} />}
                {t("common.error", lang) if failed else t("common.loading", lang)}
            </p>
        </div>;
    }
    counters = obj(room["counters"]);
    timeline = rows(room["timeline"]);
    return <div className="rk-ink" style={page}>
        {header}
        <section style={{"display": "flex", "flexWrap": "wrap", "alignItems": "flex-end", "rowGap": "14px", "padding": "18px 24px",
                         "borderBottom": "1px solid " + INK["line"]}}>
            <Counter label={t("war.checked", lang)} value={str(counters["checked"])} />
            <Counter label={t("war.blocked", lang)} value={str(counters["blocked"])} color={SIGNAL["danger"]} />
            <Counter label={t("war.held", lang)} value={str(counters["held"])} color={SIGNAL["warn"]} />
            <Counter label={t("war.protected", lang)} value={money(counters["protected_rs"])} color={SIGNAL["safe"]} />
            <Counter label={t("war.recovered", lang)} value={money(counters["recovered_rs"])} color={SIGNAL["frozen"]} />
            <Counter label={t("war.human", lang)} value={str(counters["human_needed"])} color={SIGNAL["violet"]} />
            <DetectTimes times={rows(counters["detect_times"])} />
        </section>
        <div style={{"display": "grid", "gridTemplateColumns": "minmax(0, 1.5fr) minmax(0, 1fr) minmax(0, 0.85fr)", "gap": "18px",
                     "padding": "18px 24px", "alignItems": "start"}}>
            <GraphView graph={obj(room["graph"])} walk={walk} hop={hop} />
            <CouncilColumn room={room} shown={shown} />
            <div style={{"display": "flex", "flexDirection": "column", "gap": "14px"}}>
                <NormalVsRakshaka normal={obj(room["normal_security"])} ruling={room["ruling"]} />
                <SignalsFeed signals={rows(room["signals"])} />
                <AnalystPanel alerts={rows(room["alerts"])} />
            </div>
        </div>
        <div style={{"padding": "0 24px 28px"}}><Timeline timeline={timeline} /></div>
    </div>;
}
