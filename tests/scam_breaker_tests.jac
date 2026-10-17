"""Tests for the Scam-Breaker (owner: Person B). Run: jac test tests/scam_breaker_tests.jac
No network: keys are cleared, so questions are the fixed texts and replies use the code reader."""

import os;
import uuid;
import from graph.nodes { Citizen, Request, Guardian, Alert, Proposal, ScamCheck }
import from graph.edges { Made, ProtectedBy, Raised, HasProposal, Checked }
import from agents.council.scam_breaker {
    ScamBreakerStart, ScamAnswer, scam_breaker_state, people_saw, find_request
}
import from ai.lang { detect_language }
import from tests.net_story { forget_test_graph, MARK }

with entry {
    for k in ["TYPESAFE_API_KEY", "GEMINI_API_KEY", "GOOGLE_API_KEY", "OPENAI_API_KEY", "ANTHROPIC_API_KEY"] {
        os.environ[k] = "";
    }
}

"""Elder + guardian + one scam Request, with a unique id (the graph persists between runs)."""
def make_case(name: str, lang: str, guardian: str) -> Request {
    forget_test_graph();
    rid = "REQ-" + MARK + uuid.uuid4().hex[:8];
    c = Citizen(id="C-" + rid, name=name, age=74, city="Kandy", language=lang, is_elder=True);
    r = Request(id=rid, action="BREAK_FD", amount=4200000, reference_text="safe account", status="HELD",
                language=lang, telemetry={"on_call": True, "pasted_account": True});
    root ++> c;
    c +>:Made():+> r;
    c +>:ProtectedBy():+> Guardian(id="G-" + rid, name=guardian, relation="son", language=lang);
    return r;
}

def proposals_of(r: Request) -> list[Proposal] {
    return [p for p in [r ->:HasProposal:->] if isinstance(p, Proposal) and p.agent == "SCAM_BREAKER"];
}

test "start asks 3 questions in Sinhala" {
    r = make_case("Siriwardena", "si", "Dilshan");
    r spawn ScamBreakerStart();
    st = scam_breaker_state(r.id);
    assert st["active"] and st["language"] == "si";
    assert len(list(st["questions"])) == 3;
    assert all([detect_language(str(q)) == "si" for q in list(st["questions"])]);
    assert detect_language(str(st["warning"])) == "si";
    assert st["answers"] == ["", "", ""];
}

test "start twice does not ask twice" {
    r = make_case("Siriwardena", "si", "Dilshan");
    r spawn ScamBreakerStart();
    r spawn ScamBreakerStart();
    assert len([n for n in [r ->:Checked:->] if isinstance(n, ScamCheck)]) == 3;
}

test "coached answers give a HOLD proposal, written once" {
    r = make_case("Siriwardena", "si", "Dilshan");
    r spawn ScamBreakerStart();
    res = r spawn ScamAnswer(answer="ඔව්");
    assert res.reports[0]["next_question"] is not None;
    r spawn ScamAnswer(answer="Yes, he says he is CID");
    res = r spawn ScamAnswer(answer="ඔව්");
    assert res.reports[0]["next_question"] is None;
    ps = proposals_of(r);
    assert len(ps) == 1;
    assert ps[0].stance == "HOLD" and ps[0].confidence >= 0.9;
    assert ps[0].scope == "REQUEST" and "Siriwardena" in ps[0].reason;
    assert scam_breaker_state(r.id)["readings"] == ["COACHED", "COACHED", "COACHED"];
    r spawn ScamAnswer(answer="නැහැ");                  # extra answer after the last one: ignored
    assert len(proposals_of(r)) == 1;
    assert scam_breaker_state(r.id)["answers"][0] == "ඔව්";
}

test "Tamil elder: questions in Tamil, 'no' answers give STEP_UP" {
    r = make_case("Kamala", "ta", "Priya");
    r spawn ScamBreakerStart();
    st = scam_breaker_state(r.id);
    assert st["language"] == "ta" and detect_language(str(st["questions"][0])) == "ta";
    for _ in range(3) { r spawn ScamAnswer(answer="இல்லை"); }
    ps = proposals_of(r);
    assert len(ps) == 1 and ps[0].stance == "STEP_UP";
}

test "answer by question index" {
    r = make_case("Siriwardena", "si", "Dilshan");
    r spawn ScamBreakerStart();
    r spawn ScamAnswer(q=2, answer="නැහැ");
    st = scam_breaker_state(r.id);
    assert st["answers"] == ["", "", "නැහැ"] and st["readings"][2] == "NOT_COACHED";
}

test "people_saw shows the elder's questions and the guardian card" {
    r = make_case("Siriwardena", "si", "Dilshan");
    r spawn ScamBreakerStart();
    r +>:Raised():+> Alert(id="AL-" + r.id, kind="GUARDIAN", language="si", title="කරුණාකර බලන්න", lines=["එක", "දෙක"]);
    st = scam_breaker_state(r.id);
    assert "Dilshan" in str(st["guardian_message"]);
    saw = people_saw(r.id);
    assert len([s for s in saw if s["who"] == "Siriwardena"]) == 5;    # 3 questions + warning + "son was asked"
    assert len([s for s in saw if s["who"] == "Dilshan" and s["language"] == "si"]) == 1;
}

test "unknown request: inactive state, nothing seen" {
    assert find_request("NO-SUCH-REQ") is None;
    assert scam_breaker_state("NO-SUCH-REQ")["active"] == False;
    assert people_saw("NO-SUCH-REQ") == [];
}
