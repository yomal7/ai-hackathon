# Graph edges - every edge from section 4 with the FIXED names (A)
# Edges with several source types start from RNode (the base of every node).
import from graph.nodes {
    RNode, Bank, Citizen, Device, Place, Habit, Account, Request, PressureReading,
    Proposal, Ruling, ScamCheck, ScamPattern, Signal, Alert, Guardian
}

edge AccountAt: Account --> Bank {}
edge Owns: Citizen --> Account {}
edge Uses: Citizen --> Device {}
edge Usually: Citizen --> Place {}
edge Has: Citizen --> Habit {}
edge Made: Citizen --> Request {}
edge From: Request --> Device {}
edge At: Request --> Place {}
edge PaysTo: Request --> Account {}

"""Money flow. Mule Ring and Money Tracer walk these."""
edge Paid: Account --> Account {
    has amount: int = 0;
    has time: str = "";              # demo clock "HH:MM"
    has days_ago: int = 0;           # extra: 0 = today
}

edge HasProposal: RNode --> Proposal {}      # Request | Account -> Proposal
edge Decided: Request --> Ruling {}
edge Read: Request --> PressureReading {}
edge Checked: Request --> ScamCheck {}
edge Matched: Request --> ScamPattern {}
edge LearnedFrom: ScamPattern --> Request {}
edge Emitted: RNode --> Signal {}            # Ruling | Account -> Signal
edge ProtectedBy: Citizen --> Guardian {}
edge Raised: RNode --> Alert {}              # Request | Signal -> Alert
