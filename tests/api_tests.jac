# Tests: every public API walker returns the exact shape from section 8 (C).
import from walkers.api {
    get_war_room, get_phone, get_guardian, get_story, start_request, telemetry_update, submit_request,
    scam_answer, guardian_answer, analyst_answer, set_language, run_scenario, reset_demo
}

"""The single report of a spawned walker."""
def one(spawned: object) -> dict[str, any] {
    reports = getattr(spawned, "reports") as list[dict[str, any]];
    assert len(reports) == 1, f"{type(spawned).__name__} must report exactly once";
    return reports[0];
}

"""A JSON value as a dict."""
def obj_of(value: object) -> dict[str, any] {
    return value as dict[str, any];
}

"""A JSON value as a list of dicts."""
def rows(value: object) -> list[dict[str, any]] {
    return value as list[dict[str, any]];
}

"""Assert a dict has exactly these keys."""
def keys_are(value: object, want: list[str]) {
    got = sorted(obj_of(value).keys());
    assert got == sorted(want), f"keys {got} != {sorted(want)}";
}

test "reset demo" {
    keys_are(one(root spawn reset_demo()), ["ok"]);
}

test "war room shape" {
    room = one(root spawn get_war_room());
    keys_are(room, ["graph", "request", "proposals", "ruling", "pressure", "walk", "signals", "alerts",
                    "people_saw", "counters", "normal_security", "timeline"]);
    graph = obj_of(room["graph"]);
    keys_are(graph, ["nodes", "edges"]);
    for n in rows(graph["nodes"]) {
        keys_are(n, ["id", "type", "label", "x", "y", "state"]);
        assert n["state"] in ["normal", "active", "suspect", "mule", "blocked", "frozen", "safe"];
    }
    for e in rows(graph["edges"]) {
        keys_are(e, ["from", "to", "type", "label", "state"]);
    }
    if room["request"] is not None {
        keys_are(room["request"], ["id", "citizen", "language", "action", "amount", "payee", "status"]);
    }
    for p in rows(room["proposals"]) {
        keys_are(p, ["agent", "stance", "confidence", "reason", "ms", "source"]);
        assert p["source"] in ["jev", "llm", "code", "fallback"];
        assert 0.0 <= (p["confidence"] as float) <= 1.0;
    }
    if room["ruling"] is not None {
        keys_are(room["ruling"], ["decision", "why", "rule", "assurance", "ms", "deadlock", "locked"]);
    }
    keys_are(room["pressure"], ["value", "reasons"]);
    if room["walk"] is not None {
        keys_are(room["walk"], ["kind", "path", "step"]);
        assert obj_of(room["walk"])["kind"] in ["MULE_RING", "MONEY_TRACE"];
    }
    for s in rows(room["signals"]) {
        keys_are(s, ["kind", "account", "from_bank", "to_bank", "status"]);
    }
    for a in rows(room["alerts"]) {
        keys_are(a, ["id", "kind", "language", "title", "lines", "options", "status", "answer"]);
        assert a["language"] in ["si", "ta", "en"];
    }
    for ps in rows(room["people_saw"]) {
        keys_are(ps, ["who", "language", "text"]);
    }
    counters = obj_of(room["counters"]);
    keys_are(counters, ["checked", "blocked", "held", "protected_rs", "recovered_rs", "human_needed", "detect_times"]);
    for d in rows(counters["detect_times"]) {
        keys_are(d, ["name", "seconds"]);
    }
    keys_are(room["normal_security"], ["password", "otp", "device", "place", "verdict"]);
    for row in rows(room["timeline"]) {
        keys_are(row, ["time", "agent", "text"]);
    }
}

test "phone flow shapes" {
    started = one(root spawn start_request(citizen_id="c_seeya", action="BREAK_FD", amount=4200000, payee="LDB-77821", reference="safe account"));
    keys_are(started, ["request_id"]);
    rid = str(started["request_id"]);
    pressure = one(root spawn telemetry_update(request_id=rid, signals={"on_call": True, "pasted_account": True}));
    keys_are(pressure, ["pressure"]);
    assert 0 <= int(pressure["pressure"]) <= 100;
    submitted = one(root spawn submit_request(request_id=rid));
    keys_are(submitted, ["ruling"]);
    keys_are(submitted["ruling"], ["decision", "why", "rule", "assurance", "ms", "deadlock", "locked"]);
    phone = one(root spawn get_phone(request_id=rid));
    keys_are(phone, ["language", "screen", "pressure", "balance", "fd", "scam_breaker", "message"]);
    keys_are(phone["scam_breaker"], ["active", "language", "questions", "warning", "answers"]);
    keys_are(one(root spawn scam_answer(request_id=rid, q=0, answer="Yes, he says he is CID")), ["next_question"]);
}

