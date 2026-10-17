# FAKE data for the API until A's and B's walkers land (C). Delete this file when api.jac no longer uses it.
# Everything is fictional. Shapes match section 8 exactly.
# English only for now; S3 switches to Sinhala and S4 to Tamil when si/ta testing starts.
import from ai.jev { jev_pressure }
import from ai.llm_calls { scam_questions, guardian_card, analyst_card, debrief }

"""A request on the fake phone."""
obj FakeRequest {
    has id: str,
        citizen: str,
        action: str,
        amount: int,
        payee: str,
        reference: str,
        telemetry: dict[str, any] = {},
        status: str = "DRAFT",
        pressure: int = 0,
        answers: list[str] = [];
}

"""A guardian alert on the fake guardian phone."""
obj FakeAlert {
    has id: str,
        guardian: str,
        request: str,
        language: str,
        title: str,
        lines: list[str],
        options: list[str],
        status: str = "OPEN",
        answer: str = "";

    """The alert in the section 8 shape."""
    def shape() -> dict[str, any] {
        return {"id": self.id, "kind": "GUARDIAN", "language": self.language, "title": self.title, "lines": self.lines,
                "options": self.options, "status": self.status, "answer": self.answer};
    }
}

"""One person in the fake demo."""
obj FakePerson {
    has name: str,
        language: str = "en",
        balance: int = 0,
        fd: int = 0,
        guardian: str = "";
}

"""All fake demo state (one demo at a time)."""
obj FakeState {
    has next_id: int = 1,
        requests: dict[str, FakeRequest] = {},
        alerts: dict[str, FakeAlert] = {},
        langs: dict[str, str] = {},
        analyst_answers: dict[str, str] = {},
        last_request: str = "",
        device: dict[str, any] = {};    # simulated phone signals; every new request starts with them
}

# Payees each citizen has paid before (anything else is a new payee).
glob KNOWN_PAYEES: list[str] = ["CEB-ELECTRICITY", "KANDY-GENERAL-HOSPITAL", "NWSDB-WATER"];

glob STATE: FakeState = FakeState();

glob PEOPLE: dict[str, FakePerson] = {
    "c_seeya": FakePerson(name="Siriwardena (Seeya)", balance=185000, fd=4200000, guardian="g_dilshan"),
    "c_kamala": FakePerson(name="Kamala", balance=92000, fd=2600000, guardian="g_priya"),
    "g_dilshan": FakePerson(name="Dilshan"),
    "g_priya": FakePerson(name="Priya")
};

"""A demo scenario as a fake request."""
obj FakeScenario {
    has citizen: str,
        action: str,
        amount: int,
        payee: str,
        reference: str,
        status: str,
        telemetry: dict[str, any] = {};
}

glob SCENARIOS: dict[str, FakeScenario] = {
    "S1": FakeScenario(citizen="c_seeya", action="BILL_PAY", amount=4500, payee="CEB-ELECTRICITY", reference="Electricity bill", status="ALLOWED"),
    "S2": FakeScenario(citizen="c_seeya", action="TRANSFER", amount=900000, payee="IDB-55120", reference="", status="BLOCKED",
                       telemetry={"new_payee": True}),
    "S3": FakeScenario(citizen="c_seeya", action="BREAK_FD", amount=4200000, payee="LDB-77821", reference="safe account", status="HELD",
                       telemetry={"on_call": True, "pasted_account": True, "hesitation_ms": 9000, "new_payee": True}),
    "S4": FakeScenario(citizen="c_kamala", action="BREAK_FD", amount=2600000, payee="LDB-77821", reference="safe account", status="HELD",
                       telemetry={"on_call": True, "pasted_account": True, "new_payee": True}),
    "S5": FakeScenario(citizen="c_seeya", action="TRANSFER", amount=180000, payee="KANDY-GENERAL-HOSPITAL", reference="Hospital bill", status="STEP_UP")
};

"""Language of a person (set_language wins over the default)."""
def fake_lang(person_id: str) -> str {
    if person_id in STATE.langs {
        return STATE.langs[person_id];
    }
    return PEOPLE[person_id].language if person_id in PEOPLE else "en";
}

"""Pressure 0-100 from B's Jev (fallback rules today)."""
def fake_pressure(telemetry: dict[str, any], reference: str) -> int {
    return int(jev_pressure(telemetry, {"reference_text": reference}).coached * 100);
}

