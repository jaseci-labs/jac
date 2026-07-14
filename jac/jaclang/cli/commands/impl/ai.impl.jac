impl ai(
    prompt: str = "",
    model: str = "",
    n_ctx: int = 0,
    safe: bool = False,
    quiet: bool = False,
    ui: bool = False
) -> int {
    import from jaclang.cli.agent_api { build_agent_request }
    import from jaclang.jac0core.runtime { JacRuntime as Jac }
    req = build_agent_request(prompt, model, n_ctx, safe, quiet, ui);
    return Jac.run_ai_agent(req);
}
