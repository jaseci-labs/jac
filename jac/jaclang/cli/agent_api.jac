import os;
import from jaclang.compiler.code_intel { CodeIntelligence }


obj AgentRequest {
    has prompt: str = "",
        model: str = "",
        n_ctx: int = 0,
        safe: bool = False,
        quiet: bool = False,
        ui: bool = False,
        cwd: str = "",
        code_intel: CodeIntelligence | None = None;
}


def build_agent_request(
    prompt: str = "",
    model: str = "",
    n_ctx: int = 0,
    safe: bool = False,
    quiet: bool = False,
    ui: bool = False
) -> AgentRequest {
    cwd = os.getcwd();
    return AgentRequest(
        prompt=prompt,
        model=model,
        n_ctx=n_ctx,
        safe=safe,
        quiet=quiet,
        ui=ui,
        cwd=cwd,
        code_intel=CodeIntelligence(proj_dir=cwd, lazy=True)
    );
}
