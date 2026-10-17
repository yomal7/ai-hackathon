# Bank Council (5) - Pattern: does this request match a scam pattern the network has learned? (A)
# Reads the ScamPattern nodes (written by B's Pattern Learner) -> B's jev_pattern -> Matched edge.
import time;
import from graph.nodes { Request, ScamPattern, Proposal, AgentName, Scope, Stance }
import from graph.edges { Matched }
import from ai.jev { jev_pattern }
import from agents.council.council_common { ms_since, request_state, put_proposal }

"""Every learned scam pattern (the Pattern Learner hangs them on root)."""
def learned_patterns() -> list[ScamPattern] {
    return [root -->[?:ScamPattern]];
}

"""Spawned on a Request by RunCouncil. Writes one PATTERN Proposal."""
walker PatternAgent {
    has matched: str = "";

    can check with Request entry {
        t0 = time.perf_counter();
        patterns = learned_patterns();
        if not patterns {
            put_proposal(here, Proposal(agent=AgentName.PATTERN, scope=Scope.REQUEST, stance=Stance.ALLOW,
                confidence=0.3, reason="No scam patterns learned yet", ms=ms_since(t0), source="code"));
            disengage;
        }
        st = request_state(here);
        st["pattern_phrases"] = {p.name: list(p.phrases) for p in patterns};
        name = jev_pattern(st, [p.name for p in patterns]);
        hit = [p for p in patterns if p.name == name];
        if not hit {
            put_proposal(here, Proposal(agent=AgentName.PATTERN, scope=Scope.REQUEST, stance=Stance.ALLOW,
                confidence=0.3, reason=f"No match among {len(patterns)} learned pattern(s)",
                ms=ms_since(t0), source="code"));
            disengage;
        }
        pat = hit[0];
        if not [m for m in [here ->:Matched:->] if m.name == pat.name] {
            here +>:Matched:+> pat;
            pat.times_matched += 1;
        }
        self.matched = pat.name;
        put_proposal(here, Proposal(
            agent=AgentName.PATTERN, scope=Scope.REQUEST, stance=Stance.HOLD, confidence=0.95,
            reason=f"Matches learned pattern '{pat.name}' (learned from {pat.learned_from}, matched {pat.times_matched}×)",
            ms=ms_since(t0), source="jev"
        ));
    }
}
