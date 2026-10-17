# Tests: seed data, ResetDemo and RunScenario (A)
import from graph.nodes { Citizen, Account, Request, Device, Place, ScamPattern, Lang }
import from graph.edges { Paid, Owns, Made }
import from graph.queries {
    all_nodes, all_citizens, all_accounts, all_guardians, find_account, find_citizen, find_analyst,
    find_request, demo_state, payee_of, device_of, place_of, citizen_of
}
import from seed.scenarios { seed_demo, RunScenario, ResetDemo }

"""How many nodes of each type, plus the total number of edges."""
def graph_counts() -> dict[str, int] {
    counts: dict[str, int] = {"edges": 0};
    for n in all_nodes() {
        kind = type(n).__name__;
        counts[kind] = counts.get(kind, 0) + 1;
        counts["edges"] = counts["edges"] + len([edge n -->]);
    }
    return counts;
}

"""Accounts that received money from this account."""
def paid_to(account_id: str) -> list[str] {
    a = find_account(account_id);
    return [] if a is None else [b.id for b in [a ->:Paid:->]];
}

"""Test helpers: find or fail (also narrows the type for the checker)."""
def acct(account_id: str) -> Account {
    a = find_account(account_id);
    assert a is not None, account_id;
    return a;
}

def req_of(request_id: str) -> Request {
    r = find_request(request_id);
    assert r is not None, request_id;
    return r;
}

def who(r: Request) -> Citizen {
    c = citizen_of(r);
    assert c is not None;
    return c;
}

def payee(r: Request) -> Account {
    a = payee_of(r);
    assert a is not None;
    return a;
}

def dev(r: Request) -> Device {
    d = device_of(r);
    assert d is not None;
    return d;
}

def place(r: Request) -> Place {
    p = place_of(r);
    assert p is not None;
    return p;
}

test "seed twice gives the same graph" {
    seed_demo();
    first = graph_counts();
    seed_demo();
    second = graph_counts();
    assert first == second, f"{first} != {second}";
    assert first["Bank"] == 3;
    assert first["Citizen"] == 24;     # 4 story elders + 20 normal citizens
    assert first["Guardian"] == 2;
    assert first["Analyst"] == 1;
    assert first["DemoState"] == 1;
    assert "Request" not in first;
}

test "no scam pattern at the start" {
    seed_demo();
    assert len([n for n in all_nodes() if isinstance(n, ScamPattern)]) == 0;
}

test "every person has a valid language" {
    seed_demo();
    valid = [Lang.SI, Lang.TA, Lang.EN];
    for c in all_citizens() {
        assert c.language in valid, c.id;
    }
    for g in all_guardians() {
        assert g.language in valid, g.id;
    }
    an = find_analyst();
    assert an is not None and an.language == Lang.EN;
    langs = {c.id: str(c.language) for c in all_citizens()};
    assert langs["c_seeya"] == "si" and langs["c_mallika"] == "si";
    assert langs["c_rasheed"] == "ta" and langs["c_kamala"] == "ta";
    assert {str(g.language) for g in all_guardians()} == {"si", "ta"};
    assert {"si", "ta", "en"} <= set(langs.values());
}

test "story people are seeded right" {
    seed_demo();
    seeya = find_citizen("c_seeya");
    assert seeya is not None;
    assert seeya.age == 74 and seeya.city == "Kandy" and seeya.is_elder;
    fd = acct("LDB-20115");
    assert fd.is_fd and fd.balance == 4200000;
    assert fd in [seeya ->:Owns:->];
    kamala = find_citizen("c_kamala");
    assert kamala is not None and kamala.city == "Trincomalee";
    assert all(a.bank == "IDB" for a in [kamala ->:Owns:->]);
    ages = [c.age for c in all_citizens() if c.id not in ["c_seeya", "c_mallika", "c_rasheed", "c_kamala"]];
    assert min(ages) >= 25 and max(ages) <= 80;
}

test "mule chain exists in order" {
    seed_demo();
    assert "CDB-40213" in paid_to("LDB-77821");
    assert "IDB-90077" in paid_to("CDB-40213");
    assert "ATM-IDB-0042" in paid_to("IDB-90077");
    ages = [acct(i).opened_days_ago for i in ["LDB-77821", "CDB-40213", "IDB-90077"]];
    assert ages == [9, 6, 4];
    # Mallika and Rasheed paid the first mule today
    assert "LDB-77821" in paid_to("CDB-30871") and "LDB-77821" in paid_to("IDB-41290");
    # Mallika's Rs 650,000 is still at CDB-40213
    assert acct("CDB-40213").balance == 650000;
}

test "Perera Hardware looks like a real shop" {
    seed_demo();
    shop = acct("CDB-11502");
    assert shop.opened_days_ago >= 3 * 365;
    senders = [a.id for a in [shop <-:Paid:<-]];
    assert len(senders) >= 10;
    assert "IDB-90077" in senders;
}

test "canvas positions fit 1000 x 600" {
    seed_demo();
    for c in all_citizens() {
        assert 0 < c.x < 250 and 0 < c.y < 600, c.id;
    }
    for a in all_accounts() {
        assert 250 < a.x < 1000 and 0 < a.y < 600, a.id;
    }
    assert acct("ATM-IDB-0042").x > acct("IDB-90077").x;
}

test "RunScenario S1 builds a normal bill payment" {
    seed_demo();
    w = root spawn RunScenario(name="S1");
    req = req_of(w.request_id);
    assert req.amount == 4500 and str(req.language) == "si";
    assert who(req).id == "c_seeya";
    assert payee(req).id == "LDB-10001";
    assert dev(req).trusted;
    assert place(req).name == "Kandy";
    assert demo_state().current_request == req.id;
}

test "RunScenario S2 uses a new laptop in Colombo after a Kandy login" {
    seed_demo();
    w = root spawn RunScenario(name="S2");
    req = req_of(w.request_id);
    assert req.time == "02:13" and req.amount == 900000;
    assert not dev(req).trusted and dev(req).kind == "Linux laptop";
    assert place(req).name == "Colombo";
    seeya = find_citizen("c_seeya");
    assert seeya is not None;
    logins = [r for r in [seeya ->:Made:->] if str(r.action) == "LOGIN"];
    assert len(logins) == 1 and logins[0].time == "02:03" and place(logins[0]).name == "Kandy";
}

test "RunScenario S3 and S4 carry the scam call" {
    seed_demo();
    s3 = req_of((root spawn RunScenario(name="S3")).request_id);
    assert s3.telemetry["on_call"] and s3.reference_text == "ආරක්ෂිත ගිණුම";
    s4 = req_of((root spawn RunScenario(name="S4")).request_id);
    assert str(s4.language) == "ta" and who(s4).id == "c_kamala";
    assert payee(s4).id == "IDB-31877";
}

test "ResetDemo clears requests and counters" {
    seed_demo();
    root spawn RunScenario(name="S3");
    demo_state().blocked = 5;
    root spawn ResetDemo();
    assert demo_state().blocked == 0 and demo_state().next_request == 1;
    assert find_request("REQ-0001") is None;
    assert len(demo_state().detect_times) == 2;
}

test "unknown scenario is reported, not crashed" {
    seed_demo();
    w = root spawn RunScenario(name="S9");
    assert w.request_id == "";
}
