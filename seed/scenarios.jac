# Demo scenarios S1-S5, demo seed and reset (A)
# Walker names are FIXED (section 7): RunScenario(name), ResetDemo.
import from graph.nodes { Bank, Device, Request, RequestStatus }
import from graph.queries { demo_state, clear_demo, all_banks, find_citizen, create_request, add_timeline }
import from seed.banks { seed_banks }
import from seed.people { seed_places, seed_people }
import from seed.money { seed_money, layout_canvas }
import from agents.council.arbiter { RunCouncil }

# Scam reference texts the scenarios type into the "reference" box.
# si / ta: to be checked by a native speaker.
glob SCAM_REFERENCES: dict[str, str] = {
    "en_safe_account": "safe account",
    "en_cid": "CID case",
    "si_safe_account": "ආරක්ෂිත ගිණුම",
    "si_police": "පොලිසිය",
    "ta_safe_account": "பாதுகாப்பான கணக்கு",
    "ta_police": "காவல்துறை",
    "singlish_police": "police case eka",
    "singlish_safe": "safe account ekata",
    "tanglish_customs": "customs fee kattanum"
};

# Telemetry an elder on a scam call produces. S3 / S4 replay these steps one by one (M2).
glob SCAM_CALL_STEPS: list[dict[str, any]] = [
    {"hesitation_ms": 12000, "backtracks": 4},
    {"pasted_account": True, "new_payee": True},
    {"on_call": True, "typing_change": True}
];

# S1-S5 (section 9). Every amount, time and text is fictional.
glob SCENARIOS: dict[str, dict[str, any]] = {
    "S1": {"title": "Normal day", "citizen": "c_seeya", "action": "BILL_PAY", "amount": 4500,
           "payee": "LDB-10001", "reference": "Electricity bill - October", "time": "10:15"},
    "S2": {"title": "Stolen password", "citizen": "c_seeya", "action": "TRANSFER", "amount": 900000,
           "payee": "CDB-63390", "reference": "", "time": "02:13", "place": "Colombo",
           "new_device": "Linux laptop", "earlier_login": {"time": "02:03", "place": "Kandy"}},
    "S3": {"title": "The scam call", "citizen": "c_seeya", "action": "BREAK_FD", "amount": 4200000,
           "payee": "LDB-77821", "reference": SCAM_REFERENCES["si_safe_account"], "time": "14:30",
           "steps": SCAM_CALL_STEPS},
    "S4": {"title": "Network immunity", "citizen": "c_kamala", "action": "BREAK_FD", "amount": 2600000,
           "payee": "IDB-31877", "reference": SCAM_REFERENCES["ta_safe_account"], "time": "14:40",
           "steps": SCAM_CALL_STEPS},
    "S5": {"title": "Hospital at 1 AM", "citizen": "c_seeya", "action": "BILL_PAY", "amount": 180000,
           "payee": "LDB-10004", "reference": "Kandy General Hospital - emergency admission", "time": "01:00"}
};

"""Wipe the graph and build the whole demo again. Running it twice gives the same graph."""
def seed_demo() {
    clear_demo();
    banks = seed_banks();
    places = seed_places();
    accounts = seed_people(banks, places);
    seed_money(banks, accounts);
    layout_canvas(banks);
    st = demo_state();
    st.detect_times = [{"name": "Mallika", "seconds": None}, {"name": "Rasheed", "seconds": None}];
    add_timeline("SYSTEM", "Demo reset - simulation, fictional data");
}

"""Seed only if the graph is empty (first start of the server)."""
def ensure_seeded() {
    if not all_banks() {
        seed_demo();
    }
}

"""Create the Request for scenario S1..S5 (no council yet). None if the name is unknown."""
def build_scenario_request(name: str) -> Request | None {
    if name not in SCENARIOS {
        return None;
    }
    sc = SCENARIOS[name];
    cid = str(sc["citizen"]);
    device: Device | None = None;
    if "earlier_login" in sc {
        # S2: the real owner logged in at home 10 min earlier, from his own phone
        login = sc["earlier_login"] as dict[str, str];
        earlier = create_request(cid, "LOGIN", 0, at_time=login["time"], place_name=login["place"]);
        if earlier is not None {
            earlier.status = RequestStatus.ALLOWED;
        }
    }
    if "new_device" in sc {
        device = Device(id=f"d_new_{name.lower()}", kind=str(sc["new_device"]), first_seen="today", trusted=False);
    }
    # Final telemetry = all steps merged. RunScenario replays them one by one from M2.
    telemetry: dict[str, any] = {};
    steps = (sc["steps"] if "steps" in sc else []) as list[dict[str, any]];
    for step in steps {
        telemetry.update(step);
    }
    return create_request(
        cid, str(sc["action"]), sc["amount"] as int, str(sc["payee"]), str(sc["reference"]),
        str(sc["time"]), device, str(sc["place"]) if "place" in sc else "", telemetry
    );
}

"""Run demo scenario S1..S5: build its Request, then spawn the Bank Council on it."""
walker RunScenario {
    has name: str = "S1";
    has request_id: str = "";

    can run with Root entry {
        ensure_seeded();
        req = build_scenario_request(self.name);
        if req is None {
            report {"request_id": None, "error": f"Unknown scenario {self.name}"};
            disengage;
        }
        self.request_id = req.id;
        add_timeline("SYSTEM", f"Scenario {self.name}: {SCENARIOS[self.name]['title']} ({req.id})");
        req spawn RunCouncil();
        report {"request_id": req.id};
    }
}

"""Delete everything and re-seed the demo graph. Counters go back to zero."""
walker ResetDemo {
    can reset with Root entry {
        seed_demo();
        report {"ok": True};
    }
}
