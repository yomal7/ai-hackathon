# Guardian Arbiter: runs the Bank Council and writes the Ruling (A). Built in M2.
# Walker names are FIXED (section 7) - stubs for now so C can wire the API.

"""Spawned on a Request: Sentinel -> 5 specialists -> rules -> Ruling."""
walker RunCouncil {}

"""Apply the guardian's answer (REJECT | APPROVE | CALL) to an alert."""
walker ApplyGuardianAnswer {
    has alert_id: str = "";
    has answer: str = "";
}
