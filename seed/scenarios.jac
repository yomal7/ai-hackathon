# Demo scenarios S1-S5 and demo reset (A). Built in M1.
# Walker names are FIXED (section 7) - stubs for now so C can wire the API.

"""Run demo scenario S1..S5. Reports {"request_id"}."""
walker RunScenario {
    has name: str = "S1";
}

"""Delete everything and re-seed the demo graph. Reports {"ok"}."""
walker ResetDemo {}
