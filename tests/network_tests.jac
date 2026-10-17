"""Tests for the whole Fraud Network (owner: Person B). Run: jac test tests/network_tests.jac
No network: keys cleared. Story: tests/net_story.jac (S3)."""

import os;
import from graph.nodes { Account, Signal, Alert, Proposal, ScamPattern }
import from graph.edges { Emitted, Raised, HasProposal }
import from agents.network.network { RunNetwork, ApplyAnalystAnswer, network_state, analyst_alerts }
import from agents.network.pattern_learner { pattern_catalog }
import from agents.network.net_common { find_account, find_alert, reset_network, TOTALS }
import from ai.jev { jev_pattern }
import from tests.net_story { forget_test_graph, build_story }

with entry {
    for k in ["TYPESAFE_API_KEY", "GEMINI_API_KEY", "GOOGLE_API_KEY", "OPENAI_API_KEY", "ANTHROPIC_API_KEY"] {
        os.environ[k] = "";
    }
}

glob _ids: dict[str, str] = {};

"""A NEW S3 story with the network already run. For tests that change things or read network memory."""
def fresh_s3() -> dict[str, str] {
    reset_network();
    story = build_story();
    story.request spawn RunNetwork();
    return story.ids;
}

"""One shared S3 story for read-only tests (graph writes are slow).
Tests may run in any order or in parallel (Jac 0.34 uses pytest workers), so nothing here changes it."""
def run_s3() -> dict[str, str] {
    if not _ids { _ids.update(fresh_s3()); }
    return _ids;
}

"""The account with this id (fails the test if missing)."""
def acc(account_id: str) -> Account {
    a = find_account(account_id);
    assert a is not None, account_id;
    return a;
}

"""The FREEZE_REQUEST signal on this account (fails the test if missing)."""
def signal_of(acc_id: str) -> Signal {
    found = [s for s in [acc(acc_id) ->:Emitted:->] if isinstance(s, Signal) and s.kind == "FREEZE_REQUEST"];
    assert found, acc_id;
    return found[0];
}

def liaison_stance(acc_id: str) -> str {
    a = find_account(acc_id);
    ps = [p for p in [a ->:HasProposal:->] if isinstance(p, Proposal) and p.agent == "LIAISON_CDB"] if a else [];
    return ps[0].stance if ps else "";
}

test "S3: Ceylon liaison agrees for CDB-40213 -> analyst alert, nothing frozen yet" {
    ids = run_s3();
    s = signal_of(ids["CDB-40213"]);
    assert s.status == "AGREED";
    assert liaison_stance(ids["CDB-40213"]) == "FREEZE";
    a = find_alert("AL-" + ids["CDB-40213"]);
    assert a is not None and a.kind == "ANALYST" and a.language == "en" and a.status == "OPEN";
    assert list(a.options) == ["APPROVE", "KEEP_OPEN"];
    assert len(a.lines) <= 3;
    assert acc(ids["CDB-40213"]).frozen == False;
}

test "S3: Perera Hardware -> advocate objects -> DEADLOCK alert with both sides" {
    ids = run_s3();
    s = signal_of(ids["CDB-11502"]);
    assert s.status == "OPEN";
    assert liaison_stance(ids["CDB-11502"]) == "WATCH";
    a = find_alert("AL-" + ids["CDB-11502"]);
    assert a is not None and "DEADLOCK" in a.title;
    assert a.lines[0].startswith("FOR freeze") and a.lines[1].startswith("AGAINST");
    assert acc(ids["CDB-11502"]).frozen == False;
}

test "a cross-bank freeze always needs the analyst" {
    ids = run_s3();
    for key in ["LDB-77821", "CDB-40213", "CDB-11502", "IDB-55001", "IDB-99001"] {
        assert acc(ids[key]).frozen == False, key;      # the network alone froze nothing
    }
    res = root spawn ApplyAnalystAnswer(alert_id="AL-NO-SUCH", answer="APPROVE");
    assert res.reports[0]["ok"] == False;
}

test "analyst APPROVE freezes CDB-40213 and recovers Rs 650,000 for Mallika" {
    ids = fresh_s3();
    res = root spawn ApplyAnalystAnswer(alert_id="AL-" + ids["CDB-40213"], answer="APPROVE");
    assert res.reports[0]["ok"];
    assert acc(ids["CDB-40213"]).frozen == True;
    assert signal_of(ids["CDB-40213"]).status == "DONE";
    assert TOTALS["recovered_rs"] == 650000;
    st = network_state();
    assert st["recovered_rs"] == 650000;
    assert len([t for t in st["timeline"] if "Mallika" in t["text"] and "recovered" in t["text"]]) == 1;
}

test "analyst KEEP_OPEN: Perera Hardware is never frozen" {
    ids = fresh_s3();
    root spawn ApplyAnalystAnswer(alert_id="AL-" + ids["CDB-11502"], answer="KEEP_OPEN");
    assert acc(ids["CDB-11502"]).frozen == False;
    assert signal_of(ids["CDB-11502"]).status == "OBJECTED";
    assert TOTALS["recovered_rs"] == 0;                     # keeping the shop open recovers nothing
    res = root spawn ApplyAnalystAnswer(alert_id="AL-" + ids["CDB-11502"], answer="APPROVE");   # already answered
    assert res.reports[0]["ok"] == False;
    assert acc(ids["CDB-11502"]).frozen == False;
}

test "pattern learned from S3 matches the Tamil S4 request (network immunity)" {
    run_s3();
    cat = pattern_catalog();
    assert "Fake CID — safe account" in cat;
    phrases = cat["Fake CID — safe account"];
    assert "ආරක්ෂිත ගිණුම" in phrases and "பாதுகாப்பான கணக்கு" in phrases;
    s4 = {"reference_text": "பாதுகாப்பான கணக்கு", "telemetry": {"on_call": True}, "pattern_phrases": cat};
    assert jev_pattern(s4, [str(k) for k in cat.keys()]) == "Fake CID — safe account";
    assert jev_pattern({"reference_text": "CEB electricity", "pattern_phrases": cat}, [str(k) for k in cat.keys()]) == "NONE";
}

test "network_state shape for the War Room" {
    ids = fresh_s3();
    st = network_state();
    for key in ["signals", "alerts", "walk", "recovered_rs", "timeline", "patterns"] {
        assert key in st, key;
    }
    assert st["walk"]["kind"] == "MONEY_TRACE" and ids["CDB-40213"] in st["walk"]["path"];
    mine = [a for a in analyst_alerts() if ids["CDB-40213"] in a["id"] or ids["CDB-11502"] in a["id"]];
    assert len(mine) == 2;
    assert all([set(a.keys()) >= {"id", "kind", "language", "title", "lines", "options", "status", "answer"} for a in mine]);
    agents = set([t["agent"] for t in st["timeline"]]);
    assert {"NETWORK", "PATTERN_LEARNER", "MONEY_TRACER", "LIAISON_CDB"}.issubset(agents);
}

# Runs last (tests run in file order on Jac 0.16): leave the shared graph as we found it,
# so other test files (A's War Room / seed tests) do not see our test stories.
test "zz clean up this file's test stories" {
    forget_test_graph(True);
    assert True;
}
