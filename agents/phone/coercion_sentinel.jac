# Layer 1 - Coercion Sentinel: live pressure meter 0-100 (A). Built in M2.

"""Spawned on a Request on every telemetry change."""
walker CoercionSentinel {
    has signals: dict = {};
}