"""Request id for '' (latest), 'latest:<citizen_id>' or a real id; '' if none."""
def fake_resolve(request_id: str) -> str {
    if not request_id {
        return STATE.last_request;
    }
    if request_id.startswith("latest:") {
        citizen = request_id.split(":", 1)[1];
        mine = [r.id for r in STATE.requests.values() if r.citizen == citizen];
        return mine[-1] if mine else "";
    }
    return request_id if request_id in STATE.requests else "";
}

"""Start a request with the current device signals; returns its id."""
def fake_start(citizen_id: str, action: str, amount: int, payee: str, reference: str) -> str {
    rid = f"req_{STATE.next_id}";
    STATE.next_id += 1;
    signals = {**STATE.device, "new_payee": payee not in KNOWN_PAYEES};
    STATE.requests[rid] = FakeRequest(id=rid, citizen=citizen_id, action=action, amount=amount, payee=payee, reference=reference,
                                      telemetry=signals, pressure=fake_pressure(signals, reference));
    STATE.last_request = rid;
    return rid;
}

"""New device signals: kept on the device and merged into the open request ('' = latest draft).
Returns the pressure of that request, or of the device alone when no draft is open."""
def fake_telemetry(request_id: str, signals: dict[str, any]) -> int {
    STATE.device = {**STATE.device, **signals};
    rid = fake_resolve(request_id);
    req = STATE.requests.get(rid, None);
    if req is None or (not request_id and req.status != "DRAFT") {
        return fake_pressure(STATE.device, "");
    }
    req.telemetry = {**req.telemetry, **signals};
    req.pressure = fake_pressure(req.telemetry, req.reference);
    return req.pressure;
}

"""A ruling in the section 8 shape."""
def ruling(decision: str, why: str, rule: str, assurance: str, ms: int, deadlock: bool, locked: bool) -> dict[str, any] {
    return {"decision": decision, "why": why, "rule": rule, "assurance": assurance, "ms": ms, "deadlock": deadlock, "locked": locked};
}

"""Fake ruling for a request (simple code rule; the real rules come from A's Arbiter)."""
def fake_ruling(req: FakeRequest) -> dict[str, any] {
    if req.status == "ALLOWED" or (req.status in ["DRAFT", "CHECKING"] and req.amount < 100000) {
        return ruling("ALLOW", "Normal payment for this person", "R4", "HIGH", 310, False, False);
    }
    if req.status == "BLOCKED" {
        return ruling("BLOCK", "Stopped: confirmed scam or stolen password", "R2", "HIGH", 180, False, True);
    }
    if req.status == "STEP_UP" or (req.status == "DRAFT" and req.pressure < 40) {
        return ruling("STEP_UP", "Council deadlock: unusual time vs known hospital", "R5", "MEDIUM", 2300, True, False);
    }
    return ruling("HOLD", "Coached transfer of life savings to a mule-ring account", "R3", "HIGH", 412, False, True);
}

glob STATUS_OF: dict[str, str] = {"ALLOW": "ALLOWED", "BLOCK": "BLOCKED", "STEP_UP": "STEP_UP"};

"""Submit a request; returns the ruling."""
def fake_submit(request_id: str) -> dict[str, any] {
    rid = fake_resolve(request_id);
    if not rid {
        return fake_ruling(FakeRequest(id="", citizen="c_seeya", action="BREAK_FD", amount=4200000, payee="", reference="", status="HELD"));
    }
    req = STATE.requests[rid];
    result = fake_ruling(req);
    req.status = STATUS_OF.get(str(result["decision"]), "HELD");
    if req.status == "HELD" {
        _open_guardian_alert(req);
    }
    return result;
}

"""Open the guardian alert for a held request (B's guardian_card text). Approve is off: the hold is locked."""
def _open_guardian_alert(req: FakeRequest) {
    gid = PEOPLE[req.citizen].guardian if req.citizen in PEOPLE else "g_dilshan";
    lang = fake_lang(gid);
    card = guardian_card("Large transfer to a mule-ring account while on a call", [], lang);
    aid = "al_" + req.id;
    STATE.alerts[aid] = FakeAlert(id=aid, guardian=gid, request=req.id, language=lang, title=str(card["title"]),
                                  lines=card["lines"] as list[str], options=["REJECT", "CALL"]);
}

