# Tests: arbiter rules R1-R6, the Bank Council, the Coercion Sentinel and guardian answers (A)
import from graph.nodes { Request, Ruling, Proposal, Alert, ScamPattern, Signal, AlertKind }
import from graph.edges { Emitted, Raised, Read }
import from graph.queries { find_request, find_account, demo_state, create_request, payee_of }
import from seed.scenarios { seed_demo, RunScenario }
import from rules.arbiter_rules { apply_rules }
import from agents.phone.coercion_sentinel { CoercionSentinel }
import from agents.council.council_common { proposal_of, latest_pressure }
import from agents.council.arbiter { RunCouncil, ApplyGuardianAnswer, ruling_of }

# ---------- helpers ----------

"""Run a scenario and return its request."""
def run(name: str) -> Request {
    w = root spawn RunScenario(name=name);
    r = find_request(w.request_id);
    assert r is not None, name;
    return r;
}

def ruling(req: Request) -> Ruling {
    r = ruling_of(req);
    assert r is not None, req.id;
    return r;
}

def prop(req: Request, agent: str) -> Proposal {
    p = proposal_of(req, agent);
    assert p is not None, agent;
    return p;
}

"""The open-or-answered guardian alert of a request."""
def guardian_alert(req: Request) -> Alert {
    found = [a for a in [req ->:Raised:->] if a.kind == AlertKind.GUARDIAN];
    assert found, f"no guardian alert on {req.id}";
    return found[-1];
}

def answer(req: Request, ans: str) {
    root spawn ApplyGuardianAnswer(alert_id=guardian_alert(req).id, answer=ans);
}

"""A proposal dict for the pure rule tests."""
def p(agent: str, stance: str, conf: float, reason: str = "test") -> dict {
    return {"agent": agent, "stance": stance, "confidence": conf, "reason": reason};
}

glob CALM: list[dict] = [
    p("COERCION", "ALLOW", 0.9), p("PLACE_TIME", "ALLOW", 0.95), p("ROUTINE", "ALLOW", 0.9),
    p("MULE_RING", "ALLOW", 0.95), p("PATTERN", "ALLOW", 0.3), p("ADVOCATE", "ALLOW", 0.99)
];

# ---------- pure rules ----------

test "R1 a confirmed mule is always blocked" {
    out = apply_rules(CALM, {"payee_id": "LDB-77821", "payee_confirmed_mule": True, "amount": 1000, "largest_usual": 6000});
    assert out["decision"] == "BLOCK" and out["rule"] == "R1" and out["assurance"] == "HIGH";
    frozen = apply_rules(CALM, {"payee_id": "CDB-40213", "payee_frozen": True});
    assert frozen["decision"] == "BLOCK" and frozen["rule"] == "R1";
}

test "R2 impossible travel blocks and revokes the session" {
    props = CALM[:1] + [p("PLACE_TIME", "BLOCK", 0.95, "impossible travel")] + CALM[2:];
    out = apply_rules(props, {"amount": 900000, "largest_usual": 6000});
    assert out["decision"] == "BLOCK" and out["rule"] == "R2" and out["emit"] == ["SESSION_REVOKED"];
}

test "R3 holds a pressured big payment, locked only by mule ring or pattern" {
    props = [p("COERCION", "HOLD", 0.95), p("ROUTINE", "HOLD", 0.98), p("MULE_RING", "HOLD", 0.93), p("ADVOCATE", "WATCH", 0.6)];
    out = apply_rules(props, {"pressure": 95, "amount": 4200000, "largest_usual": 6000});
    assert out["decision"] == "HOLD" and out["rule"] == "R3" and out["locked"];
    assert out["ask_guardian"] and out["scam_breaker"];
    unlocked = apply_rules([p("COERCION", "HOLD", 0.95), p("MULE_RING", "STEP_UP", 0.4)],
                           {"pressure": 95, "amount": 4200000, "largest_usual": 6000});
    assert unlocked["rule"] == "R3" and not unlocked["locked"];
    small = apply_rules(props, {"pressure": 95, "amount": 20000, "largest_usual": 6000});
    assert small["rule"] != "R3";
}

test "R4 fast path allows a calm request" {
    out = apply_rules(CALM, {"pressure": 5, "amount": 4500, "largest_usual": 6000});
    assert out["decision"] == "ALLOW" and out["rule"] == "R4" and out["assurance"] == "LOW";
}

test "R5 deadlock steps up instead of blocking" {
    props = [p("ROUTINE", "HOLD", 0.78), p("PLACE_TIME", "STEP_UP", 0.4), p("ADVOCATE", "ALLOW", 0.85)];
    out = apply_rules(props, {"pressure": 0, "amount": 180000, "largest_usual": 6000});
    assert out["decision"] == "STEP_UP" and out["rule"] == "R5" and out["deadlock"];
    assert out["assurance"] == "MEDIUM" and out["ask_guardian"];
    assert "ROUTINE" in out["why"] and "ADVOCATE" in out["why"];
}

test "R6 asks System 2 but only accepts our decisions" {
    props = [p("ROUTINE", "STEP_UP", 0.5), p("ADVOCATE", "WATCH", 0.6)];
    out = apply_rules(props, {"pressure": 10, "amount": 30000, "largest_usual": 6000});
    assert out["rule"] == "R6";
    assert out["decision"] in ["ALLOW", "STEP_UP", "HOLD", "BLOCK", "ASK_GUARDIAN", "ASK_ANALYST"];
}

# ---------- the council on the demo scenarios ----------

