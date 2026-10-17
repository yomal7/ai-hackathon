# Trust Graph SVG (C). x/y come from A's seed. Nodes coloured by state, money edges thicker by amount,
# the Mule Ring / Money Tracer walk lit hop by hop with a moving dot (hop = how far the War Room has animated).
import from .i18n { t, money, ops_lang }
import from .ui { Card, color_of, rows }

glob STATES: list[str] = ["normal", "active", "suspect", "mule", "blocked", "frozen", "safe"];
# Higher wins when several payments between the same two accounts are drawn as one line.
glob SEVERITY: dict[str, int] = {"normal": 0, "safe": 1, "active": 2, "suspect": 3, "mule": 4, "blocked": 5, "frozen": 6};
glob WALK_COLOR: dict[str, str] = {"MULE_RING": "#FFE14A", "MONEY_TRACE": "#FF8FC7"};

"""Rs amount at the start of an edge label like 'Rs 650,000 · 14:02' (0 if none)."""
def label_amount(label: str) -> int {
    first = label.split("·")[0];
    digits = first.replace("Rs", "").replace(",", "").strip();
    return int(digits) if digits else 0;
}

"""Line width for a money flow: 1.5 for links, up to 9 for millions."""
def edge_width(amount: int) -> float {
    if amount <= 0 {
        return 1.2;
    }
    return min(9.0, max(1.5, len(str(amount)) - 2.5));
}

"""Payments between the same two nodes drawn as one line: total amount, worst state."""
def merge_edges(edges: list[dict[str, any]]) -> list[dict[str, any]] {
    merged: dict[str, dict[str, any]] = {};
    order: list[str] = [];
    for e in edges {
        key = (e["from"] as str) + ">" + (e["to"] as str) + ">" + (e["type"] as str);
        amount = label_amount(e["label"] as str) if e["type"] != "Owns" else 0;
        state = e["state"] as str;
        if key not in merged {
            merged[key] = {"from": e["from"], "to": e["to"], "type": e["type"], "amount": amount, "count": 1, "state": state};
            order.append(key);
        } else {
            m = merged[key];
            worse = state if SEVERITY[state] > SEVERITY[m["state"] as str] else m["state"];
            merged[key] = {**m, "amount": (m["amount"] as int) + amount, "count": (m["count"] as int) + 1, "state": worse};
        }
    }
    return [merged[k] for k in order];
}

"""[min x, min y, max x, max y] of the nodes. A loop: min(list) compiles to Math.min(array) = NaN in the browser."""
def bounds(nodes: list[dict[str, any]]) -> list[float] {
    box = [99999.0, 99999.0, -99999.0, -99999.0];
    for n in nodes {
        x = n["x"] as float;
        y = n["y"] as float;
        box = [min(box[0], x), min(box[1], y), max(box[2], x), max(box[3], y)];
    }
    return box if len(nodes) > 0 else [0.0, 0.0, 100.0, 100.0];
}

"""Is this node worth a label on a busy canvas?"""
def labelled(n: dict[str, any], lit: list[str]) -> bool {
    return n["type"] in ["Citizen", "Bank"] or n["state"] != "normal" or (n["id"] as str) in lit;
}

"""One bank's column band with its name on top."""
def:pub BankBand(n: dict[str, any], bottom: float) -> JsxElement {
    x = n["x"] as float;
    y = n["y"] as float;
    return <g>
        <rect x={x - 88} y={y - 12} width="176" height={bottom - y + 24} rx="14" fill="#141412" stroke="#2C2B27" />
        <text x={x} y={y + 6} fill="#9C978C" fontSize="15" fontWeight="700" textAnchor="middle">{n["label"]}</text>
    </g>;
}

"""One merged edge."""
def:pub GraphEdge(e: dict[str, any], a: dict[str, any], b: dict[str, any]) -> JsxElement {
    state = e["state"] as str;
    amount = e["amount"] as int;
    kind = e["type"] as str;
    hot = state != "normal";
    ax = a["x"] as float;
    ay = a["y"] as float;
    bx = b["x"] as float;
    by = b["y"] as float;
    if kind == "PaysTo" {
        return <g>
            <line x1={ax} y1={ay} x2={bx} y2={by} stroke={color_of(state)} strokeWidth={edge_width(amount) + 1}
                strokeDasharray="10 6" style={{"animation": "rkDash 1s linear infinite"}} />
            <text x={(ax + bx) / 2} y={(ay + by) / 2 - 8} fill={color_of(state)} fontSize="16" fontWeight="800" textAnchor="middle">
                {money(amount)}
            </text>
        </g>;
    }
    return <g>
        <line x1={ax} y1={ay} x2={bx} y2={by} stroke={color_of(state) if hot else "#77736A"}
            strokeOpacity={0.85 if hot else (0.10 if kind == "Owns" else 0.16)} strokeWidth={edge_width(amount)} />
        {hot and amount > 0 and <text x={(ax + bx) / 2} y={(ay + by) / 2 - 5} fill="#F2B544" fontSize="13" textAnchor="middle">
            {money(amount)}
        </text>}
    </g>;
}

