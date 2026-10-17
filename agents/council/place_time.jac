# Bank Council (2) - Place & Time: impossible travel, new untrusted device, odd hour (A)
# Walks only: Request->At->Place, Request->From->Device, Citizen->Usually->Place, Citizen->Uses->Device.
import math;
import time;
import from graph.nodes { Citizen, Device, Place, Request, Proposal, AgentName, Scope, Stance }
import from graph.edges { Uses, Usually, Made, From, At }
import from graph.queries { hhmm_to_min }
import from agents.council.council_common { ms_since, rs, clock12, hour_of, put_proposal, confidence_for }

glob MAX_SPEED_KMH: float = 150.0;     # faster than this between two logins = impossible travel
glob BIG_AMOUNT: int = 100000;

"""00:00 - 05:00 counts as an odd hour."""
def is_odd_hour(hhmm: str) -> bool {
    return hour_of(hhmm) < 5;
}

"""The citizen's latest other request in the 3 hours before req (same demo day), with its place."""
def previous_request(c: Citizen, req: Request) -> Request | None {
    now = hhmm_to_min(req.time);
    best: Request | None = None;
    best_t = -1;
    for r in [c ->:Made:->] {
        t = hhmm_to_min(r.time);
        if r.id != req.id and 0 <= now - t <= 180 and [r ->:At:->] and t > best_t {
            best = r;
            best_t = t;
        }
    }
    return best;
}

"""Spawned on a Request by RunCouncil. Writes one PLACE_TIME Proposal."""
walker PlaceTimeAgent {
    can check with Request entry {
        t0 = time.perf_counter();
        owners = [here <-:Made:<-];
        if not owners {
            disengage;
        }
        c = owners[0];
        devices = [here ->:From:->];
        places = [here ->:At:->];
        dev = devices[0] if devices else None;
        place = places[0] if places else None;

        new_device = dev is None or not dev.trusted or dev not in [c ->:Uses:->];
        away = place is not None and place not in [c ->:Usually:->];
        odd = is_odd_hour(here.time);
        big = here.amount >= BIG_AMOUNT;

        # Impossible travel: distance / time from the last request's place
        travel = "";
        impossible = False;
        prev = previous_request(c, here);
        if prev is not None and place is not None {
            prev_place = [prev ->:At:->][0];
            km = math.hypot(place.x - prev_place.x, place.y - prev_place.y);
            minutes = hhmm_to_min(here.time) - hhmm_to_min(prev.time);
            speed = km / (max(minutes, 1) / 60.0);
            if km > 30 and speed > MAX_SPEED_KMH {
                impossible = True;
                travel = f"{minutes} min after a {prev_place.name} login ({int(km)} km away)";
            }
        }

        where = place.name if place is not None else "an unknown place";
        what = dev.kind if dev is not None else "an unknown device";
        stance: Stance = Stance.ALLOW;
        risk: float = 0.05;
        why: str = "";
        if impossible {
            stance = Stance.BLOCK;
            risk = 0.95;
            why = f"{'New ' if new_device else ''}{what} in {where} at {clock12(here.time)}, {travel} - impossible travel";
        } elif new_device and odd and big {
            stance = Stance.BLOCK;
            risk = 0.9;
            why = f"New untrusted {what} at {clock12(here.time)} trying {rs(here.amount)}";
        } elif new_device {
            stance = Stance.STEP_UP;
            risk = 0.6;
            why = f"New untrusted device: {what} in {where}";
        } elif odd or away {
            stance = Stance.STEP_UP;
            risk = 0.4;
            why = f"Own {what}, but " + (f"at {clock12(here.time)} (odd hour)" if odd else f"away from home in {where}");
        } else {
            stance = Stance.ALLOW;
            risk = 0.05;
            why = f"Own {what}, usual place ({where}), normal hour";
        }
        put_proposal(here, Proposal(
            agent=AgentName.PLACE_TIME, scope=Scope.REQUEST, stance=stance,
            confidence=confidence_for(stance, risk),
            reason=why, ms=ms_since(t0), source="code"
        ));
    }
}
