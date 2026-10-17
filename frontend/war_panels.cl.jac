# War Room right column (C): "Normal security vs Rakshaka" and the signals feed between the 3 banks.
import from .i18n { t }
import from .ui { Card, Badge, color_of, rows }

glob LANG: str = "en";
glob CHECKS: list[dict[str, str]] = [
    {"field": "password", "key": "war.password"},
    {"field": "otp", "key": "war.otp"},
    {"field": "device", "key": "war.device"},
    {"field": "place", "key": "war.place"}
];
glob SIGNAL_COLORS: dict[str, str] = {"OPEN": "#94a3b8", "AGREED": "#38bdf8", "OBJECTED": "#a78bfa", "DONE": "#22c55e"};

"""Password ✓ OTP ✓ device ✓ place ✓ -> ALLOW, next to what Rakshaka decided."""
def:pub NormalVsRakshaka(normal: dict[str, any], ruling: any) -> JsxElement {
    verdict = (normal["verdict"] or "ALLOW") as str;
    decision = ((ruling as dict[str, any])["decision"] as str) if ruling else "";
    big = {"fontSize": "26px", "fontWeight": "800"};
    return <Card dark={True} title={t("war.normal_vs", LANG)}>
        <div style={{"display": "grid", "gridTemplateColumns": "1fr 1fr", "gap": "12px"}}>
            <div>
                <div style={{"fontSize": "14px", "color": "#94a3b8", "marginBottom": "6px"}}>{t("war.normal_security", LANG)}</div>
                {for c in CHECKS {
                    <div key={c["field"]} style={{"display": "flex", "justifyContent": "space-between", "fontSize": "16px", "padding": "2px 0"}}>
                        <span>{t(c["key"], LANG)}</span>
                        <strong style={{"color": "#22c55e" if normal[c["field"]] else "#ef4444"}}>{"✓" if normal[c["field"]] else "✗"}</strong>
                    </div>
                }}
                <div style={{**big, "color": color_of(verdict), "marginTop": "6px"}}>{"→ " + t("decision." + verdict, LANG)}</div>
            </div>
            <div style={{"borderLeft": "1px solid #1e293b", "paddingLeft": "12px"}}>
                <div style={{"fontSize": "14px", "color": "#94a3b8", "marginBottom": "6px"}}>{t("war.rakshaka", LANG)}</div>
                <div style={{"fontSize": "14px", "color": "#cbd5e1"}}>{t("war.rakshaka_sees", LANG)}</div>
                <div style={{**big, "color": color_of(decision) if decision else "#94a3b8", "marginTop": "10px"}}>
                    {"→ " + (t("decision." + decision, LANG) if decision else "…")}
                </div>
            </div>
        </div>
        {decision in ["HOLD", "BLOCK"] and verdict == "ALLOW" and <p style={{"margin": "10px 0 0", "fontSize": "14px", "color": "#fbbf24"}}>{t("war.owner_coerced", LANG)}</p>}
    </Card>;
}

"""Signals between banks: LDB → CDB, kind, account, status."""
def:pub SignalsFeed(signals: list[dict[str, any]]) -> JsxElement {
    return <Card dark={True} title={t("war.signals", LANG)}>
        {if len(signals) == 0 {
            <span style={{"color": "#94a3b8"}}>{t("war.no_signals", LANG)}</span>
        }}
        {for (i, s) in enumerate(signals) {
            <div key={str(i)} style={{"display": "flex", "alignItems": "center", "gap": "8px", "padding": "6px 0",
                                      "borderTop": "1px solid #1e293b" if i > 0 else "none", "animation": "rkIn 0.4s ease-out"}}>
                <strong style={{"fontSize": "15px", "minWidth": "92px"}}>{(s["from_bank"] as str) + " → " + (s["to_bank"] as str)}</strong>
                <div style={{"flex": "1"}}>
                    <div style={{"fontSize": "14px"}}>{t("signal." + (s["kind"] as str), LANG)}</div>
                    <div style={{"fontSize": "13px", "color": "#94a3b8"}}>{s["account"]}</div>
                </div>
                <Badge text={s["status"] as str} color={SIGNAL_COLORS[s["status"] as str] or "#94a3b8"} />
            </div>
        }}
    </Card>;
}
