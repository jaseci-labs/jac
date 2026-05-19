"""Implementation of the `jac ai` command.

This file is intentionally thin: it builds an `AgentRequest` from the user's
flags and dispatches it through the `run_ai_agent` hook. The core ships a
built-in byLLM agent as the default hook implementation; a plugin can register
its own to replace it. Because dispatch goes through the hook, the core CLI
keeps no hard dependency on the byLLM plugin.
"""

"""Launch an interactive Jac coding agent."""
impl ai(prompt: str = "", model: str = "", n_ctx: int = 0, safe: bool = False) -> int {
    import from jaclang.cli.agent_api { build_agent_request }
    import from jaclang.jac0core.runtime { JacRuntime as Jac }
    req = build_agent_request(prompt, model, n_ctx, safe);
    return Jac.run_ai_agent(req);
}
