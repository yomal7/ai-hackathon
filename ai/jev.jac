"""System 1 — Jev (TypeSafe System One) calls (owner: Person B).
Every function asks Jev first. On no key, timeout or error it uses the code rules
in ai/fallback.jac — same return type, source = "fallback". The demo never waits
longer than JEV_TIMEOUT_MS (default 800 ms)."""

import json;
import time;
import hashlib;
import httpx;
import from concurrent.futures { ThreadPoolExecutor }
import from ai.env { env }
import from ai.types { RiskVector }
import from ai.lang { detect_language, scam_keywords_hit }
import from ai.fallback {
    fb_request_vector, fb_pressure, fb_pattern, fb_read_reply, fb_mule_score,
    state_text, to_float, round2, as_str
}

glob JEV_URL: str = "https://api.typesafe.ai/v1/systemone";
glob _client: httpx.Client = httpx.Client(timeout=5.0);
glob _pool: ThreadPoolExecutor = ThreadPoolExecutor(max_workers=4);
glob _cache: dict[str, dict] = {};
glob LAST: dict[str, dict] = {};     # per function: {"source", "ms"} of the latest call

# ---------- the one HTTP helper ----------

def _timeout_s() -> float {
    return to_float(env("JEV_TIMEOUT_MS", "800"), 800.0) / 1000.0;
}

def _post(body: dict, key: str) -> dict | None {
    r = _client.post(JEV_URL, headers={"Authorization": "Bearer " + key}, json=body);
    if r.status_code != 200 { return None; }
    return dict(r.json());
}

"""POST to Jev. Returns {"answers": {...}, "ms": int} or None (no key, timeout, error).
Successful answers are cached, so the same question twice is instant."""
def jev_call(state: dict, questions: dict) -> dict | None {
    key = env("TYPESAFE_API_KEY");
    if not key { return None; }
    body = {"model": "jev-latest", "state": state, "questions": questions};
    ck = hashlib.sha1(json.dumps(body, sort_keys=True, ensure_ascii=False, default=as_str).encode()).hexdigest();
    if ck in _cache { return {"answers": _cache[ck], "ms": 0, "cached": True}; }
    t0 = time.perf_counter();
    try {
        data = _pool.submit(_post, body, key).result(timeout=_timeout_s());
    } except Exception {
        return None;          # timeout or network error -> caller uses code fallback
    }
    if not isinstance(data, dict) or not isinstance(data.get("answers"), dict) { return None; }
    if len(_cache) > 500 { _cache.clear(); }
    answers = dict(data["answers"]);
    _cache[ck] = answers;
    return {"answers": answers, "ms": int((time.perf_counter() - t0) * 1000), "cached": False};
}

"""Open the connection early (call once at server start) so the first real call is fast."""
def jev_warmup() -> None {
    if env("TYPESAFE_API_KEY") {
        _pool.submit(jev_call, {"warmup": True}, {"ok": {"type": "noul", "instructions": "Is this a warm-up?"}});
    }
}

"""{"source": "jev"|"fallback", "ms": int} for the latest call of a function (for Proposal.source)."""
def jev_last(fn: str) -> dict {
    return LAST.get(fn, {"source": "fallback", "ms": 0});
}

def _mark(fn: str, source: str, t0: float) -> int {
    ms = int((time.perf_counter() - t0) * 1000);
    LAST[fn] = {"source": source, "ms": ms};
    return ms;
}

def _ans(res: dict, key: str) -> dict {
    a = res["answers"].get(key);
    return a if isinstance(a, dict) else {};
}

# ---------- questions (instructions in English; state may be any language) ----------

glob SCAM_TYPES: dict[str, str] = {
    "NONE": "No sign of a scam; a normal payment.",
    "FAKE_POLICE_SAFE_ACCOUNT": "Caller pretends to be police / CID, threatens arrest, says move money to a 'safe' or 'government' account, keep it secret.",
    "FAKE_BANK_STAFF": "Caller pretends to be bank staff and asks to move money or share codes to 'protect' the account.",
    "CUSTOMS_PARCEL_FEE": "A parcel or gift is held at customs and a fee must be paid to release it.",
    "ROMANCE": "An online partner the person never met asks for money.",
    "INVESTMENT_DOUBLE": "Promise to double money quickly through an investment.",
    "LOTTERY_FEE": "Person 'won' a lottery or prize and must pay a fee first."
};

