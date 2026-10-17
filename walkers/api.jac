# Public REST API (C). walker:pub = POST /walker/<name>. Names and return shapes are FIXED (section 8).
# Each endpoint calls A's / B's real walkers and functions (section 7). Remove a name from REAL to fall
# back to walkers/fake_data.jac for that endpoint (demo safety net while a teammate's part is broken).
#
# Two conventions the screens rely on (handled here, so A's and B's code stays simple):
#   request_id ""                -> the demo's current request
#   request_id "latest:<cid>"    -> that citizen's newest request (Kamala's phone follows S4)
#   telemetry_update with ""     -> the signals stay on the device; the next request starts with them
import from operator { attrgetter }
import from graph.nodes { Request, RequestStatus }
import from graph.edges { Made, Owns, Paid }
import from graph.queries { demo_state, find_citizen, find_request, create_request, set_person_language }
import from graph.views { war_room_data, phone_data, guardian_data, story_data }
import from seed.scenarios { RunScenario, ResetDemo, scenario_steps, ensure_seeded }
import from agents.phone.coercion_sentinel { CoercionSentinel }
import from agents.council.arbiter { RunCouncil, ApplyGuardianAnswer }
import from agents.council.scam_breaker { ScamAnswer, scam_breaker_state }
import from agents.network.network { ApplyAnalystAnswer }
import from ai.jev { jev_pressure }
import from ai.llm_calls { debrief }
import from walkers.fake_data {
    fake_war_room, fake_phone, fake_guardian, fake_story, fake_start, fake_telemetry, fake_submit,
    fake_scam_answer, fake_guardian_answer, fake_analyst_answer, fake_set_language, fake_scenario, fake_reset
}

# Endpoints that use the real walkers. All of them since M3.
glob REAL: list[str] = [
    "get_war_room", "get_phone", "get_guardian", "get_story", "start_request", "telemetry_update",
    "submit_request", "scam_answer", "guardian_answer", "analyst_answer", "set_language", "run_scenario", "reset_demo"
];

glob LANG_CODES: list[str] = ["si", "ta", "en"];
glob ACTIONS: list[str] = ["BILL_PAY", "TRANSFER", "BREAK_FD", "LOGIN"];
glob SCENARIO_NAMES: list[str] = ["S1", "S2", "S3", "S4", "S5"];

# Simulated phone signals set before a request exists (control panel toggles, the phone's own paste).
# Changed in place (clear / update), so no `global` is needed (Jac 0.34 has no `global`).
glob DEVICE: dict[str, any] = {};

"""True when this endpoint should call the real walker."""
def _real(name: str) -> bool {
    return name in REAL;
}

# ---------------- helpers on A's graph ----------------

"""The Request a screen means: '' = current, 'latest:<cid>' = that citizen's newest, else the id."""
def resolve(request_id: str) -> Request | None {
    if not request_id {
        rid = demo_state().current_request;
        return find_request(rid) if rid else None;
    }
    if request_id.startswith("latest:") {
        c = find_citizen(request_id.split(":", 1)[1]);
        mine = sorted([c ->:Made:->], key=attrgetter("id")) if c is not None else [];
        return mine[-1] if mine else None;
    }
    return find_request(request_id);
}

"""Pressure 0-100 of the device signals alone (no request yet)."""
def device_pressure() -> int {
    return int(jev_pressure(DEVICE, {}).coached * 100);
}

"""Has this citizen paid this account before?"""
def known_payee(citizen_id: str, payee: str) -> bool {
    c = find_citizen(citizen_id);
    if c is None {
        return False;
    }
    for acct in [c ->:Owns:->] {
        if payee in [b.id for b in [acct ->:Paid:->]] {
            return True;
        }
    }
    return False;
}

