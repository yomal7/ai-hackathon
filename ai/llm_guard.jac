"""Safety net for System 2 (LLM) calls (owner: Person B):
time limit, cache (memory + .cache/ file), and answer checks.
The demo never waits longer than LLM_TIMEOUT_MS (default 6000 ms)."""

import os;
import re;
import json;
import hashlib;
import threading;
import from concurrent.futures { ThreadPoolExecutor }
import from ai.env { env, llm_key_present, llm_model_name, ROOT }
import from ai.lang { detect_language, script_clean }
import from ai.fallback { to_float }

glob CACHE_FILE: str = os.path.join(ROOT, ".cache", "llm_cache.json");
glob _pool: ThreadPoolExecutor = ThreadPoolExecutor(max_workers=4);
glob _lock: threading.Lock = threading.Lock();
glob _cache: dict = {};
glob _cache_loaded: bool = False;

# ---------- cache ----------

def _load_cache() -> None {
    global _cache_loaded;
    if _cache_loaded { return; }
    _cache_loaded = True;
    try {
        with open(CACHE_FILE, encoding="utf-8") as fh { _cache.update(dict(json.load(fh))); }
    } except Exception {}    # no cache file yet
}

def cache_key(fn: str, payload: dict) -> str {
    raw = llm_model_name() + "|" + fn + "|" + json.dumps(payload, sort_keys=True, ensure_ascii=False);
    return hashlib.sha1(raw.encode()).hexdigest();
}

def cache_get(key: str) -> any {
    with _lock {
        _load_cache();
        return _cache.get(key);
    }
}

def cache_put(key: str, value: any) -> None {
    with _lock {
        _cache[key] = value;
        try {
            os.makedirs(os.path.dirname(CACHE_FILE), exist_ok=True);
            with open(CACHE_FILE, "w", encoding="utf-8") as fh { json.dump(_cache, fh, ensure_ascii=False); }
        } except Exception {}    # cache is only a speed-up
    }
}

# ---------- run with time limit ----------

def _work(fn: str, key: str, worker: any) -> any {
    try {
        result = worker();
    } except Exception as e {
        print("[llm] " + fn + " failed (" + type(e).__name__ + ") -> fixed text used");
        return None;
    }
    if result is not None { cache_put(key, result); }   # even after a timeout: next call is instant
    return result;
}

"""Run worker() (an LLM call that returns checked, JSON-safe data or None).
Returns the cached / fresh result, or None (no key, timeout, error, bad answer)."""
def run_llm(fn: str, payload: dict, worker: any) -> any {
    if not llm_key_present() { return None; }
    key = cache_key(fn, payload);
    hit = cache_get(key);
    if hit is not None { return hit; }
    limit = to_float(env("LLM_TIMEOUT_MS", "6000"), 6000.0) / 1000.0;
    try {
        return _pool.submit(_work, fn, key, worker).result(timeout=limit);
    } except Exception {
        return None;
    }
}

# ---------- answer checks ----------

"""Non-empty, not too long, written in the asked language's script, and no other Indian script mixed in."""
def text_ok(text: any, lang: str, max_len: int = 220) -> bool {
    if not isinstance(text, str) { return False; }
    t = text.strip();
    return 0 < len(t) and len(t) <= max_len and detect_language(t) == lang and script_clean(t, lang);
}

def _numbers(text: str) -> set[str] {
    return set([str(n).replace(",", "") for n in re.findall("\\d[\\d,]*", text)]);
}

"""The LLM never sets numbers: every number it writes must appear in the input."""
def numbers_ok(out_text: str, input_text: str) -> bool {
    return _numbers(out_text).issubset(_numbers(input_text));
}
