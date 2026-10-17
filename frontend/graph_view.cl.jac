# Trust Graph SVG (C): nodes coloured by state, money edges thicker by amount, walk path highlighted.
# Full walk animation comes in M3.
import from .i18n { t }
import from .ui { Card, color_of, rows, obj }

glob W: int = 880;
glob H: int = 480;

"""Rs amount inside an edge label like 'Rs 650,000' (0 if none)."""
def label_amount(label: str) -> int {
    digits = label.replace("Rs", "").replace(",", "").strip();
    return int(digits) if digits else 0;
}

"""Edge width: thin for links, thicker for bigger money flows."""
def edge_width(label: str) -> float {
    amount = label_amount(label);
    if amount <= 0 {
        return 1.5;
    }
    return min(9.0, len(str(amount)) - 2.0);
}

def:pub GraphView(graph: dict[str, any], walk: dict[str, any]) -> JsxElement {
    pos: dict[str, dict[str, any]] = {};
    for n in rows(graph["nodes"]) {
        pos[n["id"] as str] = n;
    }
    path = (walk["path"] or []) as list[str];
    step = (walk["step"] or 0) as int;
    on_walk = path[:step + 1];
    return <Card dark={True} title={t("screen.graph", "en")}>
        <svg viewBox={"0 0 " + str(W) + " " + str(H)} style={{"width": "100%", "height": "auto"}}>
            {for e in rows(graph["edges"]) {
                if pos[e["from"] as str] and pos[e["to"] as str] {
                    <GraphEdge key={(e["from"] as str) + "-" + (e["to"] as str)} e={e} a={pos[e["from"] as str]} b={pos[e["to"] as str]} />
                }
            }}
            {for n in rows(graph["nodes"]) {
                <GraphNode key={n["id"]} n={n} lit={(n["id"] as str) in on_walk} />
            }}
        </svg>
    </Card>;
}

"""One edge with its money label."""
def:pub GraphEdge(e: dict[str, any], a: dict[str, any], b: dict[str, any]) -> JsxElement {
    label = e["label"] as str;
    state = e["state"] as str;
    ax = a["x"] as float;
    ay = a["y"] as float;
    bx = b["x"] as float;
    by = b["y"] as float;
    return <g>
        <line x1={ax} y1={ay} x2={bx} y2={by} stroke={color_of(state)}
            strokeOpacity={0.35 if state == "normal" else 0.8} strokeWidth={edge_width(label)} />
        {label and <text x={(ax + bx) / 2} y={(ay + by) / 2 - 6} fill="#94a3b8" fontSize="12" textAnchor="middle">{label}</text>}
    </g>;
}

"""One node: coloured circle + label; a yellow ring when the walk has reached it."""
def:pub GraphNode(n: dict[str, any], lit: bool) -> JsxElement {
    x = n["x"] as float;
    y = n["y"] as float;
    return <g style={{"transition": "all 0.5s ease"}}>
        {lit and <circle cx={x} cy={y} r="26" fill="none" stroke="#fde047" strokeWidth="3" />}
        <circle cx={x} cy={y} r={20 if n["type"] == "Citizen" else 15} fill={color_of(n["state"] as str)} />
        <text x={x} y={y + 34} fill="#e2e8f0" fontSize="13" textAnchor="middle">{n["label"]}</text>
    </g>;
}
