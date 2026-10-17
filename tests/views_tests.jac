# Tests: screen data for C's API - war_room_data / phone_data / guardian_data / story_data (A)
import json;
import from graph.queries { find_citizen, set_person_language }
import from graph.views { war_room_data, phone_data, guardian_data, story_data }
import from seed.scenarios { seed_demo, RunScenario }
import from agents.council.arbiter { ApplyGuardianAnswer }

glob WAR_ROOM_KEYS: list[str] = [
    "graph", "request", "proposals", "ruling", "pressure", "walk", "signals", "alerts",
    "people_saw", "counters", "normal_security", "timeline"
];
glob STATES: list[str] = ["normal", "active", "suspect", "mule", "blocked", "frozen", "safe"];

# Typed views of JSON-like values (dict lookups are `any` for the checker).
def num(v: any) -> int {
    return int(v as int);
}

def items(v: any) -> list {
    return v as list;
}

def keys_of(v: any) -> list[str] {
    return sorted([str(k) for k in (v as dict).keys()]);
}

"""Run a scenario, return its request id."""
def run(name: str) -> str {
    return (root spawn RunScenario(name=name)).request_id;
}

"""State colour of one graph node in the War Room data."""
def state_of(d: dict, node_id: str) -> str {
    for n in items(d["graph"]["nodes"]) {
        if n["id"] == node_id {
            return str(n["state"]);
        }
    }
    return "";
}

"""Reject the first alert of a guardian."""
def reject_first(guardian_id: str) {
    alerts = guardian_data(guardian_id)["alerts"] as list[dict];
    root spawn ApplyGuardianAnswer(alert_id=str(alerts[0]["id"]), answer="REJECT");
}

test "war room before any request has the fixed shape" {
    seed_demo();
    d = war_room_data();
    assert sorted(d.keys()) == sorted(WAR_ROOM_KEYS);
    assert d["request"] is None and d["ruling"] is None and d["walk"] is None;
    assert d["normal_security"]["verdict"] == "ALLOW";
    nodes = d["graph"]["nodes"] as list[dict];
    ids = [n["id"] for n in nodes];
    for n in nodes {
        assert sorted(n.keys()) == ["id", "label", "state", "type", "x", "y"];
        assert n["state"] in STATES, n;
        assert 0 <= int(n["x"]) <= 1000 and 0 <= int(n["y"]) <= 600, n;
    }
    for e in d["graph"]["edges"] as list[dict] {
        assert sorted(e.keys()) == ["from", "label", "state", "to", "type"];
        assert e["from"] in ids and e["to"] in ids, e;
    }
    assert len([n for n in nodes if n["type"] == "Bank"]) == 3;
    assert len([n for n in nodes if n["type"] == "Citizen"]) == 24;
    assert json.dumps(d, ensure_ascii=False);
}

test "war room during the scam call (S3)" {
    seed_demo();
    run("S3");
    d = war_room_data();
    assert d["request"]["language"] == "si" and d["request"]["status"] == "HELD" and d["request"]["amount"] == 4200000;
    assert [p["agent"] for p in d["proposals"]] == ["COERCION", "PLACE_TIME", "ROUTINE", "MULE_RING", "PATTERN", "ADVOCATE"];
    assert keys_of(d["proposals"][0]) == ["agent", "confidence", "ms", "reason", "source", "stance"];
    assert d["ruling"]["decision"] == "HOLD" and d["ruling"]["locked"] and d["ruling"]["rule"] == "R3";
    assert num(d["pressure"]["value"]) >= 70 and len(items(d["pressure"]["reasons"])) == 3;
    assert d["walk"]["kind"] == "MULE_RING" and "c_mallika" in items(d["walk"]["path"]) and "c_rasheed" in items(d["walk"]["path"]);
    assert d["normal_security"] == {"password": True, "otp": True, "device": True, "place": True, "verdict": "ALLOW"};
    alerts = d["alerts"] as list[dict];
    assert len(alerts) == 1 and alerts[0]["kind"] == "GUARDIAN" and alerts[0]["language"] == "si";
    assert d["counters"]["held"] == 1 and d["counters"]["checked"] == 1;
    assert state_of(d, "c_seeya") == "active" and state_of(d, "LDB-77821") == "suspect";
    times = [t["time"] for t in d["timeline"]];
    assert times == sorted(times);
    assert json.dumps(d, ensure_ascii=False);
}

