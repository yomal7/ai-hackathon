# Rakshaka (රක්ෂක, "protector")

**A multi-agent system in Jac that protects elders from "safe account" phone scams.**

Built by Team Argon at AI Hackathon 2026 Sri Lanka (powered by Jaseci Labs, Department of Electrical Engineering, University of Moratuwa, 17 Oct 2026).

🎥 **Demo video:** https://youtu.be/QfWv8U6Wj0k

> **Simulation, fictional data.** Every bank, person, account and rupee in this project is made up. Nothing connects to a real bank.

---

## The problem

An elder gets a call: *"This is CID. Move your money to a safe account now, or you'll be arrested."*
They open **their own** banking app, on **their own** phone, and type **their own** OTP. Every check a bank runs today passes.

Banks ask *"Is this the real owner?"* Rakshaka asks *"Is this person acting freely?"*

## How it works

Three layers of agents share one Jac graph. Every agent reads it and writes its findings back.

| Layer | Agents | What they do |
|---|---|---|
| **Phone Shield** | Coercion Sentinel | Watches signals from the banking session (active call, pasted account number, new payee, hesitation, scam words) and builds a **pressure meter** (0–100) |
| **Bank Council** | Place & Time, Routine, Mule Ring, Pattern, Citizen Advocate, Scam-Breaker, Arbiter | Each specialist gives a stance and confidence. The **Advocate** argues *against* blocking so elders aren't locked out unfairly. The **Arbiter** decides using plain-code rules. |
| **Fraud Network** | Pattern Learner, Money Tracer, Bank Liaison (one per bank) | Learns new scam patterns, follows stolen money across banks, and proposes freezes |

Humans stay in the loop:

- 👨‍👦 **Guardian** (son or daughter) gets one tap: **Reject / Approve / Call now**
- 🗣️ **Scam-Breaker** talks to the elder calmly in **Sinhala, Tamil or English**
- 🏦 **Bank analyst** is the only one who can approve a cross-bank freeze. No agent can freeze an account on its own.

### Safety by design

- **Final decisions are plain code** (`rules/arbiter_rules.jac`, `rules/network_rules.jac`), not an LLM.
- **Two AI systems:**
  - **System 1 (Jev, TypeSafe System One)** gives fast typed risk answers with an 800 ms limit.
  - **System 2 (`by llm`)** writes questions, guardian cards, patterns and debriefs.
- **Every AI call has a code fallback** with the same return type, so the demo still works offline or without API keys.

## Demo scenarios

Run these from the War Room screen:

| # | Scenario | Expected outcome |
|---|---|---|
| S1 | Normal day: a small bill payment | **ALLOW** |
| S2 | Stolen password: login from an impossible location | **BLOCK** and session revoked |
| S3 | The scam call: breaking a large fixed deposit while coached on a call | **HOLD**, then Scam-Breaker talks to the elder and the guardian is alerted |
| S4 | Network immunity: a second elder targeted with the same script | Caught by the pattern learned from S3 |
| S5 | Hospital at 1 AM: an urgent, unusual but genuine payment | Advocate vs. risk agents **deadlock**, so the guardian decides |

## Screens

| Route | Screen |
|---|---|
| `/war-room` | Live council, graph view and fraud-network panels (default page) |
| `/phone` | The elder's banking app with the pressure meter |
| `/guardian` | The family member's alert card |
| `/telemetry` | Raw phone signals |
| `/story` | Step-by-step explanation of what happened |

## Run it locally

```bash
pip install jaseci
jac install                 # installs Python + npm dependencies from jac.toml
cp .env.example .env        # optional: add keys (it runs on code fallbacks without them)
jac start --dev main.jac
```

Then open the URL printed in the terminal and go to `/war-room`.

**Environment variables** (see `.env.example`):

| Variable | Purpose |
|---|---|
| `TYPESAFE_API_KEY` | Jev (System 1) |
| `LLM_MODEL`, `GEMINI_API_KEY` | `by llm` model (System 2), default `gemini/gemini-3.5-flash-lite` |
| `JEV_TIMEOUT_MS`, `LLM_TIMEOUT_MS` | Time limits before the code fallback takes over |

Never commit `.env`.

## Project structure

```
main.jac            entry point: imports agents, registers the REST walkers, serves the client app
graph/              nodes, edges, queries and views (the shared blackboard)
agents/phone/       Coercion Sentinel (pressure meter)
agents/council/     Bank Council specialists + Arbiter
agents/network/     Pattern Learner, Money Tracer, Bank Liaison
rules/              plain-code decision rules (arbiter + network)
ai/                 Jev client, by-llm calls, typed fallbacks, language helpers
walkers/api.jac     public REST API (walker:pub → POST /walker/<name>)
seed/               fictional banks, people, money and scenarios S1–S5
frontend/           client screens written in Jac (*.cl.jac)
tests/              jac test suites
```

## How we used Jac and Jaseci

- **Graph as shared memory:** citizens, accounts, requests, proposals and scam patterns are nodes. Agents are **walkers** that read and write the same graph.
- **`walker:pub`** turns walkers into REST endpoints with no extra web framework.
- **`by llm`** for System 2 generation, with typed return values.
- **Jac client (`.cl.jac`)** for the full frontend, so the UI is written in Jac too.
- **`jac test`** for unit and scenario tests.