"""Run S1..S5 as a fake request; returns its id."""
def fake_scenario(name: str) -> str {
    sc = SCENARIOS[name] if name in SCENARIOS else SCENARIOS["S1"];
    rid = fake_start(sc.citizen, sc.action, sc.amount, sc.payee, sc.reference);
    req = STATE.requests[rid];
    req.telemetry = sc.telemetry;
    req.pressure = fake_pressure(sc.telemetry, sc.reference);
    req.status = sc.status;
    if req.status == "HELD" {
        _open_guardian_alert(req);
    }
    return rid;
}

"""Scam-Breaker questions for a citizen, in their language."""
def _questions(citizen: str) -> dict[str, any] {
    return scam_questions("fake police, safe account", fake_lang(citizen));
}

"""Store a Scam-Breaker answer; returns the next question or None."""
def fake_scam_answer(request_id: str, q: int, answer: str) -> str | None {
    req = STATE.requests.get(fake_resolve(request_id), None);
    if req is None {
        return None;
    }
    req.answers = req.answers + [answer];
    questions = _questions(req.citizen)["questions"] as list[str];
    return questions[q + 1] if q + 1 < len(questions) else None;
}

"""Guardian answered an alert. REJECT stops the transfer."""
def fake_guardian_answer(alert_id: str, answer: str) -> bool {
    alert = STATE.alerts.get(alert_id, None);
    if alert is None {
        return False;
    }
    alert.status = "ANSWERED";
    alert.answer = answer;
    if answer == "REJECT" and alert.request in STATE.requests {
        STATE.requests[alert.request].status = "BLOCKED";
    }
    return True;
}

"""Analyst answered an alert (the War Room fake reads it)."""
def fake_analyst_answer(alert_id: str, answer: str) -> bool {
    STATE.analyst_answers[alert_id] = answer;
    return True;
}

"""Remember a person's language."""
def fake_set_language(person_id: str, language: str) {
    STATE.langs[person_id] = language;
}

"""Back to an empty demo."""
def fake_reset() {
    global STATE;
    STATE = FakeState();
}

glob SCREEN_OF: dict[str, str] = {"DRAFT": "FORM"};

"""What the elder's phone shows ('' = latest request, 'latest:<citizen_id>' = that citizen's latest).
With no request yet: HOME, with the pressure of the device signals alone."""
def fake_phone(request_id: str) -> dict[str, any] {
    req = STATE.requests.get(fake_resolve(request_id), None);
    asked = request_id.split(":", 1)[1] if request_id.startswith("latest:") else "c_seeya";
    citizen = req.citizen if req is not None else (asked if asked in PEOPLE else "c_seeya");
    lang = fake_lang(citizen);
    person = PEOPLE[citizen];
    screen = SCREEN_OF.get(req.status, req.status) if req is not None else "HOME";
    pressure = req.pressure if req is not None else fake_pressure(STATE.device, "");
    breaker: dict[str, any] = {"active": False, "language": lang, "questions": [], "warning": "", "answers": []};
    if req is not None and req.status == "HELD" and pressure >= 70 {
        sq = _questions(citizen);
        breaker = {"active": True, "language": lang, "questions": sq["questions"], "warning": sq["warning"], "answers": req.answers};
    }
    return {"language": lang, "screen": screen, "pressure": pressure, "balance": person.balance, "fd": person.fd,
            "scam_breaker": breaker, "message": ""};
}

"""What a guardian's phone shows."""
def fake_guardian(guardian_id: str) -> dict[str, any] {
    gid = guardian_id if guardian_id in PEOPLE else "g_dilshan";
    alerts = [a.shape() for a in STATE.alerts.values() if a.guardian == gid];
    return {"language": fake_lang(gid), "name": PEOPLE[gid].name, "alerts": alerts};
}

"""Story screen: debrief + timeline."""
def fake_story(language: str) -> dict[str, any] {
    return {"language": language, "debrief": debrief({}, language), "timeline": fake_war_room()["timeline"]};
}

"""Graph node in the section 8 shape."""
def gnode(id: str, kind: str, label: str, x: int, y: int, state: str) -> dict[str, any] {
    return {"id": id, "type": kind, "label": label, "x": x, "y": y, "state": state};
}

