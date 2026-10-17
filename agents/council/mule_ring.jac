# Bank Council (4) - Mule Ring: who else paid this account today, and where did the money go? (A)
# 2-hop walk: Request->PaysTo->Account <-Paid<- other citizens' accounts, and Account->Paid->next accounts.
# The visit order is saved on the Request (walk_path) so the War Room can animate it.
import time;
import from graph.nodes { Citizen, Account, Request, Proposal, AgentName, Scope, Stance, AccountKind }
import from graph.edges { Owns, Paid, Made, PaysTo }
import from graph.queries { hhmm_to_min }
import from ai.jev { jev_mule_scores }
import from agents.council.council_common { ms_since, score, put_proposal, stance_for, confidence_for }

glob WINDOW_MIN: int = 180;     # "today, in the last hours"

"""Spawned on a Request by RunCouncil. Writes one MULE_RING Proposal and the walk path."""
walker MuleRingAgent {
    has path: list[str] = [];

    can check with Request entry {
        t0 = time.perf_counter();
        owners = [here <-:Made:<-];
        payees = [here ->:PaysTo:->];
        if not owners or not payees {
            put_proposal(here, Proposal(agent=AgentName.MULE_RING, scope=Scope.REQUEST, stance=Stance.ALLOW,
                confidence=0.9, reason="No payee account to check", ms=ms_since(t0), source="code"));
            disengage;
        }
        me = owners[0];
        payee = payees[0];
        now = hhmm_to_min(here.time);
        self.path = [me.id, payee.id];

        # Hop 1 (backwards): today's money into the payee from OTHER citizens
        elders: list[str] = [];
        senders: list[str] = [];
        first_in = now;
        in_times: list[int] = [];
        flagged_sender = False;
        for acc in [payee <-:Paid:<-] {
            holders = [acc <-:Owns:<-];
            if acc.id in senders or (holders and holders[0].id == me.id) {
                continue;
            }
            times = [hhmm_to_min(e.time) for e in [edge acc ->:Paid:-> payee] if e.days_ago == 0];
            times = [t for t in times if 0 <= now - t <= WINDOW_MIN];
            if not times {
                continue;
            }
            flagged_sender = flagged_sender or acc.confirmed_mule;
            senders.append(acc.id);
            in_times.extend(times);
            first_in = min([first_in] + times);
            self.path.append(acc.id);
            if holders {
                self.path.append(holders[0].id);
                if holders[0].is_elder and holders[0].id not in elders {
                    elders.append(holders[0].id);
                }
            }
        }

        # Hop 1 (forwards): where the payee sent money on, and how fast
        moved_min: int | None = None;
        for e in [edge payee ->:Paid:->] {
            t = hhmm_to_min(e.time);
            if e.days_ago != 0 {
                continue;
            }
            for t_in in in_times {
                if t >= t_in and (moved_min is None or t - t_in < moved_min) {
                    moved_min = t - t_in;
                }
            }
        }
        for nxt in [payee ->:Paid:->] {
            if nxt.id not in self.path {
                self.path.append(nxt.id);
            }
        }
        here.walk_path = list(self.path);

        # Evidence in code
        young = payee.opened_days_ago < 30;
        old_business = payee.opened_days_ago >= 365 and payee.kind in [AccountKind.SHOP, AccountKind.BILLER, AccountKind.HOSPITAL];
        if payee.confirmed_mule or payee.frozen {
            code_risk = 0.99;
        } elif len(elders) >= 2 and young {
            code_risk = 0.93;
        } elif len(elders) == 1 and young {
            code_risk = 0.6;
        } elif young and moved_min is not None and moved_min <= 30 {
            code_risk = 0.5;
        } elif young {
            code_risk = 0.2;
        } else {
            code_risk = 0.05;
        }
        # System 1 (Jev) mule score for the payee; the higher of code and Jev wins, old real businesses are capped
        jev = jev_mule_scores([{
            "id": payee.id, "kind": str(payee.kind), "opened_days_ago": payee.opened_days_ago,
            "inflow_count": len(senders), "distinct_senders": len(set(senders)),
            "minutes_to_move_on": moved_min, "from_flagged": flagged_sender
        }]);
        risk = max(code_risk, float(jev.get(payee.id, 0.0) as float));
        if old_business and not payee.confirmed_mule {
            risk = min(risk, 0.3);
        }
        risk = score(risk);

        stance: Stance = Stance.ALLOW;
        if payee.confirmed_mule or payee.frozen {
            stance = Stance.BLOCK;
            why = f"{payee.id} is a {'frozen' if payee.frozen else 'confirmed mule'} account";
        } else {
            stance = stance_for(risk);
            parts = [f"{len(elders)} other elder{'s' if len(elders) != 1 else ''} paid this {payee.opened_days_ago}-day-old account in the last {now - first_in} min"] if elders else ["No other elders paid this account today" + (f" ({payee.opened_days_ago} days old)" if young else "")];
            if moved_min is not None {
                parts.append(f"money moved on within {moved_min} min");
            }
            if old_business {
                parts.append(f"established {str(payee.kind).lower()} ({payee.opened_days_ago // 365} years)");
            }
            why = "; ".join(parts);
        }
        put_proposal(here, Proposal(
            agent=AgentName.MULE_RING, scope=Scope.REQUEST, stance=stance,
            confidence=confidence_for(stance, risk) if stance != Stance.BLOCK else risk,
            reason=why, ms=ms_since(t0), source="code"
        ));
    }
}
