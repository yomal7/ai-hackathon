"""Test fixture (no tests here): the S3 money story, built fresh with unique ids.
Fictional people, banks and money. Used by money_tracer_tests and network_tests."""

import uuid;
import time;
import re;
import from graph.nodes { Bank, Citizen, Account, Request, ScamCheck, Guardian, ScamPattern }
import from graph.edges { AccountAt, Owns, Made, PaysTo, Paid, Checked, ProtectedBy, LearnedFrom }

obj Story {
    has ids: dict[str, str];      # short key ("CDB-40213") -> real id ("CDB-40213-ab12cd")
    has request: Request;         # Seeya's blocked S3 request
}

glob MARK: str = "TST";       # every test id contains this, so old test stories can be removed
glob MAX_AGE_S: int = 600;    # only stories older than this are removed (tests may run in parallel)

"""A fresh marker: TST<unix seconds>x<random>, e.g. TST1760700000xa1b2."""
def new_mark() -> str {
    return f"{MARK}{int(time.time())}x{uuid.uuid4().hex[:4]}";
}

"""True for an OLD test node (marker older than MAX_AGE_S, or an old marker without a time)."""
def _old_mark(text: str) -> bool {
    if MARK not in text { return False; }
    m = re.search(MARK + "(\d{9,})x", text);
    return m is None or time.time() - int(m.group(1)) > MAX_AGE_S;
}

def _marked(n: any) -> bool {
    return _old_mark(str(getattr(n, "id", ""))) or _old_mark(str(getattr(n, "name", "")));
}

"""Disconnect old test stories from root (Jac keeps the graph between runs; this keeps tests fast)."""
def forget_test_graph() -> None {
    for n in [root -->] {
        if isinstance(n, ScamPattern) {
            for r in [n ->:LearnedFrom:->] {
                if _marked(r) { for e in [edge n ->:LearnedFrom:-> r] { del e; } }
            }
            if _old_mark(n.learned_from) and not [n ->:LearnedFrom:->] {
                for e in [edge root --> n] { del e; }
            }
        } elif _marked(n) {
            for e in [edge root --> n] { del e; }
        }
    }
}

"""Per-story banks, so one story can be removed by cutting its links to root."""
def _banks(sfx: str) -> dict[str, Bank] {
    out: dict[str, Bank] = {};
    for (short, name) in [("LDB", "Lanka Demo Bank"), ("CDB", "Ceylon Demo Bank"), ("IDB", "Island Demo Bank")] {
        b = Bank(name=name + " " + sfx, short=short);
        root ++> b;
        out[short] = b;
    }
    return out;
}

def _acc(ids: dict[str, str], banks: dict[str, Bank], key: str, sfx: str, bank: str, owner: str, kind: str, days: int, balance: float) -> Account {
    a = Account(id=key + "-" + sfx, bank=bank, owner_name=owner, opened_days_ago=days, kind=kind, balance=balance);
    a +>:AccountAt():+> banks[bank];
    ids[key] = a.id;
    return a;
}

def _pay(a: Account, b: Account, amount: float, at: str) -> None {
    a +>:Paid(amount=amount, time=at):+> b;
}

"""Build the story with fresh unique ids."""
def build_story() -> Story {
    forget_test_graph();
    sfx = new_mark();
    ids: dict[str, str] = {};
    banks = _banks(sfx);
    mallika = _acc(ids, banks, "LDB-10001", sfx, "LDB", "Mallika", "PERSONAL", 7000, 1500000);
    rasheed = _acc(ids, banks, "IDB-20002", sfx, "IDB", "Rasheed", "PERSONAL", 6000, 900000);
    mule = _acc(ids, banks, "LDB-77821", sfx, "LDB", "N. Kumara", "MULE_SUSPECT", 9, 0);
    sits = _acc(ids, banks, "CDB-40213", sfx, "CDB", "S. Bandara", "PERSONAL", 12, 650000);
    hop2 = _acc(ids, banks, "IDB-55001", sfx, "IDB", "R. Silva", "PERSONAL", 20, 0);
    atm = _acc(ids, banks, "IDB-99001", sfx, "IDB", "ATM cash-out", "ATM_CASHOUT", 400, 0);
    shop = _acc(ids, banks, "CDB-11502", sfx, "CDB", "Perera Hardware", "SHOP", 4200, 1250000);
    seeya_acc = _acc(ids, banks, "LDB-10777", sfx, "LDB", "Siriwardena", "PERSONAL", 12000, 4200000);

    _pay(mallika, mule, 650000, "10:05");         # victim 1 (missed)
    _pay(rasheed, mule, 425000, "11:40");         # victim 2 (missed)
    _pay(mule, sits, 650000, "10:20");            # Mallika's money still sits here
    _pay(mule, hop2, 380000, "11:52");
    _pay(hop2, atm, 380000, "12:10");             # Rasheed's money: cashed out
    _pay(mule, shop, 45000, "12:30");             # mule buys goods at a real shop
    for i in range(12) {                          # the shop's normal customers
        c = _acc(ids, banks, f"CDB-6{i:04d}", sfx, "CDB", f"Customer {i}", "PERSONAL", 3000, 50000);
        _pay(c, shop, 2500 + i * 100, f"0{8 + i % 2}:{10 + i}");
    }

    seeya = Citizen(id="CIT-SEEYA-" + sfx, name="Siriwardena", age=74, city="Kandy", language="si", is_elder=True);
    root ++> seeya;
    seeya +>:Owns():+> seeya_acc;
    seeya +>:ProtectedBy():+> Guardian(id="G-DILSHAN-" + sfx, name="Dilshan", relation="son", language="si");
    req = Request(id="REQ-S3-" + sfx, action="BREAK_FD", amount=4200000, reference_text="ආරක්ෂිත ගිණුම",
                  status="BLOCKED", language="si", telemetry={"on_call": True, "pasted_account": True});
    seeya +>:Made():+> req;
    req +>:PaysTo():+> mule;
    for (q, a, r) in [("Q1", "ඔව්", "COACHED"), ("Q2", "ඔව්, ඔහු සීඅයිඩී කියලා කිව්වා", "COACHED"), ("Q3", "ඔව්", "COACHED")] {
        req +>:Checked():+> ScamCheck(question=q, answer=a, jev_reading=r, language="si");
    }
    return Story(ids=ids, request=req);
}
