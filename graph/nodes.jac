"""Graph nodes — names and fields FIXED by the shared plan (section 4).
TEMPORARY COPY written by Person B (branch b-ai) so B's agents can run and be tested.
Person A owns this file: A may use it as the start or replace it (keep the same names/fields)."""

node Bank {
    has name: str, short: str;
}

node Citizen {
    has id: str, name: str, age: int = 0, city: str = "", language: str = "en",
        is_elder: bool = False, x: float = 0.0, y: float = 0.0;
}

node Device {
    has id: str, kind: str = "", first_seen: str = "", trusted: bool = False;
}

node Place {
    has name: str, x: float = 0.0, y: float = 0.0;
}

node Habit {
    has action: str, typical_amount: float = 0.0, hour_from: int = 0, hour_to: int = 23, count: int = 0;
}

# kind: PERSONAL | SHOP | BILLER | HOSPITAL | MULE_SUSPECT | ATM_CASHOUT
node Account {
    has id: str, bank: str = "", owner_name: str = "", opened_days_ago: int = 0, kind: str = "PERSONAL",
        frozen: bool = False, balance: float = 0.0, x: float = 0.0, y: float = 0.0;
}

# action: BILL_PAY | TRANSFER | BREAK_FD | LOGIN ; status: DRAFT | CHECKING | ALLOWED | STEP_UP | HELD | BLOCKED
node Request {
    has id: str, action: str = "TRANSFER", amount: float = 0.0, time: str = "", reference_text: str = "",
        status: str = "DRAFT", language: str = "en", telemetry: dict = {};
}

node PressureReading {
    has time: str = "", value: int = 0, top_reasons: list[str] = [];
}

node Proposal {
    has agent: str, scope: str = "REQUEST", stance: str = "WATCH", confidence: float = 0.0,
        reason: str = "", ms: int = 0, source: str = "code";
}

node Ruling {
    has decision: str, why: str = "", rule: str = "", ms: int = 0, deadlock: bool = False,
        assurance: str = "LOW", locked: bool = False;
}

# jev_reading: COACHED | NOT_COACHED | UNSURE | ""
node ScamCheck {
    has question: str, answer: str = "", jev_reading: str = "", language: str = "en";
}

node ScamPattern {
    has name: str, features: list[str] = [], phrases: list[str] = [], learned_from: str = "", times_matched: int = 0;
}

# kind: ACCOUNT_FLAGGED | FREEZE_REQUEST | SESSION_REVOKED ; status: OPEN | AGREED | OBJECTED | DONE
node Signal {
    has kind: str, subject_account: str = "", from_bank: str = "", to_bank: str = "", time: str = "", status: str = "OPEN";
}

# kind: GUARDIAN | ANALYST ; status: OPEN | ANSWERED
node Alert {
    has id: str, kind: str = "GUARDIAN", language: str = "en", title: str = "", lines: list[str] = [],
        options: list = [], status: str = "OPEN", answer: str = "";
}

node Guardian {
    has id: str, name: str = "", relation: str = "", language: str = "en";
}

node Analyst {
    has id: str, name: str = "", language: str = "en";
}
