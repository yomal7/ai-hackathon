"""Load .env once, quiet noisy library logs, and build the LLM model (owner: Person B).
Works on both Jac versions: pip jaclang 0.16 (byllm.lib) and the native jac 0.34 (jaclang.byllm.lib).
Import this first in every ai/ module that needs keys."""

import os;
import logging;
import warnings;
import importlib;
import dotenv;

glob ROOT: str = os.path.dirname(os.path.dirname(os.path.abspath(__file__)));
glob ENV_LOADED: bool = dotenv.load_dotenv(os.path.join(ROOT, ".env"));

"""Import the first module that exists, or None."""
def _first_module(names: list[str]) -> any {
    for name in names {
        try { return importlib.import_module(name); } except ImportError {}
    }
    return None;
}

with entry {
    logging.getLogger("httpx").setLevel("WARNING");
    logging.getLogger("LiteLLM").setLevel("WARNING");
    warnings.filterwarnings("ignore", message="Pydantic serializer warnings");   # harmless litellm tool-call warning
    lite = _first_module(["litellm"]);
    if lite is not None { lite.suppress_debug_info = True; }       # no "Give Feedback / Provider List" prints
    lg = _first_module(["loguru"]);
    if lg is not None { lg.logger.disable("byllm"); }              # byllm logs full error JSON; we log one short line instead
}

def env(name: str, fallback_val: str = "") -> str {
    return os.environ.get(name, fallback_val).strip();
}

"""True if an LLM key for the chosen model is set."""
def llm_key_present() -> bool {
    return bool(env("GEMINI_API_KEY") or env("GOOGLE_API_KEY") or env("OPENAI_API_KEY") or env("ANTHROPIC_API_KEY"));
}

def llm_model_name() -> str {
    return env("BYLLM_DEFAULT_MODEL", "gemini/gemini-3.5-flash-lite") or "gemini/gemini-3.5-flash-lite";
}

"""The byLLM Model for by llm() calls, from whichever Jac version is running."""
def make_llm() -> any {
    lib = _first_module(["jaclang.byllm.lib", "byllm.lib"]);
    return lib.Model(model_name=llm_model_name());
}
