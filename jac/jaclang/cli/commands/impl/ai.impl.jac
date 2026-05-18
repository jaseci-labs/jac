"""Implementation of the `jac ai` command.

This file is intentionally thin: it validates that byLLM is available, then
hands the user's flags straight to `run_agent`. The agent itself lives in
`jaclang/cli/ai_agent.jac`, imported lazily here so the core CLI keeps no hard
dependency on the byLLM plugin.
"""
import from jaclang.cli.console { console }

"""Launch an interactive Jac coding agent powered by a byLLM model."""
impl ai(prompt: str = "", model: str = "", n_ctx: int = 0, yolo: bool = False) -> int {
    try {
        import from jaclang.cli.ai_agent { run_agent }
    } except ImportError {
        console.error(
            "`jac ai` needs the byLLM plugin, which is not installed.",
            hint="Install it with:  pip install byllm"
        );
        return 1;
    }
    return run_agent(prompt, model, n_ctx, yolo);
}
