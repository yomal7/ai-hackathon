# Tests: UI text (C). frontend/i18n.cl.jac is client code, so we read it as text here.
import os;
import re;
import glob as files;

glob FRONTEND: str = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "frontend");

"""Whole text of a file."""
def read_text(path: str) -> str {
    with open(path, encoding="utf-8") as f {
        return f.read();
    }
}

"""The {key: text} entries of one glob dictionary (EN / SI / TA) in i18n.cl.jac."""
def dictionary(name: str) -> dict[str, str] {
    src = read_text(os.path.join(FRONTEND, "i18n.cl.jac"));
    pattern: str = "(?s)glob " + name + r": dict\[str, str\] = \{(.*?)\n\};";
    block = re.search(pattern, src);
    assert block is not None, f"glob {name} not found in i18n.cl.jac";
    pairs = re.findall(r'(?m)^\s*"([^"]+)":\s*"((?:[^"\\]|\\.)*)"', block.group(1)) as list[tuple[str, str]];
    return {k: v for (k, v) in pairs};
}

"""Every literal key passed to t(...) / tf(...), or stored as "key": "..." in a table, in the frontend files."""
def used_keys() -> set[str] {
    keys: set[str] = set();
    for path in files.glob(os.path.join(FRONTEND, "*.cl.jac")) {
        src = read_text(path);
        keys.update(re.findall(r'\bt[f]?\("([a-z_]+\.[A-Za-z0-9_.]+)"', src) as list[str]);
        keys.update(re.findall(r'"key":\s*"([a-z_]+\.[A-Za-z0-9_.]+)"', src) as list[str]);
    }
    return keys;
}

# Keys built at run time ("agent." + name, ...) - every value the API can send.
glob DYNAMIC: list[str] = (
    ["agent." + a for a in ["COERCION", "PLACE_TIME", "ROUTINE", "MULE_RING", "PATTERN", "ADVOCATE", "SCAM_BREAKER",
                            "ARBITER", "PATTERN_LEARNER", "MONEY_TRACER", "LIAISON_LDB", "LIAISON_CDB", "LIAISON_IDB"]]
    + ["decision." + d for d in ["ALLOW", "STEP_UP", "HOLD", "BLOCK", "ASK_GUARDIAN", "ASK_ANALYST", "FREEZE", "WATCH"]]
    + ["scenario." + s for s in ["S1", "S2", "S3", "S4", "S5"]]
    + ["state." + s for s in ["normal", "active", "suspect", "mule", "blocked", "frozen", "safe"]]
    + ["lang." + c for c in ["si", "ta", "en"]]
    + ["tele.lang_name." + c for c in ["si", "ta", "en"]]
    + ["pressure.calm", "pressure.rising", "pressure.high"]
    + [f"result.{r}.{p}" for r in ["allowed", "blocked", "held", "step_up"] for p in ["title", "body"]]
    + ["nav.phone", "nav.war_room", "nav.guardian", "nav.story", "guardian.reject", "guardian.approve", "guardian.call"]
);

"""A used key is fine if it exists, or is a prefix that real keys extend ("result.held" -> "result.held.title")."""
def known(key: str, en: dict[str, str]) -> bool {
    return key in en or len([k for k in en if k.startswith(key + ".")]) > 0;
}

test "every used key has English text" {
    en = dictionary("EN");
    missing = sorted([k for k in used_keys() if not k.endswith(".") and not known(k, en)]);
    assert missing == [], f"keys used in frontend but missing in EN: {missing}";
}

test "every dynamic key has English text" {
    en = dictionary("EN");
    missing = [k for k in DYNAMIC if k not in en];
    assert missing == [], f"dynamic keys missing in EN: {missing}";
}

test "English texts are not empty" {
    en = dictionary("EN");
    assert len(en) > 100;
    assert [k for (k, v) in en.items() if not v.strip()] == [];
    assert en["sim.banner"] == "Simulation — fictional data";
}

test "Sinhala and Tamil only use known keys, in the right script" {
    en = dictionary("EN");
    for (name, low, high) in [("SI", 0x0D80, 0x0DFF), ("TA", 0x0B80, 0x0BFF)] {
        d = dictionary(name);
        assert [k for k in d if k not in en] == [], f"{name} has keys that EN does not";
        for (k, v) in d.items() {
            assert any(low <= ord(ch) <= high for ch in v), f"{name} text for {k} is not in its script";
        }
    }
}

test "simulation label exists in all three languages" {
    for name in ["EN", "SI", "TA"] {
        assert "sim.banner" in dictionary(name);
    }
}