"""Elder's phone with no request yet: home screen, own balances, device pressure."""
def home_phone(citizen_id: str) -> dict[str, any] {
    c = find_citizen(citizen_id);
    mine = [c ->:Owns:->] if c is not None else [];
    return {
        "language": str(c.language) if c is not None else "en", "screen": "HOME", "pressure": device_pressure(),
        "balance": sum([a.balance for a in mine if not a.is_fd]), "fd": sum([a.balance for a in mine if a.is_fd]),
        "scam_breaker": scam_breaker_state(""), "message": ""
    };
}

"""Send changed signals through A's Coercion Sentinel on a request; returns the new pressure."""
def sense(req: Request, signals: dict[str, any]) -> int {
    return (req spawn CoercionSentinel(signals=signals)).pressure;
}

"""Health check so we can see the server is up."""
walker:pub ping {
    can go with Root entry {
        report {"ok": True, "app": "rakshaka", "simulation": True};
    }
}

# ---------------- Reads (screens poll these) ----------------

"""Everything the War Room shows."""
walker:pub get_war_room {
    can go with Root entry {
        if _real("get_war_room") {
            ensure_seeded();    # first start of the server: build the demo graph once
        }
        report war_room_data() if _real("get_war_room") else fake_war_room();
    }
}

"""What the elder's phone shows ('' = current request, 'latest:<cid>' = that citizen's newest)."""
walker:pub get_phone {
    has request_id: str = "";

    can go with Root entry {
        if not _real("get_phone") {
            report fake_phone(self.request_id);
            disengage;
        }
        ensure_seeded();
        req = resolve(self.request_id);
        if req is not None {
            report phone_data(req.id);
        } else {
            citizen = self.request_id.split(":", 1)[1] if self.request_id.startswith("latest:") else "c_seeya";
            report home_phone(citizen);
        }
    }
}

"""What a guardian's phone shows."""
walker:pub get_guardian {
    has guardian_id: str = "g_dilshan";

    can go with Root entry {
        report guardian_data(self.guardian_id) if _real("get_guardian") else fake_guardian(self.guardian_id);
    }
}

"""Debrief + timeline of the current case. language '' = the elder's own language."""
walker:pub get_story {
    has language: str = "";

    can go with Root entry {
        if not _real("get_story") {
            report fake_story(self.language or "en");
            disengage;
        }
        story = story_data();
        if self.language in LANG_CODES and self.language != story["language"] and story["debrief"] {
            room = war_room_data();
            story = {**story, "language": self.language, "debrief": debrief((room["request"] or {}) as dict, self.language)};
        }
        report story;
    }
}

# ---------------- Actions ----------------

"""Elder starts a request (draft) with the current device signals. Reports {"request_id"}."""
walker:pub start_request {
    has citizen_id: str = "c_seeya";
    has action: str = "TRANSFER";
    has amount: int = 0;
    has payee: str = "";
    has reference: str = "";

    can go with Root entry {
        action = self.action if self.action in ACTIONS else "TRANSFER";
        amount = self.amount if self.amount > 0 else 0;
        if not _real("start_request") {
            report {"request_id": fake_start(self.citizen_id, action, amount, self.payee, self.reference)};
            disengage;
        }
        ensure_seeded();
        req = create_request(self.citizen_id, action, amount, self.payee, self.reference);
        if req is None {
            report {"request_id": ""};
            disengage;
        }
        sense(req, {**DEVICE, "new_payee": not known_payee(self.citizen_id, self.payee)});
        report {"request_id": req.id};
    }
}

"""New simulated device signals. Reports {"pressure"} 0-100.
request_id '' = keep them on the device and also apply them to the current request while it is a draft."""
walker:pub telemetry_update {
    has request_id: str = "";
    has signals: dict[str, any] = {};

    can go with Root entry {
        if not _real("telemetry_update") {
            report {"pressure": fake_telemetry(self.request_id, self.signals)};
            disengage;
        }
        if not self.request_id {
            DEVICE.update(self.signals);
        }
        req = resolve(self.request_id);
        if req is None or (not self.request_id and req.status != RequestStatus.DRAFT) {
            report {"pressure": device_pressure()};
        } else {
            report {"pressure": sense(req, self.signals)};
        }
    }
}

