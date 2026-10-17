"""Rakshaka - entry point (A).

Imports every module so `jac start main.jac` serves the whole app.
Simulation only: fictional banks, people, accounts and money.
"""
import os;
import dotenv;  # plain import on purpose: `import from X { f }` in main.jac exposes f as a REST endpoint

# Graph + seed (A)
import graph.nodes;
import graph.edges;
import graph.views;
import seed.banks;
import seed.people;
import seed.money;
import seed.scenarios;

# Agents (A, B)
import agents.phone.coercion_sentinel;
import agents.council.place_time;
import agents.council.routine;
import agents.council.mule_ring;
import agents.council.pattern;
import agents.council.advocate;
import agents.council.arbiter;
import agents.council.scam_breaker;
import agents.network.pattern_learner;
import agents.network.money_tracer;
import agents.network.bank_liaison;
import agents.network.network;

# Rules (A, B)
import rules.arbiter_rules;
import rules.network_rules;

# AI functions (B)
import ai.types;
import ai.jev;
import ai.llm_calls;
import ai.lang;

# Public API (C). Only `import from X { names }` registers REST endpoints - C tells A the names to add.
import from walkers.api {
    ping, get_war_room, get_phone, get_guardian, get_story, start_request, telemetry_update, submit_request,
    scam_answer, guardian_answer, analyst_answer, set_language, run_scenario, reset_demo
}

# Keys come only from the environment; .env is loaded if present (never committed).
with entry {
    dotenv.load_dotenv(os.path.join(os.getcwd(), ".env"));
}

# Client UI (C builds the screens)
cl {
    import from .frontend.app { App }

    def:pub app -> JsxElement {
        return <App/>;
    }
}
