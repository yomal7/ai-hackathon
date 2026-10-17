"""Graph edges — names FIXED by the shared plan (section 4).
Endpoint types (Src --> Tgt) let the type checker know what a traversal returns.
TEMPORARY COPY written by Person B (branch b-ai). Person A owns this file."""

import from graph.nodes { Bank, Citizen, Device, Place, Habit, Account, Request, Ruling, PressureReading, ScamCheck, ScamPattern, Guardian }

edge AccountAt: Account --> Bank {}
edge Owns: Citizen --> Account {}
edge Uses: Citizen --> Device {}
edge Usually: Citizen --> Place {}
edge Has: Citizen --> Habit {}
edge Made: Citizen --> Request {}
edge From: Request --> Device {}
edge At: Request --> Place {}
edge PaysTo: Request --> Account {}

# Money flow — Mule Ring and Money Tracer walk these.
edge Paid: Account --> Account {
    has amount: float = 0.0, time: str = "";
}

edge HasProposal {}     # Request | Account -> Proposal
edge Decided: Request --> Ruling {}
edge Read: Request --> PressureReading {}
edge Checked: Request --> ScamCheck {}
edge Matched: Request --> ScamPattern {}
edge LearnedFrom: ScamPattern --> Request {}
edge Emitted {}         # Ruling | Account -> Signal
edge ProtectedBy: Citizen --> Guardian {}
edge Raised {}          # Request | Signal -> Alert
