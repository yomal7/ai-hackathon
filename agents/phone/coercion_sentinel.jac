# Layer 1 - Coercion Sentinel: live "pressure meter" 0-100 while the elder is in the transfer flow (A)
# Signals like "on a phone call" are SIMULATED toggles - a real bank app's SDK provides them.
import time;
import from graph.nodes { Request, PressureReading, Proposal, AgentName, Scope, Stance }
import from graph.edges { Read }
import from graph.queries { now_hms, now_s }
import from ai.jev { jev_pressure }
import from ai.lang { scam_keywords_hit }
import from agents.council.council_common { ms_since, score, request_state, put_proposal, confidence_for }

# Telemetry keys, most telling first. Used to pick the top 3 reasons (plain code).
glob SIGNAL_ORDER: list[str] = [
    "on_call", "remote_app", "reference_text", "pasted_account", "hesitation_ms", "backtracks", "typing_change", "new_payee"
];

"""True if this telemetry value is a warning sign."""
def is_sign(key: str, value: any) -> bool {
    if key == "hesitation_ms" {
        return int(value or 0) >= 4000;
    }
    if key == "backtracks" {
        return int(value or 0) >= 2;
    }
    return bool(value);
}

"""Short English reason for one telemetry sign."""
def reason_for(key: str, value: any) -> str {
    if key == "on_call" {
        return "On a phone call while paying";
    }
    if key == "remote_app" {
        return "Remote-access app is open";
    }
    if key == "pasted_account" {
        return "Account number was pasted";
    }
    if key == "hesitation_ms" {
        return f"Long pause ({int(value) // 1000} s) before confirming";
    }
    if key == "backtracks" {
        return f"Went back {int(value)} times";
    }
    if key == "typing_change" {
        return "Typing rhythm changed";
    }
    if key == "new_payee" {
        return "Paying a new payee";
    }
    return f"Note says '{value}'";
}

"""Top 3 reasons, in SIGNAL_ORDER. The reference note counts only if it has scam words."""
def top_reasons(req: Request) -> list[str] {
    reasons: list[str] = [];
    for key in SIGNAL_ORDER {
        if key == "reference_text" {
            hits = scam_keywords_hit(req.reference_text);
            if hits {
                reasons.append(reason_for(key, hits[0]));
            }
        } elif key in req.telemetry and is_sign(key, req.telemetry[key]) {
            reasons.append(reason_for(key, req.telemetry[key]));
        }
    }
    return reasons[:3];
}

"""Spawn on a Request on every telemetry change. signals = the changed keys
(telemetry keys, plus "reference_text" when the elder types the note). Reports {"pressure"}."""
walker CoercionSentinel {
    has signals: dict[str, any] = {};
    has pressure: int = 0;

    can sense with Request entry {
        t0 = time.perf_counter();
        tel = dict(here.telemetry);
        for (key, value) in self.signals.items() {
            if key == "reference_text" {
                here.reference_text = str(value);
            } else {
                tel[key] = value;
            }
        }
        here.telemetry = tel;   # assign a new dict so the change is saved
        # Start the detection clock at the first warning sign
        if here.first_signal_at == 0.0 and (top_reasons(here) or any([is_sign(str(k), v) for (k, v) in tel.items()])) {
            here.first_signal_at = now_s();
        }

        rv = jev_pressure(tel, request_state(here));
        value = int(score(rv.coached) * 100);
        reasons = top_reasons(here);
        here +>:Read:+> PressureReading(time=now_hms(), value=value, top_reasons=reasons);

        stance: Stance = Stance.HOLD if value >= 70 else (Stance.STEP_UP if value >= 40 else Stance.ALLOW);
        conf = confidence_for(stance, rv.coached);
        why = f"Pressure {value}: " + "; ".join(reasons) if reasons else f"Pressure {value}: no signs of a guided payment";
        put_proposal(here, Proposal(
            agent=AgentName.COERCION, scope=Scope.DEVICE, stance=stance, confidence=conf,
            reason=why, ms=ms_since(t0), source=rv.source
        ));
        self.pressure = value;
        report {"pressure": value};
    }
}
