# Graph nodes - every node from section 4 with the FIXED names and fields (A)
# Enums are `str` enums: Stance.HOLD == "HOLD" is True, and they go out as plain strings in JSON.
# Extra fields added by A (all have defaults) are marked "# extra".

enum Lang: str { SI = "si", TA = "ta", EN = "en" }

enum Action: str { BILL_PAY = "BILL_PAY", TRANSFER = "TRANSFER", BREAK_FD = "BREAK_FD", LOGIN = "LOGIN" }

enum RequestStatus: str {
    DRAFT = "DRAFT", CHECKING = "CHECKING", ALLOWED = "ALLOWED",
    STEP_UP = "STEP_UP", HELD = "HELD", BLOCKED = "BLOCKED"
}

enum AccountKind: str {
    PERSONAL = "PERSONAL", SHOP = "SHOP", BILLER = "BILLER", HOSPITAL = "HOSPITAL",
    MULE_SUSPECT = "MULE_SUSPECT", ATM_CASHOUT = "ATM_CASHOUT"
}

enum AgentName: str {
    COERCION = "COERCION", PLACE_TIME = "PLACE_TIME", ROUTINE = "ROUTINE", MULE_RING = "MULE_RING",
    PATTERN = "PATTERN", ADVOCATE = "ADVOCATE", SCAM_BREAKER = "SCAM_BREAKER",
    LIAISON_LDB = "LIAISON_LDB", LIAISON_CDB = "LIAISON_CDB", LIAISON_IDB = "LIAISON_IDB",
    MONEY_TRACER = "MONEY_TRACER"
}

enum Scope: str { DEVICE = "DEVICE", REQUEST = "REQUEST", NETWORK = "NETWORK" }

enum Stance: str {
    ALLOW = "ALLOW", STEP_UP = "STEP_UP", HOLD = "HOLD", BLOCK = "BLOCK",
    ASK_GUARDIAN = "ASK_GUARDIAN", FREEZE = "FREEZE", WATCH = "WATCH"
}

enum Decision: str {
    ALLOW = "ALLOW", STEP_UP = "STEP_UP", HOLD = "HOLD", BLOCK = "BLOCK",
    ASK_GUARDIAN = "ASK_GUARDIAN", ASK_ANALYST = "ASK_ANALYST"
}

enum Assurance: str { LOW = "LOW", MEDIUM = "MEDIUM", HIGH = "HIGH" }

enum JevReading: str { COACHED = "COACHED", NOT_COACHED = "NOT_COACHED", UNSURE = "UNSURE", NONE = "" }

enum SignalKind: str { ACCOUNT_FLAGGED = "ACCOUNT_FLAGGED", FREEZE_REQUEST = "FREEZE_REQUEST", SESSION_REVOKED = "SESSION_REVOKED" }

enum SignalStatus: str { OPEN = "OPEN", AGREED = "AGREED", OBJECTED = "OBJECTED", DONE = "DONE" }

enum AlertKind: str { GUARDIAN = "GUARDIAN", ANALYST = "ANALYST" }

enum AlertStatus: str { OPEN = "OPEN", ANSWERED = "ANSWERED" }

"""Base of every Rakshaka node, so one edge type can start from several node types."""
node RNode {}

node Bank(RNode) {
    has name: str;
    has short: str;                       # LDB | CDB | IDB
}

node Citizen(RNode) {
    has id: str;
    has name: str;
    has age: int;
    has city: str;
    has language: Lang = Lang.EN;
    has is_elder: bool = False;
    has x: int = 0;                       # War Room canvas position (about 1000 x 600)
    has y: int = 0;
}

node Device(RNode) {
    has id: str;
    has kind: str;                        # e.g. "Galaxy A12 (Android)", "Linux laptop"
    has first_seen: str;                  # e.g. "2023-02"
    has trusted: bool = False;
}

"""A town. x / y are map positions in km (for impossible-travel checks), not canvas pixels."""
node Place(RNode) {
    has name: str;
    has x: int = 0;
    has y: int = 0;
}

