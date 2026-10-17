"""Pattern Learner (agent 9, owner: Person B) — NETWORK IMMUNITY.
Turns one confirmed scam into a ScamPattern every bank's Pattern Agent can match,
with phrases in Sinhala, Tamil and English so the next victim is caught in any language."""

import from graph.nodes { Request, ScamPattern }
import from graph.edges { LearnedFrom }
import from ai.llm_calls { learn_pattern }
import from agents.council.scam_breaker { checks_of, situation_of }
import from agents.network.net_common { all_patterns, add_line }

"""{pattern name: phrases} for every learned pattern — feed this to jev_pattern(state["pattern_phrases"])."""
def pattern_catalog() -> dict[str, list[str]] {
    return {p.name: list(p.phrases) for p in all_patterns()};
}

walker PatternLearner {
    has pattern_name: str = "";          # result, for the caller

    can learn with Request entry {
        answers = [c.answer for c in checks_of(here) if c.answer];
        summary = situation_of(here) + " Telemetry: " + str(here.telemetry);
        draft = learn_pattern(summary, answers);
        same = [p for p in all_patterns() if p.name == draft.name];
        if same {
            pat = same[0];                # already known: add the new phrases, link this case too
            for ph in draft.phrases {
                if ph not in pat.phrases { pat.phrases.append(ph); }
            }
        } else {
            pat = ScamPattern(name=draft.name, features=draft.features, phrases=draft.phrases,
                              learned_from=here.id, times_matched=0);
            root ++> pat;
        }
        pat +>:LearnedFrom():+> here;
        self.pattern_name = pat.name;
        add_line("PATTERN_LEARNER", f"Learned '{pat.name}' from {here.id} ({len(pat.phrases)} phrases in si/ta/en). All 3 banks now know it.");
    }
}