"""Submit the request to the Bank Council. Reports {"ruling"}."""
walker:pub submit_request {
    has request_id: str = "";

    can go with Root entry {
        if not _real("submit_request") {
            report {"ruling": fake_submit(self.request_id)};
            disengage;
        }
        req = resolve(self.request_id);
        if req is None {
            report {"ruling": None};
            disengage;
        }
        report {"ruling": (req spawn RunCouncil()).ruling};
    }
}

"""Elder answers Scam-Breaker question q. Reports {"next_question"} (None = done)."""
walker:pub scam_answer {
    has request_id: str = "";
    has q: int = 0;
    has answer: str = "";

    can go with Root entry {
        if not _real("scam_answer") {
            report {"next_question": fake_scam_answer(self.request_id, self.q, self.answer)};
            disengage;
        }
        req = resolve(self.request_id);
        rid = req.id if req is not None else self.request_id;
        root spawn ScamAnswer(request_id=rid, q=self.q, answer=self.answer);
        questions = (scam_breaker_state(rid).get("questions") or []) as list[str];
        report {"next_question": questions[self.q + 1] if self.q + 1 < len(questions) else None};
    }
}

"""Guardian answers: REJECT | APPROVE | CALL. Reports {"ok"}."""
walker:pub guardian_answer {
    has alert_id: str = "";
    has answer: str = "";

    can go with Root entry {
        if self.answer not in ["REJECT", "APPROVE", "CALL"] {
            report {"ok": False};
        } elif _real("guardian_answer") {
            report {"ok": (root spawn ApplyGuardianAnswer(alert_id=self.alert_id, answer=self.answer)).ok};
        } else {
            report {"ok": fake_guardian_answer(self.alert_id, self.answer)};
        }
    }
}

"""Analyst answers: APPROVE | KEEP_OPEN. Reports {"ok"}."""
walker:pub analyst_answer {
    has alert_id: str = "";
    has answer: str = "";

    can go with Root entry {
        if self.answer not in ["APPROVE", "KEEP_OPEN"] {
            report {"ok": False};
        } elif _real("analyst_answer") {
            root spawn ApplyAnalystAnswer(alert_id=self.alert_id, answer=self.answer);
            report {"ok": True};
        } else {
            report {"ok": fake_analyst_answer(self.alert_id, self.answer)};
        }
    }
}

"""Change a person's language (si | ta | en). Reports {"ok"}."""
walker:pub set_language {
    has person_id: str = "";
    has language: str = "en";

    can go with Root entry {
        if self.language not in LANG_CODES or not self.person_id {
            report {"ok": False};
        } elif _real("set_language") {
            report {"ok": set_person_language(self.person_id, self.language)};
        } else {
            fake_set_language(self.person_id, self.language);
            report {"ok": True};
        }
    }
}

"""Run demo scenario S1..S5. Reports {"request_id"}.
live=True (extra, optional): only build the request and also report its telemetry "steps"; the control
panel then replays them with telemetry_update and calls submit_request, so the pressure climbs on screen."""
walker:pub run_scenario {
    has name: str = "S1";
    has live: bool = False;

    can go with Root entry {
        name = self.name if self.name in SCENARIO_NAMES else "S1";
        if not _real("run_scenario") {
            report {"request_id": fake_scenario(name)};
            disengage;
        }
        DEVICE.clear();
        run = root spawn RunScenario(name=name, live=self.live);
        if self.live {
            report {"request_id": run.request_id, "steps": scenario_steps(name)};
        } else {
            report {"request_id": run.request_id};
        }
    }
}

"""Reset the whole demo. Reports {"ok"}."""
walker:pub reset_demo {
    can go with Root entry {
        DEVICE.clear();
        if _real("reset_demo") {
            root spawn ResetDemo();
        } else {
            fake_reset();
        }
        report {"ok": True};
    }
}
