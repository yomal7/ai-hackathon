# Demo scenarios S1-S5, demo seed and reset (A)
# Walker names are FIXED (section 7): RunScenario(name), ResetDemo.
import from graph.nodes { Bank, Device, Request, RequestStatus }
import from graph.queries { demo_state, clear_demo, all_banks, find_citizen, create_request, add_timeline }
import from seed.banks { seed_banks }
import from seed.people { seed_places, seed_people }
import from seed.money { seed_money, layout_canvas }
import from agents.council.arbiter { RunCouncil }
import from agents.phone.coercion_sentinel { CoercionSentinel }
import from agents.network.net_common { reset_network }

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

# What the phone sees during a scam call, step by step: hesitation -> pasted account -> on a call -> the note.
# Each step goes through the Coercion Sentinel, so the pressure meter climbs.
def scam_call_steps(note: str) -> list[dict[str, any]] {
    return [
        {"hesitation_ms": 12000, "backtracks": 4},
        {"pasted_account": True, "new_payee": True},
        {"on_call": True, "typing_change": True},
        {"reference_text": note}
    ];
}

# S1-S5 (section 9). Every amount, time and text is fictional.
glob SCENARIOS: dict[str, dict[str, any]] = {
    "S1": {"title": "Normal day", "citizen": "c_seeya", "action": "BILL_PAY", "amount": 4500,
           "payee": "LDB-10001", "reference": "Electricity bill - October", "time": "10:15"},
    "S2": {"title": "Stolen password", "citizen": "c_seeya", "action": "TRANSFER", "amount": 900000,
           "payee": "CDB-63390", "reference": "", "time": "02:13", "place": "Colombo",
           "new_device": "Linux laptop", "earlier_login": {"time": "02:03", "place": "Kandy"}},
    "S3": {"title": "The scam call", "citizen": "c_seeya", "action": "BREAK_FD", "amount": 4200000,
           "payee": "LDB-77821", "reference": "", "time": "14:30",
           "steps": scam_call_steps(SCAM_REFERENCES["si_safe_account"])},
    "S4": {"title": "Network immunity", "citizen": "c_kamala", "action": "BREAK_FD", "amount": 2600000,
           "payee": "IDB-31877", "reference": "", "time": "14:40",
           "steps": scam_call_steps(SCAM_REFERENCES["ta_safe_account"])},
    "S5": {"title": "Hospital at 1 AM", "citizen": "c_seeya", "action": "BILL_PAY", "amount": 180000,
           "payee": "LDB-10004", "reference": "Kandy General Hospital - emergency admission", "time": "01:00"}
};

"""Wipe the graph and build the whole demo again. Running it twice gives the same graph."""
def seed_demo() {
    clear_demo();
    reset_network();     # B's Fraud Network memory
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
    # Telemetry starts empty; RunScenario (or the live phone screen) sends the steps.
    return create_request(
        cid, str(sc["action"]), sc["amount"] as int, str(sc["payee"]), str(sc["reference"]),
        str(sc["time"]), device, str(sc["place"]) if "place" in sc else ""
    );
}

"""Telemetry steps of a scenario (empty for S1, S2, S5)."""
def scenario_steps(name: str) -> list[dict[str, any]] {
    sc = SCENARIOS.get(name, {});
    return (sc["steps"] if "steps" in sc else []) as list[dict[str, any]];
}

"""Run demo scenario S1..S5: build its Request, replay its phone telemetry, then spawn the Bank Council.
live=True: only build the Request and report the steps - the phone screen replays them with
telemetry_update and then calls submit_request, so the pressure meter climbs on screen."""
walker RunScenario {
    has name: str = "S1";
    has live: bool = False;
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
        steps = scenario_steps(self.name);
        if self.live {
            report {"request_id": req.id, "steps": steps};
            disengage;
        }
        for step in steps {
            req spawn CoercionSentinel(signals=step);
        }
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
