"""Tests for the Money Tracer (owner: Person B). Run: jac test tests/money_tracer_tests.jac
No network: keys cleared, so mule scores come from the code fallback + traced-money rule."""

import os;
import from graph.nodes { Account, Signal, Proposal }
import from graph.edges { Emitted, HasProposal }
import from agents.network.money_tracer { MoneyTracer, paid_out, paid_in }
import from agents.network.net_common { find_account, reset_network, WALK, HELD, to_minutes }
import from rules.network_rules { traced_score, network_verdict, advocate_objection, may_freeze }
import from tests.net_story { build_story }

with entry {
    for k in ["TYPESAFE_API_KEY", "GEMINI_API_KEY", "GOOGLE_API_KEY", "OPENAI_API_KEY", "ANTHROPIC_API_KEY"] {
        os.environ[k] = "";
    }
}

def signals_on(acc_id: str) -> list[Signal] {
    a = find_account(acc_id);
    return [s for s in [a ->:Emitted:->] if isinstance(s, Signal)] if a else [];
}

def tracer_score(acc_id: str) -> float {
    a = find_account(acc_id);
    ps = [p for p in [a ->:HasProposal:->] if isinstance(p, Proposal) and p.agent == "MONEY_TRACER"] if a else [];
    return ps[0].confidence if ps else -1.0;
}

glob _ids: dict[str, str] = {};

"""Build the S3 story and run the tracer ONCE for this file (graph writes are slow)."""
def trace() -> dict[str, str] {
    if not _ids {
        reset_network();
        _ids.update(build_story().ids);
        mule = find_account(_ids["LDB-77821"]);
        if mule is not None { mule spawn MoneyTracer(); }
    }
    return _ids;
}

"""Sort key for "H:MM" / "HH:MM" times."""
def _clock_key(t: str) -> str {
    return t.zfill(5);
}

"""The account with this id (fails the test if missing)."""
def acc(account_id: str) -> Account {
    a = find_account(account_id);
    assert a is not None, account_id;
    return a;
}

test "time parsing and money flows in time order" {
    assert to_minutes("10:20") == 620 and to_minutes("2026-10-17T10:20:00") == 620 and to_minutes("") is None;
    mule = acc(trace()["LDB-77821"]);
    outs = [f.time for f in paid_out(mule)];
    assert outs == sorted(outs, key=_clock_key);
    assert len(paid_in(mule)) == 2;
}

test "tracer finds Mallika's Rs 650,000 still at CDB-40213" {
    ids = trace();
    assert ids["CDB-40213"] in WALK["path"];
    assert WALK["kind"] == "MONEY_TRACE" and WALK["path"][0] == ids["LDB-77821"];
    assert WALK["step"] == len(list(WALK["path"])) - 1;
    h = HELD[ids["CDB-40213"]];
    assert h["amount"] == 650000 and h["victim"] == "Mallika";
    assert tracer_score(ids["CDB-40213"]) >= 0.8;
    assert [s.kind for s in signals_on(ids["CDB-40213"])] == ["FREEZE_REQUEST"];
    s = signals_on(ids["CDB-40213"])[0];
    assert s.from_bank == "LDB" and s.to_bank == "CDB" and s.status == "OPEN";
}

test "tracer follows Rasheed's money to the ATM: nothing left to freeze" {
    ids = trace();
    assert ids["IDB-99001"] in WALK["path"];
    assert HELD[ids["IDB-99001"]]["amount"] == 0;
    assert signals_on(ids["IDB-99001"]) == [];
    assert [s.kind for s in signals_on(ids["IDB-55001"])] == ["ACCOUNT_FLAGGED"];   # mule, but empty
}

test "tracer reaches Perera Hardware and asks to freeze (the advocate decides later)" {
    ids = trace();
    assert ids["CDB-11502"] in WALK["path"];
    assert [s.kind for s in signals_on(ids["CDB-11502"])] == ["FREEZE_REQUEST"];
    assert ids["CDB-60000"] not in WALK["path"];      # customers paid the shop; the trace only goes forward
}

test "the tracer never freezes anything" {
    ids = trace();
    for key in ["LDB-77821", "CDB-40213", "CDB-11502", "IDB-55001"] {
        assert acc(ids[key]).frozen == False;
    }
}

test "running the tracer twice does not duplicate signals" {
    ids = trace();
    mule = find_account(ids["LDB-77821"]);
    if mule is not None { mule spawn MoneyTracer(); }
    assert len(signals_on(ids["CDB-40213"])) == 1;
    assert len(signals_on(ids["LDB-77821"])) == 1;
}

test "network rules are plain code" {
    assert traced_score(12, None, "PERSONAL") == 0.85;
    assert traced_score(400, 5, "ATM_CASHOUT") == 0.0;
    assert network_verdict(0.85, 0.0) == "ASK_ANALYST";
    assert network_verdict(0.85, 0.85) == "DEADLOCK";
    assert network_verdict(0.5, 0.0) == "WATCH";
    assert advocate_objection(4200, "SHOP", 12, 13) >= 0.75;
    assert advocate_objection(12, "PERSONAL", 1, 1) == 0.0;
    assert may_freeze("APPROVE") and not may_freeze("KEEP_OPEN") and not may_freeze("");
}
