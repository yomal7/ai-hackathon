# Bank Council (6) - Citizen Advocate: the counter-agent. Argues ALLOW to stop false lockouts of elders (A)
# Real needs: a hospital, a biller, a payee they paid before, or a guardian who already said yes.
import time;
import from graph.nodes { Citizen, Account, Request, Alert, Proposal, AgentName, Scope, Stance, AccountKind, AlertKind }
import from graph.edges { Owns, Paid, Made, PaysTo, Raised }
import from agents.council.council_common { ms_since, put_proposal }

"""How many times this citizen paid this account before."""
def times_paid(c: Citizen, payee: Account) -> int {
    n = 0;
    for a in [c ->:Owns:->] {
        n += len([e for e in [edge a ->:Paid:-> payee]]);
    }
    return n;
}

"""Spawned on a Request by RunCouncil. Writes one ADVOCATE Proposal."""
walker AdvocateAgent {
    can check with Request entry {
        t0 = time.perf_counter();
        owners = [here <-:Made:<-];
        payees = [here ->:PaysTo:->];
        approved = [a for a in [here ->:Raised:->] if a.kind == AlertKind.GUARDIAN and a.answer == "APPROVE"];
        stance: Stance = Stance.WATCH;
        conf: float = 0.6;
        why: str = "No hospital, biller or known payee - no reason to rush";
        if approved {
            stance = Stance.ALLOW;
            conf = 0.95;
            why = "The guardian already approved this payment";
        } elif not payees {
            stance = Stance.ALLOW;
            conf = 0.5;
            why = "No money leaves the account";
        } else {
            payee = payees[0];
            paid_before = times_paid(owners[0], payee) if owners else 0;
            if payee.kind == AccountKind.HOSPITAL {
                stance = Stance.ALLOW;
                conf = 0.85;
                why = f"Payee is {payee.owner_name}, a known hospital - medical bills can be urgent";
                if paid_before {
                    why += f" (paid {paid_before}× before)";
                }
            } elif payee.kind == AccountKind.BILLER {
                stance = Stance.ALLOW;
                conf = 0.9;
                why = f"Payee is {payee.owner_name}, a registered biller";
            } elif paid_before >= 1 {
                stance = Stance.ALLOW;
                conf = 0.8;
                why = f"Known payee {payee.owner_name} - paid {paid_before}× before";
            }
        }
        put_proposal(here, Proposal(
            agent=AgentName.ADVOCATE, scope=Scope.REQUEST, stance=stance, confidence=conf,
            reason=why, ms=ms_since(t0), source="code"
        ));
    }
}
