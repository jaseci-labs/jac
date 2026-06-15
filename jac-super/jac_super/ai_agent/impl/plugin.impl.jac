"""`run_ai_agent` hook: dispatches `jac ai --tui` to the NA TUI sidecar."""

impl JacSuperAiPlugin.run_ai_agent(req: object) -> int | None {
    r: any = req;
    if bool(r?.tui) {
        import from jac_super.ai_agent.run_tui_session { run_tui_session }
        return run_tui_session(req);
    }
    return None;
}