test "guardian, analyst, language, story shapes" {
    one(root spawn run_scenario(name="S3"));
    guardian = one(root spawn get_guardian(guardian_id="g_dilshan"));
    keys_are(guardian, ["language", "name", "alerts"]);
    alerts = rows(guardian["alerts"]);
    assert len(alerts) >= 1;
    keys_are(one(root spawn guardian_answer(alert_id=str(alerts[0]["id"]), answer="REJECT")), ["ok"]);
    assert one(root spawn guardian_answer(alert_id="x", answer="MAYBE"))["ok"] == False;
    keys_are(one(root spawn analyst_answer(alert_id="al_an1", answer="APPROVE")), ["ok"]);
    assert one(root spawn set_language(person_id="c_seeya", language="ta"))["ok"] == True;
    assert one(root spawn set_language(person_id="c_seeya", language="fr"))["ok"] == False;
    keys_are(one(root spawn get_story(language="en")), ["language", "debrief", "timeline"]);
}

test "guardian reject turns the S3 hold into a block" {
    one(root spawn reset_demo());
    one(root spawn run_scenario(name="S3"));
    alert = rows(one(root spawn get_guardian(guardian_id="g_dilshan"))["alerts"])[0];
    assert obj_of(one(root spawn get_war_room())["ruling"])["decision"] == "HOLD";
    one(root spawn guardian_answer(alert_id=str(alert["id"]), answer="REJECT"));
    room = one(root spawn get_war_room());
    assert obj_of(room["ruling"])["decision"] == "BLOCK";
    assert obj_of(room["counters"])["protected_rs"] == 4200000;
}

test "device signals set before a request carry into it (S3 typed on the phone)" {
    one(root spawn reset_demo());
    calm = one(root spawn get_phone(request_id="latest:c_seeya"));
    assert calm["screen"] == "HOME";
    device = one(root spawn telemetry_update(request_id="", signals={"on_call": True, "pasted_account": True, "hesitation_ms": 9000}));
    assert int(device["pressure"]) > int(calm["pressure"]), "on a call + pasted account must raise pressure";
    rid = str(one(root spawn start_request(citizen_id="c_seeya", action="BREAK_FD", amount=4200000, payee="LDB-77821",
                                           reference="CID said move to safe account"))["request_id"]);
    phone = one(root spawn get_phone(request_id="latest:c_seeya"));
    assert phone["screen"] == "FORM";
    assert int(phone["pressure"]) >= 70, "device signals + 'safe account' note must be high pressure";
    ruling = obj_of(one(root spawn submit_request(request_id=rid))["ruling"]);
    assert ruling["decision"] == "HOLD" and ruling["locked"];
    assert one(root spawn get_phone(request_id=rid))["screen"] == "HELD";
}

test "a small known bill is allowed and latest:<citizen> follows the right person" {
    one(root spawn reset_demo());
    rid = str(one(root spawn start_request(citizen_id="c_seeya", action="BILL_PAY", amount=4500, payee="CEB-ELECTRICITY",
                                           reference="Electricity bill"))["request_id"]);
    assert obj_of(one(root spawn submit_request(request_id=rid))["ruling"])["decision"] == "ALLOW";
    one(root spawn run_scenario(name="S4"));
    assert one(root spawn get_phone(request_id="latest:c_seeya"))["screen"] == "ALLOWED";
    kamala = one(root spawn get_phone(request_id="latest:c_kamala"));
    assert kamala["screen"] == "HELD" and kamala["fd"] == 2600000;
}

test "every scenario returns a request id" {
    for name in ["S1", "S2", "S3", "S4", "S5"] {
        keys_are(one(root spawn run_scenario(name=name)), ["request_id"]);
    }
    one(root spawn reset_demo());
}
