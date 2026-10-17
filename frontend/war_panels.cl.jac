# War Room right column (C): "Normal security vs Rakshaka" and the signals feed between the 3 banks.
import from .i18n { t, ops_lang }
import from .ui { Card, Badge, color_of, rows }

glob CHECKS: list[dict[str, str]] = [
    {"field": "password", "key": "war.password"},
    {"field": "otp", "key": "war.otp"},
    {"field": "device", "key": "war.device"},
    {"field": "place", "key": "war.place"}
];
glob SIGNAL_COLORS: dict[str, str] = {"OPEN": "#9C978C", "AGREED": "#7AA2FF", "OBJECTED": "#B19CFF", "DONE": "#5BD48A"};

"""Password ✓ OTP ✓ device ✓ place ✓ -> ALLOW, next to what Rakshaka decided."""
def:pub NormalVsRakshaka(normal: dict[str, any], ruling: any) -> JsxElement {
    verdict = (normal["verdict"] or "ALLOW") as str;
    decision = ((ruling as dict[str, any])["decision"] as str) if ruling else "";
    big = {"fontSize": "26px", "fontWeight": "800"};
    return <Card dark={True} title={t("war.normal_vs", ops_lang())}>
        <div style={{"display": "grid", "gridTemplateColumns": "1fr 1fr", "gap": "12px"}}>
            <div>
                <div style={{"fontSize": "14px", "color": "#9C978C", "marginBottom": "6px"}}>{t("war.normal_security", ops_lang())}</div>
                {for c in CHECKS {
                    <div key={c["field"]} style={{"display": "flex", "justifyContent": "space-between", "fontSize": "16px", "padding": "2px 0"}}>
                        <span>{t(c["key"], ops_lang())}</span>
                        <strong style={{"color": "#5BD48A" if normal[c["field"]] else "#FF6A5C"}}>{"✓" if normal[c["field"]] else "✗"}</strong>
                    </div>
                }}
                <div style={{**big, "color": color_of(verdict), "marginTop": "6px"}}>{"→ " + t("decision." + verdict, ops_lang())}</div>
            </div>
            <div style={{"borderLeft": "1px solid #2C2B27", "paddingLeft": "12px"}}>
                <div style={{"fontSize": "14px", "color": "#9C978C", "marginBottom": "6px"}}>{t("war.rakshaka", ops_lang())}</div>
                <div style={{"fontSize": "14px", "color": "#CFCBC1"}}>{t("war.rakshaka_sees", ops_lang())}</div>
                <div style={{**big, "color": color_of(decision) if decision else "#9C978C", "marginTop": "10px"}}>
                    {"→ " + (t("decision." + decision, ops_lang()) if decision else "…")}
                </div>
            </div>
        </div>
        {decision in ["HOLD", "BLOCK"] and verdict == "ALLOW" and <p style={{"margin": "10px 0 0", "fontSize": "14px", "color": "#F2B544"}}>{t("war.owner_coerced", ops_lang())}</p>}
    </Card>;
}

"""Signals between banks: LDB → CDB, kind, account, status."""
def:pub SignalsFeed(signals: list[dict[str, any]]) -> JsxElement {
    return <Card dark={True} title={t("war.signals", ops_lang())}>
        {if len(signals) == 0 {
            <span style={{"color": "#9C978C"}}>{t("war.no_signals", ops_lang())}</span>
        }}
        {for (i, s) in enumerate(signals) {
            <div key={str(i)} style={{"display": "flex", "alignItems": "center", "gap": "8px", "padding": "6px 0",
                                      "borderTop": "1px solid #2C2B27" if i > 0 else "none", "animation": "rkIn 0.4s ease-out"}}>
                <strong style={{"fontSize": "15px", "minWidth": "92px"}}>{(s["from_bank"] as str) + " → " + (s["to_bank"] as str)}</strong>
                <div style={{"flex": "1"}}>
                    <div style={{"fontSize": "14px"}}>{t("signal." + (s["kind"] as str), ops_lang())}</div>
                    <div style={{"fontSize": "13px", "color": "#9C978C"}}>{s["account"]}</div>
                </div>
                <Badge text={s["status"] as str} color={SIGNAL_COLORS[s["status"] as str] or "#9C978C"} />
            </div>
        }}
    </Card>;
}
