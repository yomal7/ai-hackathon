# Public REST API - walker:pub endpoints from section 8. Placeholder written by A - C owns this file (C)

"""Health check so we can see the server is up. C may remove it."""
walker:pub ping {
    can go with Root entry {
        report {"ok": True, "app": "rakshaka", "simulation": True};
    }
}