test "war room after the son rejects" {
    seed_demo();
    run("S3");
    reject_first("g_dilshan");
    d = war_room_data();
    c = d["counters"];
    assert c["protected_rs"] == 4200000 and c["blocked"] == 1 and c["human_needed"] == 1;
    assert [t for t in c["detect_times"] if t["name"] == "Mallika" and t["seconds"] is None];
    assert [t for t in c["detect_times"] if t["name"] == "Seeya" and t["seconds"] is not None];
    assert d["ruling"]["decision"] == "BLOCK";
    assert state_of(d, "c_seeya") == "safe" and state_of(d, "LDB-20115") == "safe";
    assert state_of(d, "LDB-77821") == "mule";
    assert d["alerts"][0]["status"] == "ANSWERED" and d["alerts"][0]["answer"] == "REJECT";
}

test "war room for the stolen password (S2)" {
    seed_demo();
    run("S2");
    d = war_room_data();
    ns = d["normal_security"];
    assert not ns["device"] and not ns["place"] and ns["password"] and ns["otp"];
    assert [s for s in items(d["signals"]) if s["kind"] == "SESSION_REVOKED" and s["account"] == "LDB-20114"];
    assert state_of(d, "CDB-63390") == "blocked";
}

test "phone data follows the request" {
    seed_demo();
    rid = run("S3");
    p = phone_data(rid);
    assert sorted(p.keys()) == ["balance", "fd", "language", "message", "pressure", "scam_breaker", "screen"];
    assert p["language"] == "si" and p["screen"] == "HELD" and num(p["pressure"]) >= 70;
    assert p["balance"] == 185000 and p["fd"] == 4200000;
    for k in ["active", "language", "questions", "warning", "answers"] {
        assert k in keys_of(p["scam_breaker"]), k;
    }
    reject_first("g_dilshan");
    after = phone_data(rid);
    assert after["screen"] == "BLOCKED" and after["message"] == "phone.msg.blocked_protected";
    s1 = phone_data(run("S1"));
    assert s1["screen"] == "DONE" and s1["message"] == "phone.msg.done";
    assert phone_data("REQ-9999")["screen"] == "FORM";
}

test "guardian data is in the guardian's language" {
    seed_demo();
    run("S3");
    g = guardian_data("g_dilshan");
    assert g["language"] == "si" and g["name"] == "Dilshan Siriwardena";
    alerts = g["alerts"] as list[dict];
    assert len(alerts) == 1 and alerts[0]["elder"] == "Seeya" and alerts[0]["options"] == ["REJECT", "CALL"];
    priya = guardian_data("g_priya");
    assert priya["language"] == "ta" and priya["alerts"] == [];
    assert guardian_data("nobody")["alerts"] == [];
}

test "language switch reaches the screens" {
    seed_demo();
    rid = run("S1");
    assert set_person_language("c_seeya", "en");
    assert phone_data(rid)["language"] == "en";
    assert war_room_data()["request"]["language"] == "en";
    assert set_person_language("g_dilshan", "en") and guardian_data("g_dilshan")["language"] == "en";
    assert set_person_language("an_fernando", "si");
    assert not set_person_language("c_seeya", "fr");
    c = find_citizen("c_seeya");
    assert c is not None and str(c.language) == "en";
}

test "story data tells the case in the elder's language" {
    seed_demo();
    run("S3");
    reject_first("g_dilshan");
    s = story_data();
    assert s["language"] == "si" and len(str(s["debrief"]).split("\n")) == 4;
    assert len(items(s["timeline"])) > 5;
}
