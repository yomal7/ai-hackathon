# Public REST API (C). walker:pub = POST /walker/<name>. Names and return shapes are FIXED (section 8).
# Each endpoint uses FAKE data until A's / B's walker lands; then add its name to REAL.
import from graph.views { war_room_data, phone_data, guardian_data }
import from seed.scenarios { RunScenario, ResetDemo }
import from agents.council.arbiter { ApplyGuardianAnswer }
import from agents.council.scam_breaker { ScamAnswer }
import from agents.network.network { ApplyAnalystAnswer }
import from ai.llm_calls { debrief }
import from walkers.fake_data {
    fake_war_room, fake_phone, fake_guardian, fake_story, fake_start, fake_telemetry, fake_submit,
    fake_scam_answer, fake_guardian_answer, fake_analyst_answer, fake_set_language, fake_scenario, fake_reset
}

# Endpoints switched to the real walkers / functions (section 7). Empty = all fake.
glob REAL: list[str] = [];

glob LANG_CODES: list[str] = ["si", "ta", "en"];
glob ACTIONS: list[str] = ["BILL_PAY", "TRANSFER", "BREAK_FD", "LOGIN"];
glob SCENARIO_NAMES: list[str] = ["S1", "S2", "S3", "S4", "S5"];

"""True when this endpoint should call the real walker."""
def _real(name: str) -> bool {
    return name in REAL;
}

"""First report of a spawned walker, or the fallback if it reported nothing."""
def _first_report(reports: list[any], fallback: dict[str, any]) -> dict[str, any] {
    return (reports[0] as dict[str, any]) if reports else fallback;
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
        report war_room_data() if _real("get_war_room") else fake_war_room();
    }
}

"""What the elder's phone shows for one request ('' = latest)."""
walker:pub get_phone {
    has request_id: str = "";

    can go with Root entry {
        report phone_data(self.request_id) if _real("get_phone") else fake_phone(self.request_id);
    }
}

"""What a guardian's phone shows."""
walker:pub get_guardian {
    has guardian_id: str = "g_dilshan";

    can go with Root entry {
        report guardian_data(self.guardian_id) if _real("get_guardian") else fake_guardian(self.guardian_id);
    }
}

"""Debrief in the chosen language + timeline of the last case."""
walker:pub get_story {
    has language: str = "en";

    can go with Root entry {
        lang = self.language if self.language in LANG_CODES else "en";
        if _real("get_story") {
            room = war_room_data();
            report {"language": lang, "debrief": debrief(room, lang), "timeline": room["timeline"]};
        } else {
            report fake_story(lang);
        }
    }
}

# ---------------- Actions ----------------

"""Elder starts a request (draft). Reports {"request_id"}."""
walker:pub start_request {
    has citizen_id: str = "c_seeya";
    has action: str = "TRANSFER";
    has amount: int = 0;
    has payee: str = "";
    has reference: str = "";

    can go with Root entry {
        action = self.action if self.action in ACTIONS else "TRANSFER";
        amount = self.amount if self.amount > 0 else 0;
        report {"request_id": fake_start(self.citizen_id, action, amount, self.payee, self.reference)};
    }
}

"""New simulated device signals. Reports {"pressure"} 0-100."""
walker:pub telemetry_update {
    has request_id: str = "";
    has signals: dict[str, any] = {};

    can go with Root entry {
        report {"pressure": fake_telemetry(self.request_id, self.signals)};
    }
}

"""Submit the request to the Bank Council. Reports {"ruling"}."""
walker:pub submit_request {
    has request_id: str = "";

    can go with Root entry {
        report {"ruling": fake_submit(self.request_id)};
    }
}

"""Elder answers Scam-Breaker question q. Reports {"next_question"} (None = done)."""
walker:pub scam_answer {
    has request_id: str = "";
    has q: int = 0;
    has answer: str = "";

    can go with Root entry {
        if _real("scam_answer") {
            res = root spawn ScamAnswer(request_id=self.request_id, q=self.q, answer=self.answer);
            report _first_report(res.reports, {"next_question": None});
        } else {
            report {"next_question": fake_scam_answer(self.request_id, self.q, self.answer)};
        }
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
            root spawn ApplyGuardianAnswer(alert_id=self.alert_id, answer=self.answer);
            report {"ok": True};
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
        } else {
            fake_set_language(self.person_id, self.language);
            report {"ok": True};
        }
    }
}

"""Run demo scenario S1..S5. Reports {"request_id"}."""
walker:pub run_scenario {
    has name: str = "S1";

    can go with Root entry {
        name = self.name if self.name in SCENARIO_NAMES else "S1";
        if _real("run_scenario") {
            res = root spawn RunScenario(name=name);
            report _first_report(res.reports, {"request_id": ""});
        } else {
            report {"request_id": fake_scenario(name)};
        }
    }
}

"""Reset the whole demo. Reports {"ok"}."""
walker:pub reset_demo {
    can go with Root entry {
        if _real("reset_demo") {
            root spawn ResetDemo();
        } else {
            fake_reset();
        }
        report {"ok": True};
    }
}
