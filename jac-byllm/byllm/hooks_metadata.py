"""Hook metadata for byllm plugin."""


def get_hooks():
    """Return list of hooks implemented by this plugin."""
    return ["get_mtir", "call_llm"]
