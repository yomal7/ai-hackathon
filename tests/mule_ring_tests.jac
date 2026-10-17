# Tests: the Mule Ring agent (A)
import from graph.nodes { Request, Proposal }
import from graph.edges { Paid }
import from graph.queries { find_request, find_account, create_request }
import from seed.scenarios { seed_demo, RunScenario }
import from agents.council.council_common { proposal_of, risk_of }
import from agents.council.mule_ring { MuleRingAgent }

"""Run only the Mule Ring on a fresh request from Seeya to this payee at 14:30."""
def ring_for(payee_id: str) -> Request {
    req = create_request("c_seeya", "TRANSFER", 50000, payee_id, "", "14:30");
    assert req is not None;
    req spawn MuleRingAgent();
    return req;
}

def ring(req: Request) -> Proposal {
    p = proposal_of(req, "MULE_RING");
    assert p is not None;
    return p;
}

test "mule ring finds Mallika and Rasheed for LDB-77821" {
    seed_demo();
    w = root spawn RunScenario(name="S3");
    req = find_request(w.request_id);
    assert req is not None;
    p = ring(req);
    assert str(p.stance) == "HOLD" and p.confidence >= 0.9;
    assert "2 other elders" in p.reason and "9-day-old" in p.reason and "35 min" in p.reason;
    path = req.walk_path;
    assert path[:2] == ["c_seeya", "LDB-77821"];
    assert "c_mallika" in path and "c_rasheed" in path;
    assert path.index("CDB-30871") < path.index("c_mallika");      # account first, then its owner
    assert "CDB-40213" in path;                                       # where the money went next
}

test "an old shop with many payers is not a mule" {
    seed_demo();
    p = ring(ring_for("CDB-11502"));      # Perera Hardware
    assert risk_of(p) <= 0.3, p.reason;
    assert "established shop" in p.reason;
}

test "a biller and a hospital are not mules" {
    seed_demo();
    assert risk_of(ring(ring_for("LDB-10001"))) <= 0.3;
    assert risk_of(ring(ring_for("LDB-10004"))) <= 0.3;
}

test "a brand-new account nobody paid yet is not locked by the ring" {
    seed_demo();
    p = ring(ring_for("IDB-31877"));      # S4's new mule - only the Pattern agent can catch it
    assert risk_of(p) < 0.75, p.reason;
}

test "a confirmed mule is a BLOCK" {
    seed_demo();
    acc = find_account("LDB-77821");
    assert acc is not None;
    acc.confirmed_mule = True;
    p = ring(ring_for("LDB-77821"));
    assert str(p.stance) == "BLOCK";
}

test "the payer's own earlier payments do not count as other elders" {
    seed_demo();
    seeya_savings = find_account("LDB-20114");
    target = find_account("LDB-77821");
    assert seeya_savings is not None and target is not None;
    seeya_savings +>:Paid(amount=20000, time="14:20", days_ago=0):+> target;
    p = ring(ring_for("LDB-77821"));
    assert "2 other elders" in p.reason, p.reason;
}