"""Graph edge in the section 8 shape."""
def gedge(src: str, dst: str, kind: str, label: str, state: str) -> dict[str, any] {
    return {"from": src, "to": dst, "type": kind, "label": label, "state": state};
}

"""Council proposal in the section 8 shape."""
def proposal(agent: str, stance: str, confidence: float, reason: str, ms: int, source: str) -> dict[str, any] {
    return {"agent": agent, "stance": stance, "confidence": confidence, "reason": reason, "ms": ms, "source": source};
}

"""A fixed S3 moment: HOLD (R3, locked), pressure 82, Mule Ring walk, 3 signals, guardian + analyst alert.
A guardian REJECT turns it into BLOCK + Rs 4,200,000 protected; an analyst APPROVE freezes CDB-40213."""
def fake_war_room() -> dict[str, any] {
    seeya_lang = fake_lang("c_seeya");
    dilshan_lang = fake_lang("g_dilshan");
    g_card = guardian_card("Large transfer while on a call", [], dilshan_lang);
    a_card = analyst_card("Freeze CDB-40213 at Ceylon Demo Bank", [
        "Mallika's Rs 650,000 reached CDB-40213 (2 hops from LDB-77821)",
        "Account opened 6 days ago; next hop is an ATM cash-out",
        "Ceylon Liaison agrees to freeze"
    ]);
    analyst_answer = STATE.analyst_answers.get("al_an1", "");
    frozen = analyst_answer == "APPROVE";
    alerts = list(STATE.alerts.values());
    g_alert = alerts[-1] if alerts else FakeAlert(id="al_req_s3", guardian="g_dilshan", request="req_s3", language=dilshan_lang,
                                                  title=str(g_card["title"]), lines=g_card["lines"] as list[str], options=["REJECT", "CALL"]);
    rejected = g_alert.answer == "REJECT";
    return {
        "graph": {
            "nodes": [
                gnode("b_ldb", "Bank", "Lanka Demo Bank", 300, 40, "normal"),
                gnode("b_cdb", "Bank", "Ceylon Demo Bank", 640, 40, "normal"),
                gnode("p_kandy", "Place", "Home, Kandy", 80, 130, "normal"),
                gnode("c_seeya", "Citizen", "Seeya, 74", 80, 270, "safe" if rejected else "active"),
                gnode("d_seeya", "Device", "His phone", 80, 410, "normal"),
                gnode("a_seeya_fd", "Account", "LDB-10077 FD", 240, 270, "safe" if rejected else "active"),
                gnode("a_ldb_77821", "Account", "LDB-77821", 430, 270, "mule"),
                gnode("c_mallika", "Citizen", "Mallika, 69", 240, 130, "suspect"),
                gnode("a_mallika", "Account", "CDB-30117", 380, 150, "suspect"),
                gnode("c_rasheed", "Citizen", "Rasheed, 71", 240, 420, "suspect"),
                gnode("a_rasheed", "Account", "IDB-20963", 380, 400, "suspect"),
                gnode("a_cdb_40213", "Account", "CDB-40213", 620, 190, "frozen" if frozen else "mule"),
                gnode("a_atm", "Account", "ATM cash-out", 800, 190, "normal"),
                gnode("a_cdb_11502", "Account", "Perera Hardware", 620, 360, "suspect")
            ],
            "edges": [
                gedge("c_seeya", "p_kandy", "Usually", "", "normal"),
                gedge("c_seeya", "d_seeya", "Uses", "", "normal"),
                gedge("c_seeya", "a_seeya_fd", "Owns", "", "normal"),
                gedge("a_seeya_fd", "a_ldb_77821", "PaysTo", "Rs 4,200,000", "blocked" if rejected else "suspect"),
                gedge("c_mallika", "a_mallika", "Owns", "", "normal"),
                gedge("c_rasheed", "a_rasheed", "Owns", "", "normal"),
                gedge("a_mallika", "a_ldb_77821", "Paid", "Rs 650,000", "suspect"),
                gedge("a_rasheed", "a_ldb_77821", "Paid", "Rs 380,000", "suspect"),
                gedge("a_ldb_77821", "a_cdb_40213", "Paid", "Rs 650,000", "suspect"),
                gedge("a_cdb_40213", "a_atm", "Paid", "Rs 0", "normal"),
                gedge("a_ldb_77821", "a_cdb_11502", "Paid", "Rs 45,000", "normal")
            ]
        },
        "request": {"id": "req_s3", "citizen": "Siriwardena (Seeya)", "language": seeya_lang, "action": "BREAK_FD",
                    "amount": 4200000, "payee": "LDB-77821", "status": "BLOCKED" if rejected else "HELD"},
        "proposals": [
            proposal("COERCION", "HOLD", 0.82, "On a call, pasted account, note says 'safe account', 9 s hesitation", 310, "jev"),
            proposal("PLACE_TIME", "ALLOW", 0.9, "Known phone, at home in Kandy, 2:30 PM - all normal", 12, "code"),
            proposal("ROUTINE", "HOLD", 0.92, "First FD break ever, 700x his usual amount", 290, "jev"),
            proposal("MULE_RING", "BLOCK", 0.93, "Payee is 9 days old; Mallika and Rasheed paid it today", 41, "code"),
            proposal("PATTERN", "WATCH", 0.55, "Looks like fake police; no learned pattern yet", 280, "jev"),
            proposal("ADVOCATE", "HOLD", 0.7, "Looked for a real need (hospital, known payee) - found none", 2100, "llm"),
            proposal("SCAM_BREAKER", "ASK_GUARDIAN", 0.8, "Answer 'Yes, he says he is CID' reads COACHED", 330, "jev")
        ],
        "ruling": ruling("BLOCK", "Son rejected - confirmed scam", "R1", "HIGH", 412, False, True) if rejected
                  else ruling("HOLD", "Coached transfer of life savings to a mule-ring account", "R3", "HIGH", 412, False, True),
        "pressure": {"value": 82, "reasons": ["On a phone call", "Pasted account number", "Note says 'safe account'", "Long hesitation"]},
        "walk": {"kind": "MULE_RING", "path": ["a_seeya_fd", "a_ldb_77821", "a_mallika", "a_ldb_77821", "a_rasheed"], "step": 4},
        "signals": [
            {"kind": "ACCOUNT_FLAGGED", "account": "LDB-77821", "from_bank": "LDB", "to_bank": "CDB", "status": "AGREED"},
            {"kind": "FREEZE_REQUEST", "account": "CDB-40213", "from_bank": "LDB", "to_bank": "CDB", "status": "DONE" if frozen else "AGREED"},
            {"kind": "FREEZE_REQUEST", "account": "CDB-11502", "from_bank": "LDB", "to_bank": "CDB", "status": "OBJECTED"}
        ],
        "alerts": [
            g_alert.shape(),
            {"id": "al_an1", "kind": "ANALYST", "language": "en", "title": a_card["title"], "lines": a_card["lines"],
             "options": a_card["options"], "status": "ANSWERED" if analyst_answer else "OPEN", "answer": analyst_answer}
        ],
        "people_saw": [
            {"who": "Seeya (elder)", "language": seeya_lang, "text": scam_questions("fake police", seeya_lang)["warning"]},
            {"who": "Dilshan (son)", "language": dilshan_lang, "text": g_alert.title}
        ],
        "counters": {"checked": 3, "blocked": 2 if rejected else 1, "held": 0 if rejected else 1,
                     "protected_rs": 4200000 if rejected else 0, "recovered_rs": 650000 if frozen else 0, "human_needed": 1,
                     "detect_times": [{"name": "Mallika", "seconds": -1}, {"name": "Rasheed", "seconds": -1}, {"name": "Seeya", "seconds": 41}]},
        "normal_security": {"password": True, "otp": True, "device": True, "place": True, "verdict": "ALLOW"},
        "timeline": [
            {"time": "14:30:05", "agent": "COERCION", "text": "Pressure 82 - on a phone call, pasted account"},
            {"time": "14:30:41", "agent": "MULE_RING", "text": "LDB-77821 received money from Mallika and Rasheed today"},
            {"time": "14:30:42", "agent": "ROUTINE", "text": "First FD break ever, 700x usual"},
            {"time": "14:30:44", "agent": "ADVOCATE", "text": "No real need found"},
            {"time": "14:30:44", "agent": "ARBITER", "text": "HOLD (R3, locked) - Scam-Breaker + guardian"},
            {"time": "14:31:10", "agent": "SCAM_BREAKER", "text": "Reply reads COACHED"}
        ]
    };
}