"""One node: coloured dot, label if it matters, yellow ring once the walk reached it."""
def:pub GraphNode(n: dict[str, any], lit: bool, show_label: bool, ring: str) -> JsxElement {
    x = n["x"] as float;
    y = n["y"] as float;
    state = n["state"] as str;
    big = state != "normal" or lit;
    r = (10 if n["type"] == "Citizen" else 8) if big else 5;
    return <g>
        <title>{(n["label"] as str) + " (" + (n["id"] as str) + ") - " + t("state." + state, ops_lang())}</title>
        {lit and <circle cx={x} cy={y} r={r + 7} fill="none" stroke={ring} strokeWidth="3" style={{"animation": "rkPulse 1.4s ease-in-out infinite"}} />}
        <circle cx={x} cy={y} r={r} fill={color_of(state)} stroke="#0F0F0D" strokeWidth="1.5" style={{"transition": "fill 0.6s ease"}} />
        {state == "frozen" and <circle cx={x} cy={y} r={r + 4} fill="none" stroke={color_of(state)} strokeWidth="1.5" strokeDasharray="2 3" />}
        {show_label and <text x={x} y={y + r + 13} fill="#EDEAE2" fontSize={14 if big else 11} textAnchor="middle"
            fontWeight={"700" if big else "400"}>{n["label"]}</text>}
    </g>;
}

"""Colour legend under the graph."""
def:pub Legend() -> JsxElement {
    return <div style={{"display": "flex", "flexWrap": "wrap", "gap": "12px", "fontSize": "13px", "color": "#9C978C", "marginTop": "6px"}}>
        {for s in STATES {
            <span key={s} style={{"display": "inline-flex", "alignItems": "center", "gap": "5px"}}>
                <span style={{"width": "10px", "height": "10px", "borderRadius": "50%", "background": color_of(s), "display": "inline-block"}} />
                {t("state." + s, ops_lang())}
            </span>
        }}
    </div>;
}

def:pub GraphView(graph: dict[str, any], walk: dict[str, any], hop: int) -> JsxElement {
    nodes = rows(graph["nodes"]);
    pos: dict[str, dict[str, any]] = {};
    for n in nodes {
        pos[n["id"] as str] = n;
    }
    box = bounds(nodes);
    left = box[0] - 90;
    top = box[1] - 30;
    width = box[2] - box[0] + 180;
    height = box[3] - box[1] + 70;
    bottom = box[3] + 20;

    kind = (walk["kind"] or "MULE_RING") as str;
    ring = WALK_COLOR[kind] or "#FFE14A";
    path = (walk["path"] or []) as list[str];
    reached = min(hop, len(path) - 1);
    lit = path[:reached + 1];
    hops = [(path[i], path[i + 1]) for i in range(reached) if pos[path[i]] and pos[path[i + 1]]];
    edges = merge_edges(rows(graph["edges"]));
    calm = [e for e in edges if e["state"] == "normal" and e["type"] != "PaysTo"];
    hot = [e for e in edges if e["state"] != "normal" or e["type"] == "PaysTo"];
    dot = pos[path[reached]] if len(path) > 0 and reached >= 0 else None;

    return <Card dark={True} title={t("screen.graph", ops_lang())}>
        {len(path) > 0 and <div style={{"fontSize": "15px", "color": ring, "marginBottom": "4px"}}>
            {t("walk." + kind, ops_lang()) + " · " + t("war.hop", ops_lang()) + " " + str(reached) + "/" + str(len(path) - 1)}
        </div>}
        <svg viewBox={str(left) + " " + str(top) + " " + str(width) + " " + str(height)} style={{"width": "100%", "height": "auto", "display": "block"}}>
            {for b in nodes {
                if b["type"] == "Bank" { <BankBand key={"band-" + (b["id"] as str)} n={b} bottom={bottom} /> }
            }}
            {for e in calm + hot {
                if pos[e["from"] as str] and pos[e["to"] as str] {
                    <GraphEdge key={(e["from"] as str) + ">" + (e["to"] as str) + ">" + (e["type"] as str)} e={e}
                        a={pos[e["from"] as str]} b={pos[e["to"] as str]} />
                }
            }}
            {for (i, pair) in enumerate(hops) {
                <line key={"hop-" + str(i)} x1={pos[pair[0]]["x"]} y1={pos[pair[0]]["y"]} x2={pos[pair[1]]["x"]} y2={pos[pair[1]]["y"]}
                    stroke={ring} strokeWidth="4" strokeOpacity="0.9" strokeLinecap="round" style={{"filter": "drop-shadow(0 0 6px " + ring + ")"}} />
            }}
            {for n in nodes {
                if n["type"] != "Bank" {
                    <GraphNode key={n["id"]} n={n} lit={(n["id"] as str) in lit} show_label={labelled(n, lit)} ring={ring} />
                }
            }}
            {dot and <circle r="9" fill={ring} stroke="#0F0F0D" strokeWidth="2"
                style={{"transform": "translate(" + str(dot["x"]) + "px, " + str(dot["y"]) + "px)", "transition": "transform 0.6s ease-in-out",
                        "filter": "drop-shadow(0 0 8px " + ring + ")"}} />}
        </svg>
        <Legend />
    </Card>;
}