node Habit(RNode) {
    has action: str;                      # BILL_PAY | TRANSFER | BREAK_FD | WITHDRAW
    has typical_amount: int;
    has hour_from: int;
    has hour_to: int;
    has count: int;                       # how many times it happened
    has label: str = "";                  # extra: e.g. "Electricity bill"
}

node Account(RNode) {
    has id: str;                          # e.g. "LDB-77821"
    has bank: str;                        # bank short: LDB | CDB | IDB
    has owner_name: str;
    has opened_days_ago: int;
    has kind: AccountKind = AccountKind.PERSONAL;
    has frozen: bool = False;
    has balance: int = 0;
    has x: int = 0;
    has y: int = 0;
    has is_fd: bool = False;              # extra: fixed deposit
    has confirmed_mule: bool = False;     # extra: set by a guardian Reject or a learned pattern (rule R1)
}

node Request(RNode) {
    has id: str;                          # e.g. "REQ-0003"
    has action: Action;
    has amount: int;
    has time: str;                        # demo clock "HH:MM"
    has reference_text: str = "";
    has status: RequestStatus = RequestStatus.DRAFT;
    has language: Lang = Lang.EN;
    has telemetry: dict[str, any] = {};   # on_call, remote_app, pasted_account, hesitation_ms, backtracks, typing_change, new_payee
    has walk_path: list[str] = [];        # extra: Mule Ring walk, node ids in visit order
    has first_signal_at: float = 0.0;     # extra: wall time of the first telemetry signal (detection time)
    has confirmed_scam: bool = False;     # extra: set by a guardian Reject
}

node PressureReading(RNode) {
    has time: str;
    has value: int;                       # 0..100
    has top_reasons: list[str] = [];
}

node Proposal(RNode) {
    has agent: AgentName;
    has scope: Scope;
    has stance: Stance;
    has confidence: float;                # 0..1
    has reason: str;                      # short, English
    has ms: int = 0;
    has source: str = "code";             # "jev" | "llm" | "code" | "fallback"
}

node Ruling(RNode) {
    has decision: Decision;
    has why: str;
    has rule: str;                        # "R1".."R6"
    has ms: int = 0;
    has deadlock: bool = False;
    has assurance: Assurance = Assurance.LOW;
    has locked: bool = False;
}

node ScamCheck(RNode) {
    has question: str;
    has answer: str = "";
    has jev_reading: JevReading = JevReading.NONE;
    has language: Lang = Lang.EN;
}

node ScamPattern(RNode) {
    has name: str;
    has features: list[str] = [];
    has phrases: dict[str, list[str]] = {};   # {"si": [...], "ta": [...], "en": [...]}
    has learned_from: str = "";               # request id
    has times_matched: int = 0;
}

node Signal(RNode) {
    has kind: SignalKind;
    has subject_account: str;                 # account id
    has from_bank: str;
    has to_bank: str;
    has time: str;
    has status: SignalStatus = SignalStatus.OPEN;
}

node Alert(RNode) {
    has id: str;
    has kind: AlertKind;
    has language: Lang;
    has title: str;
    has lines: list[str] = [];
    has options: list[str] = [];
    has status: AlertStatus = AlertStatus.OPEN;
    has answer: str = "";
}

node Guardian(RNode) {
    has id: str;
    has name: str;
    has relation: str;                        # son | daughter | ...
    has language: Lang = Lang.EN;
}

node Analyst(RNode) {
    has id: str;
    has name: str;
    has language: Lang = Lang.EN;
}

"""extra: one per graph. Demo counters, current request and timeline. Cleared by ResetDemo."""
node DemoState(RNode) {
    has next_request: int = 1;
    has next_alert: int = 1;
    has current_request: str = "";
    has checked: int = 0;
    has blocked: int = 0;
    has held: int = 0;
    has protected_rs: int = 0;
    has recovered_rs: int = 0;                # B updates it
    has human_needed: int = 0;
    has detect_times: list[dict[str, any]] = [];   # [{"name", "seconds"}]; seconds None = missed
    has timeline: list[dict[str, any]] = [];       # [{"time", "agent", "text"}]
}
