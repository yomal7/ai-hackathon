"""Shared helpers for the Fraud Network (owner: Person B):
graph search, time parsing, and the network's memory (timeline, money walk, recovered Rs)."""

import from datetime { datetime }
import from ai.fallback { to_float }
import from graph.nodes { Request, Account, Signal, Alert, ScamPattern }

# ---------- graph search (both edge directions, so it works however the seed is wired) ----------

"""Every node reachable from root, following edges both ways."""
def all_nodes() -> list {
    seen: set[int] = set();
    out: list = [];
    todo: list = [root];
    while todo {
        n = todo.pop();
        if id(n) in seen { continue; }
        seen.add(id(n));
        out.append(n);
        todo.extend([n -->]);
        todo.extend([n <--]);
    }
    return out;
}

def find_request(request_id: str) -> Request | None {
    found = [n for n in all_nodes() if isinstance(n, Request) and n.id == request_id];
    return found[0] if found else None;
}

def find_account(account_id: str) -> Account | None {
    found = [n for n in all_nodes() if isinstance(n, Account) and n.id == account_id];
    return found[0] if found else None;
}

def find_alert(alert_id: str) -> Alert | None {
    found = [n for n in all_nodes() if isinstance(n, Alert) and n.id == alert_id];
    return found[0] if found else None;
}

def all_signals() -> list[Signal] {
    return [n for n in all_nodes() if isinstance(n, Signal)];
}

def all_patterns() -> list[ScamPattern] {
    return [n for n in all_nodes() if isinstance(n, ScamPattern)];
}

"""Short bank code: "CDB" from Account.bank ("CDB" or "Ceylon Demo Bank") or from the id prefix "CDB-40213"."""
def bank_short(acc: Account) -> str {
    b = acc.bank.strip();
    if 0 < len(b) and len(b) <= 4 { return b.upper(); }
    if "-" in acc.id { return acc.id.split("-")[0].upper(); }
    return "".join([w[0] for w in b.split() if w]).upper();
}

"""Minutes since midnight from "10:20", "10:20:05" or an ISO time; None if unknown."""
def to_minutes(t: str) -> int | None {
    s = (t or "").strip();
    if "T" in s { s = s.split("T")[1]; }
    parts = s.split(":");
    if len(parts) < 2 { return None; }
    try { return int(parts[0]) * 60 + int(parts[1][:2]); } except ValueError { return None; }
}

def now_hms() -> str {
    return datetime.now().strftime("%H:%M:%S");
}

# ---------- network memory (cleared by reset_network) ----------

glob TIMELINE: list[dict] = [];          # [{"time", "agent", "text"}]
glob WALK: dict = {};                    # {"kind": "MONEY_TRACE", "path": [...], "step": int, "hops": [...]}
glob HELD: dict[str, dict] = {};         # account id -> {"amount": float, "victim": str}
glob TOTALS: dict[str, float] = {"recovered_rs": 0.0};

"""Victims' money still in this account (from the trace; else its balance)."""
def held_amount(acc: Account) -> float {
    h = HELD.get(acc.id);
    return to_float(h.get("amount"), acc.balance) if h else acc.balance;
}

"""Whose money it is ("" if unknown)."""
def held_victim(acc: Account) -> str {
    h = HELD.get(acc.id);
    return str(h.get("victim", "")) if h else "";
}

def add_line(agent: str, text: str) -> None {
    TIMELINE.append({"time": now_hms(), "agent": agent, "text": text});
}

"""Clear the network memory (A's ResetDemo calls this)."""
def reset_network() -> None {
    TIMELINE.clear();
    WALK.clear();
    HELD.clear();
    TOTALS["recovered_rs"] = 0.0;
}
