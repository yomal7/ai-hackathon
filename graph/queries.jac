# Graph helpers: find nodes by id, demo state, clear the graph, create a Request (A)
# Root holds: Bank, Citizen, Place, Analyst, DemoState. Everything else hangs off them.
import time;
import from datetime { datetime }
import from graph.nodes {
    RNode, Bank, Citizen, Device, Place, Account, Request, Guardian, Analyst, Alert, DemoState,
    Action, Lang, RequestStatus
}
import from graph.edges { AccountAt, Uses, Usually, Made, From, At, PaysTo, ProtectedBy, Raised }

"""The one DemoState node (created if missing)."""
def demo_state() -> DemoState {
    found = [root -->[?:DemoState]];
    if found {
        return found[0];
    }
    st = DemoState();
    root ++> st;
    return st;
}

def all_banks() -> list[Bank] {
    return [root -->[?:Bank]];
}

def find_bank(short: str) -> Bank | None {
    for b in all_banks() {
        if b.short == short {
            return b;
        }
    }
    return None;
}

def all_citizens() -> list[Citizen] {
    return [root -->[?:Citizen]];
}

def find_citizen(citizen_id: str) -> Citizen | None {
    for c in all_citizens() {
        if c.id == citizen_id {
            return c;
        }
    }
    return None;
}

def find_place(name: str) -> Place | None {
    for p in [root -->[?:Place]] {
        if p.name == name {
            return p;
        }
    }
    return None;
}

"""Every account at every bank."""
def all_accounts() -> list[Account] {
    accounts: list[Account] = [];
    for b in all_banks() {
        accounts.extend([b <-:AccountAt:<-]);
    }
    return accounts;
}

def find_account(account_id: str) -> Account | None {
    for a in all_accounts() {
        if a.id == account_id {
            return a;
        }
    }
    return None;
}

"""Every request, oldest first."""
def all_requests() -> list[Request] {
    reqs: list[Request] = [];
    for c in all_citizens() {
        reqs.extend([c ->:Made:->]);
    }
    return sorted(reqs, key=lambda r: Request: r.id);
}

def find_request(request_id: str) -> Request | None {
    for r in all_requests() {
        if r.id == request_id {
            return r;
        }
    }
    return None;
}

def citizen_of(req: Request) -> Citizen | None {
    found = [req <-:Made:<-];
    return found[0] if found else None;
}

def payee_of(req: Request) -> Account | None {
    found = [req ->:PaysTo:->];
    return found[0] if found else None;
}

def device_of(req: Request) -> Device | None {
    found = [req ->:From:->];
    return found[0] if found else None;
}

def place_of(req: Request) -> Place | None {
    found = [req ->:At:->];
    return found[0] if found else None;
}

def all_guardians() -> list[Guardian] {
    gs: list[Guardian] = [];
    for c in all_citizens() {
        gs.extend([c ->:ProtectedBy:->]);
    }
    return gs;
}

def find_guardian(guardian_id: str) -> Guardian | None {
    for g in all_guardians() {
        if g.id == guardian_id {
            return g;
        }
    }
    return None;
}

def guardian_of(c: Citizen) -> Guardian | None {
    found = [c ->:ProtectedBy:->];
    return found[0] if found else None;
}

def find_analyst() -> Analyst | None {
    found = [root -->[?:Analyst]];
    return found[0] if found else None;
}

"""Every alert raised from a request or a signal."""
def all_alerts() -> list[Alert] {
    seen: dict[str, Alert] = {};
    for n in all_nodes() {
        for a in [n ->:Raised:->] {
            seen[a.id] = a;
        }
    }
    return sorted(seen.values(), key=lambda a: Alert: a.id);
}

def find_alert(alert_id: str) -> Alert | None {
    for a in all_alerts() {
        if a.id == alert_id {
            return a;
        }
    }
    return None;
}

"""Every node reachable from root (both edge directions), root itself excluded."""
def all_nodes() -> list[RNode] {
    root_id = jid(root);
    seen: dict[str, RNode] = {};
    queue: list[RNode] = [root -->[?:RNode]];
    while queue {
        n = queue.pop();
        key = jid(n);
        if key in seen {
            continue;
        }
        seen[key] = n;
        for m in [n -->[?:RNode]] + [n <--[?:RNode]] {
            if jid(m) != root_id and jid(m) not in seen {
                queue.append(m);
            }
        }
    }
    return list(seen.values());
}

"""Delete every demo node (edges go with them)."""
def clear_demo() {
    for n in all_nodes() {
        del n;
    }
}

"""Minutes since midnight for a demo clock "HH:MM"."""
def hhmm_to_min(t: str) -> int {
    parts = t.split(":");
    return int(parts[0]) * 60 + int(parts[1]);
}

"""Wall clock now as "HH:MM:SS" (timeline lines)."""
def now_hms() -> str {
    return datetime.now().strftime("%H:%M:%S");
}

"""Wall clock now in seconds (ms and detection times)."""
def now_s() -> float {
    return time.time();
}

"""Add one line to the War Room timeline."""
def add_timeline(agent: str, text: str) {
    st = demo_state();
    st.timeline = st.timeline + [{"time": now_hms(), "agent": agent, "text": text}];
}

"""Create a DRAFT Request with all its edges, and make it the current request.
Defaults: the citizen's own trusted device, usual place and language, time = now."""
def create_request(
    citizen_id: str,
    action: str,
    amount: int,
    payee_id: str = "",
    reference: str = "",
    at_time: str = "",
    device: Device | None = None,
    place_name: str = "",
    telemetry: dict[str, any] = {}
) -> Request | None {
    c = find_citizen(citizen_id);
    if c is None {
        return None;
    }
    st = demo_state();
    req = Request(
        id=f"REQ-{st.next_request:04d}",
        action=Action(action),
        amount=amount,
        time=at_time if at_time else datetime.now().strftime("%H:%M"),
        reference_text=reference,
        language=c.language,
        telemetry=dict(telemetry)
    );
    st.next_request += 1;
    st.current_request = req.id;
    c +>:Made:+> req;
    dev = device;
    if dev is None {
        own = [d for d in [c ->:Uses:->] if d.trusted];
        dev = own[0] if own else None;
    }
    if dev is not None {
        req +>:From:+> dev;
    }
    place = find_place(place_name) if place_name else None;
    if place is None {
        usual = [c ->:Usually:->];
        place = usual[0] if usual else None;
    }
    if place is not None {
        req +>:At:+> place;
    }
    payee = find_account(payee_id) if payee_id else None;
    if payee is not None {
        req +>:PaysTo:+> payee;
    }
    return req;
}

"""Change a person's language (citizen, guardian or analyst). Only "si" | "ta" | "en". False if not found."""
def set_person_language(person_id: str, language: str) -> bool {
    if language not in ["si", "ta", "en"] {
        return False;
    }
    lang = Lang(language);
    c = find_citizen(person_id);
    if c is not None {
        c.language = lang;
        return True;
    }
    g = find_guardian(person_id);
    if g is not None {
        g.language = lang;
        return True;
    }
    an = find_analyst();
    if an is not None and an.id == person_id {
        an.language = lang;
        return True;
    }
    return False;
}
