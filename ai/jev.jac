"""System 1 — Jev (TypeSafe System One) calls (owner: Person B).
M1: STUBS. Every function answers from code rules (source = "fallback").
M3 adds the real Jev call in front; signatures never change."""

import time;
import from ai.types { RiskVector }
import from ai.fallback {
    fb_request_vector, fb_pressure, fb_pattern, fb_read_reply, fb_mule_scores
}

def _ms_since(t0: float) -> int {
    return int((time.perf_counter() - t0) * 1000);
}

"""Full risk read of one request. state may hold si / ta / en / Singlish text."""
def jev_request_vector(state: dict) -> RiskVector {
    t0 = time.perf_counter();
    rv = fb_request_vector(state);
    rv.ms = _ms_since(t0);
    return rv;
}

"""Coercion Sentinel live meter. Pressure meter = round(coached * 100)."""
def jev_pressure(telemetry: dict, request: dict) -> RiskVector {
    t0 = time.perf_counter();
    rv = fb_pressure(telemetry, request);
    rv.ms = _ms_since(t0);
    return rv;
}

"""One of pattern_names, or "NONE"."""
def jev_pattern(state: dict, pattern_names: list[str]) -> str {
    return fb_pattern(state, pattern_names);
}

"""Scam-Breaker reply in any language -> COACHED / NOT_COACHED / UNSURE."""
def jev_read_reply(text: str) -> str {
    return fb_read_reply(text);
}

"""{account_id: mule score 0..1}."""
def jev_mule_scores(accounts: list[dict]) -> dict {
    return fb_mule_scores(accounts);
}
