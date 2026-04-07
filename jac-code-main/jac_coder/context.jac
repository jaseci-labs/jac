import from jac_coder.config { llm }

obj ContextConfig {
    has token_budget: int = 20000;
    has recent_window: int = 8;
}


"""LLM-based summarization of older conversation turns.
Uses the same model configured for the main coding agent."""
def summarize_turns(older_messages: list[dict], session_goal: str) -> str
    by llm(temperature=0.1, max_tokens=1000);


def estimate_tokens(messages: list[dict]) -> int;

def needs_compaction(messages: list[dict], budget: int = 20000) -> bool;

def build_context(
    chat_history: list[dict],
    active_files: list[str] = [],
    pending_errors: list[str] = [],
    config: ContextConfig | None = None,
    project_summary: str = ""
) -> list[dict];
