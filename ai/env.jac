"""Load .env once and quiet noisy library logs (owner: Person B).
Import this first in every ai/ module that needs keys."""

import os;
import logging;
import warnings;
import dotenv;
import litellm;
import from loguru { logger }

glob ROOT: str = os.path.dirname(os.path.dirname(os.path.abspath(__file__)));
glob ENV_LOADED: bool = dotenv.load_dotenv(os.path.join(ROOT, ".env"));

with entry {
    logging.getLogger("httpx").setLevel("WARNING");
    logging.getLogger("LiteLLM").setLevel("WARNING");
    litellm.suppress_debug_info = True;    # no "Give Feedback / Provider List" prints
    logger.disable("byllm");
    warnings.filterwarnings("ignore", message="Pydantic serializer warnings");   # harmless litellm tool-call warning               # byllm logs full error JSON; we log one short line instead
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