glob DECISIONS: dict[str, str] = {
    "ALLOW": "Normal for this person; let it go through.",
    "STEP_UP": "Somewhat unusual; ask for an extra check first.",
    "HOLD": "Likely scam pressure on a real owner; pause and check with family.",
    "BLOCK": "Clearly not the owner (stolen login) or a known mule; stop it."
};

glob RISK_QUESTIONS: dict = {
    "coached": {
        "type": "noul",
        "instructions": "Is this person likely being told what to do by someone else right now?",
        "criteria": {
            "true": "Signs of coaching: on a phone call while paying, pasted account number, new payee, long hesitation, going back and forth, a reference like 'safe account' in any language, an amount far above normal.",
            "false": "A calm, normal payment the person makes by themselves, like a usual bill."
        }
    },
    "routine": {
        "type": "score",
        "instructions": "How far is this from this person's normal banking?",
        "criteria": ["Normal", "Unusual", "Very unusual", "Never seen"]
    },
    "scam_type": {"type": "choice", "instructions": "Which scam does this look like?", "criteria": SCAM_TYPES},
    "decision": {"type": "choice", "instructions": "What should the bank do?", "criteria": DECISIONS}
};

# Live meter: only behaviour signals count, not the amount (Routine judges the amount).
glob PRESSURE_QUESTIONS: dict = {
    "coached": {
        "type": "noul",
        "instructions": "Looking ONLY at the live behaviour signals in telemetry right now, is someone on the phone guiding this person while they use the bank app?",
        "criteria": {
            "true": "STRONG signs: on an active phone call, a remote-access app open, or a reference like 'safe account' / police words in any language. Several weak signs together WITH a strong sign make it very likely.",
            "false": "No strong sign. WEAK signs alone (long hesitation, going back, a pasted account number, a new payee, typing changed) are common for elderly people who are simply slow or careful, so alone they mean only mild pressure. A large amount alone is NOT a sign of coaching."
        }
    },
    "scam_type": {"type": "choice", "instructions": "Which scam does this look like? Say NONE if there are no scam signs.", "criteria": SCAM_TYPES}
};

"""Add the facts Jev needs: detected language, keyword hits, habit summary."""
def _enrich(state: dict) -> dict {
    s = dict(state);
    s.pop("pattern_phrases", None);
    text = state_text(state.get("reference_text", ""));
    s["reference_language"] = detect_language(text);
    s["scam_keyword_hits"] = scam_keywords_hit(state_text(state));
    habits = state.get("habits", []) or [];
    if habits {
        s["habit_summary"] = {
            "usual_actions": sorted(set([str(h.get("action", "")) for h in habits])),
            "largest_usual_amount": max([to_float(h.get("typical_amount", 0)) for h in habits])
        };
    }
    return s;
}

"""Jev answers -> RiskVector. Any missing field comes from the code fallback."""
def _to_vector(res: dict, fb: RiskVector) -> RiskVector {
    c = _ans(res, "coached").get("noul");
    r = _ans(res, "routine").get("score");
    st = _ans(res, "scam_type").get("choice");
    d = _ans(res, "decision").get("choice");
    return RiskVector(
        coached=round2(to_float(c)) if c is not None else fb.coached,
        routine_level=max(0, min(3, int(to_float(r) + 0.5))) if r is not None else fb.routine_level,
        scam_type=str(st) if st in SCAM_TYPES else fb.scam_type,
        decision=str(d) if d in DECISIONS else fb.decision,
        ms=int(res["ms"]), source="jev"
    );
}

# ---------- public functions (signatures fixed) ----------

"""Full risk read of one request. state may hold si / ta / en / Singlish text."""
def jev_request_vector(state: dict) -> RiskVector {
    t0 = time.perf_counter();
    fb = fb_request_vector(state);
    res = jev_call(_enrich(state), RISK_QUESTIONS);
    if res is None {
        fb.ms = _mark("jev_request_vector", "fallback", t0);
        return fb;
    }
    _mark("jev_request_vector", "jev", t0);
    return _to_vector(res, fb);
}