test "S1 normal day is allowed by R4" {
    seed_demo();
    req = run("S1");
    assert str(req.status) == "ALLOWED";
    r = ruling(req);
    assert str(r.decision) == "ALLOW" and r.rule == "R4" and not r.deadlock;
    assert len([prop(req, a) for a in ["COERCION", "PLACE_TIME", "ROUTINE", "MULE_RING", "PATTERN", "ADVOCATE"]]) == 6;
}

test "S2 stolen password is blocked by R2 with SESSION_REVOKED" {
    seed_demo();
    req = run("S2");
    r = ruling(req);
    assert str(r.decision) == "BLOCK" and r.rule == "R2" and str(req.status) == "BLOCKED";
    sigs = [r ->:Emitted:->];
    assert len(sigs) == 1 and str(sigs[0].kind) == "SESSION_REVOKED" and sigs[0].subject_account == "LDB-20114";
    assert "impossible travel" in prop(req, "PLACE_TIME").reason;
    assert demo_state().blocked == 1;
}

test "S3 scam call is held, locked, and the son is asked in Sinhala" {
    seed_demo();
    req = run("S3");
    r = ruling(req);
    assert str(r.decision) == "HOLD" and r.rule == "R3" and r.locked and str(req.status) == "HELD";
    pr = latest_pressure(req);
    assert pr is not None and pr.value >= 70 and len(pr.top_reasons) == 3;
    a = guardian_alert(req);
    assert str(a.language) == "si" and a.options == ["REJECT", "CALL"] and len(a.lines) <= 3;
    assert [d for d in demo_state().detect_times if d["name"] == "Seeya" and d["seconds"] is not None];
}

test "Sinhala and Tamil notes both raise the scam signal in ROUTINE" {
    seed_demo();
    s3 = prop(run("S3"), "ROUTINE").reason;
    assert "ආරක්ෂිත ගිණුම" in s3 and "safe account" in s3 and "First FD break ever" in s3 and "700×" in s3;
    s4 = prop(run("S4"), "ROUTINE").reason;
    assert "பாதுகாப்பான கணக்கு" in s4 and "safe account" in s4;
}

test "S5 hospital at 1 AM is a deadlock, not a block, and the guardian can approve" {
    seed_demo();
    req = run("S5");
    r = ruling(req);
    assert str(r.decision) == "STEP_UP" and r.rule == "R5" and r.deadlock and not r.locked;
    assert str(prop(req, "ROUTINE").stance) == "HOLD" and str(prop(req, "ADVOCATE").stance) == "ALLOW";
    assert "APPROVE" in guardian_alert(req).options;
    answer(req, "APPROVE");
    assert str(ruling(req).decision) == "ALLOW" and str(req.status) == "ALLOWED";
    assert demo_state().human_needed == 1;
}

# ---------- guardian answers ----------

test "guardian Reject always stops the transfer" {
    seed_demo();
    req = run("S3");
    answer(req, "REJECT");
    assert str(ruling(req).decision) == "BLOCK" and str(req.status) == "BLOCKED" and req.confirmed_scam;
    payee = payee_of(req);
    assert payee is not None and payee.confirmed_mule;
    assert demo_state().protected_rs == 4200000;
    # also on a request that was NOT locked
    s5 = run("S5");
    answer(s5, "REJECT");
    assert str(s5.status) == "BLOCKED";
}

test "guardian Approve cannot open a locked HOLD; Call keeps it held" {
    seed_demo();
    req = run("S3");
    answer(req, "APPROVE");
    assert str(req.status) == "HELD" and str(ruling(req).decision) == "HOLD";
    answer(req, "CALL");
    assert str(req.status) == "HELD";
    assert [t for t in demo_state().timeline if "is calling" in str(t["text"])];
}

test "after a Reject the same mule account is blocked by R1" {
    seed_demo();
    answer(run("S3"), "REJECT");
    again = run("S3");
    r = ruling(again);
    assert str(r.decision) == "BLOCK" and r.rule == "R1";
}

test "S4 matches the learned pattern and is held in Tamil" {
    seed_demo();
    # What B's Pattern Learner leaves on the graph after S3
    root ++> ScamPattern(name="Fake CID — safe account", features=["on_call", "safe account"],
                         phrases=["safe account", "ආරක්ෂිත ගිණුම", "பாதுகாப்பான கணக்கு"], learned_from="REQ-0001");
    req = run("S4");
    pat = prop(req, "PATTERN");
    assert str(pat.stance) == "HOLD" and pat.confidence >= 0.75;
    r = ruling(req);
    assert str(r.decision) == "HOLD" and r.locked;
    assert str(guardian_alert(req).language) == "ta";
}

# ---------- Coercion Sentinel ----------

test "the pressure meter climbs step by step" {
    seed_demo();
    w = root spawn RunScenario(name="S3", live=True);
    req = find_request(w.request_id);
    assert req is not None and req.first_signal_at == 0.0;
    values: list[int] = [];
    for step in [{"hesitation_ms": 12000, "backtracks": 4}, {"pasted_account": True, "new_payee": True},
                 {"on_call": True}, {"reference_text": "ආරක්ෂිත ගිණුම"}] {
        s = req spawn CoercionSentinel(signals=step);
        values.append(s.pressure);
    }
    assert values == sorted(values) and values[-1] >= 70 and values[0] < 40, values;
    assert req.first_signal_at > 0.0 and req.reference_text == "ආරක්ෂිත ගිණුම";
    assert str(prop(req, "COERCION").stance) == "HOLD";
    assert len([req ->:Read:->]) == 4;
    c = req spawn RunCouncil();
    assert c.ruling["decision"] == "HOLD";
}
