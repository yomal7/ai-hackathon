# Bank Council (3) - Routine: how far is this from the citizen's normal banking? (A)
# Walks only: Citizen->Has->Habit and the citizen's own Paid history. Evidence in code + Jev routine_level.
import time;
import from graph.nodes { Citizen, Account, Request, Proposal, AgentName, Scope, Stance }
import from graph.edges { Owns, Paid, Made, PaysTo }
import from ai.jev { jev_request_vector }
import from ai.lang { scam_keywords_hit, detect_language }
import from agents.council.council_common {
    ms_since, score, rs, clock12, hour_of, habits_of, largest_usual_payment, request_state,
    latest_pressure, put_proposal, stance_for, confidence_for, ACTION_WORDS
}

# Base risk per routine level: 0 Normal, 1 Unusual, 2 Very unusual, 3 Never seen.
glob LEVEL_RISK: list[float] = [0.1, 0.45, 0.72, 0.88];

# English meaning of seeded si / ta scam words, for the War Room reason.
# si / ta: to be checked by a native speaker.
glob GLOSS: dict[str, str] = {
    "ආරක්ෂිත ගිණුම": "safe account", "පොලිසිය": "police", "සීඅයිඩී": "CID",
    "பாதுகாப்பான கணக்கு": "safe account", "காவல்துறை": "police", "கைது": "arrest"
};

"""Routine level from code: amount / largest usual payment, or 3 for a first-ever action."""
def level_from_ratio(ratio: float, first_ever: bool) -> int {
    if first_ever {
        return 3;
    }
    if ratio < 2 {
        return 0;
    }
    if ratio < 5 {
        return 1;
    }
    if ratio < 50 {
        return 2;
    }
    return 3;
}

"""Accounts this citizen has paid before (from their own accounts' Paid history)."""
def known_payees(c: Citizen) -> list[str] {
    ids: list[str] = [];
    for a in [c ->:Owns:->] {
        ids.extend([b.id for b in [a ->:Paid:->]]);
    }
    return ids;
}

"""'note says 'X' (meaning)' for the first scam word found, in any language."""
def note_reason(hits: list[str]) -> str {
    w = hits[0];
    return f"note says '{w}' ({GLOSS[w]})" if w in GLOSS else f"note says '{w}'";
}

"""Spawned on a Request by RunCouncil. Writes one ROUTINE Proposal."""
walker RoutineAgent {
    can check with Request entry {
        t0 = time.perf_counter();
        owners = [here <-:Made:<-];
        if not owners {
            disengage;
        }
        c = owners[0];
        action = str(here.action);
        if action == "LOGIN" {
            put_proposal(here, Proposal(agent=AgentName.ROUTINE, scope=Scope.REQUEST, stance=Stance.ALLOW,
                confidence=0.9, reason="Login only, no money moves", ms=ms_since(t0), source="code"));
            disengage;
        }
        habits = habits_of(c);
        largest = largest_usual_payment(c);
        ratio = here.amount / largest if largest > 0 else 0.0;
        first_ever = action not in [h.action for h in habits];
        payees = [here ->:PaysTo:->];
        new_payee = bool(payees) and payees[0].id not in known_payees(c);
        hour = hour_of(here.time);
        odd_hour = not any([h.hour_from <= hour <= h.hour_to for h in habits]);
        hits = scam_keywords_hit(here.reference_text);

        # System 1 (Jev) reads the whole request too; it can only raise the level, never invent the amount math
        st = request_state(here);
        pr = latest_pressure(here);
        st["pressure"] = pr.value if pr is not None else 0;
        st["amount_ratio"] = ratio;
        st["first_time_action"] = first_ever;
        st["new_payee"] = new_payee;
        rv = jev_request_vector(st);
        level = max(level_from_ratio(ratio, first_ever), rv.routine_level);

        risk = LEVEL_RISK[level];
        if new_payee {
            risk += 0.05;
        }
        if odd_hour {
            risk += 0.06;
        }
        if hits {
            risk += 0.1;
        }
        risk = score(min(risk, 0.98));

        parts: list[str] = [];
        if first_ever {
            parts.append(f"First {ACTION_WORDS.get(action, action)} ever");
        }
        if ratio >= 2 {
            parts.append(f"{int(ratio + 0.5):,}× the usual payment ({rs(largest)})");
        } elif not first_ever {
            parts.append(f"usual amount ({rs(here.amount)})");
        }
        if new_payee {
            parts.append("new payee");
        }
        if odd_hour {
            parts.append(f"unusual hour ({clock12(here.time)})");
        }
        if hits {
            parts.append(note_reason(hits));
        }
        stance = stance_for(risk);
        why = "; ".join(parts) if parts else "Normal for this person";
        put_proposal(here, Proposal(
            agent=AgentName.ROUTINE, scope=Scope.REQUEST, stance=stance,
            confidence=confidence_for(stance, risk), reason=why[0].upper() + why[1:],
            ms=ms_since(t0), source=rv.source
        ));
    }
}