"""Coercion Sentinel live meter. Pressure meter = round(coached * 100). Cached, so toggling back is instant."""
def jev_pressure(telemetry: dict, request: dict) -> RiskVector {
    t0 = time.perf_counter();
    fb = fb_pressure(telemetry, request);
    st = {
        "telemetry": telemetry,
        "action": request.get("action", ""),
        "reference_text": request.get("reference_text", ""),
        "reference_language": detect_language(state_text(request.get("reference_text", ""))),
        "scam_keyword_hits": scam_keywords_hit(state_text(request))
    };
    res = jev_call(st, PRESSURE_QUESTIONS);
    if res is None {
        fb.ms = _mark("jev_pressure", "fallback", t0);
        return fb;
    }
    _mark("jev_pressure", "jev", t0);
    return _to_vector(res, fb);
}

"""One of pattern_names, or "NONE". Empty list -> "NONE" without calling Jev.
state["pattern_phrases"] {name: [phrases]} (optional) describes each pattern."""
def jev_pattern(state: dict, pattern_names: list[str]) -> str {
    t0 = time.perf_counter();
    if not pattern_names {
        _mark("jev_pattern", "code", t0);
        return "NONE";
    }
    phrases = state.get("pattern_phrases", {}) or {};
    crit: dict[str, str] = {"NONE": "Does not match any known scam pattern."};
    for name in pattern_names {
        crit[name] = "Matches the known scam pattern '" + name + "'. Typical phrases: " + ", ".join([str(p) for p in phrases.get(name, [])][:12]);
    }
    q = {"pattern": {"type": "choice", "instructions": "Which known scam pattern does this request match? Phrases may be in Sinhala, Tamil, English or Singlish.", "criteria": crit}};
    res = jev_call(_enrich(state), q);
    choice = _ans(res, "pattern").get("choice") if res is not None else None;
    if choice in crit {
        _mark("jev_pattern", "jev", t0);
        return str(choice);
    }
    _mark("jev_pattern", "fallback", t0);
    return fb_pattern(state, pattern_names);
}

glob REPLY_CRITERIA: dict[str, str] = {
    "COACHED": "The reply says yes, or mentions a caller, police, CID, bank staff, or being told to keep it secret. Someone is guiding them.",
    "NOT_COACHED": "The reply clearly says no; nobody is telling them what to do.",
    "UNSURE": "The reply is unclear or does not answer."
};

"""Scam-Breaker reply in any language -> COACHED / NOT_COACHED / UNSURE."""
def jev_read_reply(text: str) -> str {
    t0 = time.perf_counter();
    q = {"reading": {"type": "choice", "instructions": "An elderly bank customer answered a safety question (did someone on the phone tell you to do this / say they are police / tell you to keep it secret). The reply may be Sinhala, Tamil, English or Singlish. Read it.", "criteria": REPLY_CRITERIA}};
    res = jev_call({"reply": text, "reply_language": detect_language(text)}, q);
    choice = _ans(res, "reading").get("choice") if res is not None else None;
    if choice in REPLY_CRITERIA {
        _mark("jev_read_reply", "jev", t0);
        return str(choice);
    }
    _mark("jev_read_reply", "fallback", t0);
    return fb_read_reply(text);
}

glob MULE_CRITERIA: dict[str, str] = {
    "true": "Opened recently (under 90 days) AND gets money from a confirmed mule account (from_flagged = true) or from several unrelated people, often passing it on within minutes. A young personal account holding scam money that came straight from a mule is a mule.",
    "false": "An old established account (years) with steady normal activity, like a real shop or biller, or no link to mule money."
};

def _qkey(account_id: str) -> str {
    return "mule_" + "".join([ch if ch.isalnum() else "_" for ch in account_id]);
}

"""{account_id: mule score 0..1}. ONE Jev call, one noul question per account.
Account keys: id, kind, opened_days_ago, inflow_count, distinct_senders, minutes_to_move_on, from_flagged."""
def jev_mule_scores(accounts: list[dict]) -> dict {
    t0 = time.perf_counter();
    if not accounts {
        _mark("jev_mule_scores", "code", t0);
        return {};
    }
    q: dict = {};
    for a in accounts {
        aid = str(a.get("id", ""));
        q[_qkey(aid)] = {"type": "noul", "instructions": "Is account " + aid + " likely a money-mule account (a account used to pass on scam money)?", "criteria": MULE_CRITERIA};
    }
    res = jev_call({"accounts": accounts}, q);
    out: dict = {};
    for a in accounts {
        aid = str(a.get("id", ""));
        v = _ans(res, _qkey(aid)).get("noul") if res is not None else None;
        out[aid] = round2(to_float(v)) if v is not None else fb_mule_score(a);
    }
    _mark("jev_mule_scores", "jev" if res is not None else "fallback", t0);
    return out;
}
