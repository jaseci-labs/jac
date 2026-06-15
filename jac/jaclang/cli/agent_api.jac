"""The `jac ai` agent contract -- the request a pluggable agent receives.

`AgentRequest` is the stable interface between the `jac ai` command and
whatever implements the `run_ai_agent` hook: the built-in byLLM agent, or a
plugin that replaces it. It carries the resolved CLI flags plus a
`CodeIntelligence` handle, so the agent can navigate the project
semantically -- precise definitions, uses, and types -- rather than by text
search.

The contract is an object rather than a fixed parameter list so new fields
can be added without breaking existing agent plugins.
"""

import os;
import from jaclang.cli.console { console }
import from jaclang.compiler.code_intel { CodeIntelligence }


"""Everything a `jac ai` agent needs to run one session."""
obj AgentRequest {
    has prompt: str = "",
        model: str = "",
        n_ctx: int = 0,
        safe: bool = False,
        # Compact output: suppress the live reasoning stream, per-step/tool
        # timings, and step detail, leaving just tool calls and the answer.
        quiet: bool = False,
        # Open the agent in a web UI (a bundled Jac fullstack app) instead of the
        # terminal REPL, with a live cytoscape visualizer of the phase walker.
        ui: bool = False,
        # Open the agent in a terminal UI; mutually exclusive with `ui`.
        tui: bool = False,
        cwd: str = "",
        code_intel: CodeIntelligence | None = None,
        # Session resume controls (issue #6706). At most one is meaningful; the
        # agent resolves them in priority order: resume > continue_last >
        # session_name > new session. Empty/false means "not requested".
        resume: str = "",
        continue_last: bool = False,
        session_name: str = "";
}


"""Build an AgentRequest from the resolved `jac ai` flags.

Roots a `CodeIntelligence` at the current working directory; the agent's
semantic tools share this single handle, so the project is compiled once.
"""
def build_agent_request(
    prompt: str = "",
    model: str = "",
    n_ctx: int = 0,
    safe: bool = False,
    quiet: bool = False,
    ui: bool = False,
    tui: bool = False,
    resume: str = "",
    continue_last: bool = False,
    session_name: str = ""
) -> AgentRequest {
    cwd = os.getcwd();
    return AgentRequest(
        prompt=prompt,
        model=model,
        n_ctx=n_ctx,
        safe=safe,
        quiet=quiet,
        ui=ui,
        tui=tui,
        cwd=cwd,
        code_intel=CodeIntelligence(proj_dir=cwd, lazy=True),
        resume=resume,
        continue_last=continue_last,
        session_name=session_name
        # Lazy: the agent's structural tools (`project_map`, walkers) load from
        # the cheap, cross-run-cached structural index, deferring the full
        # type-checked pipeline until the first symbol/diagnostic query actually
        # needs it -- so startup and project-map calls don't pay semantic cost.
    );
}


"""Validate CLI flag combinations on an AgentRequest.

Returns 0 when valid, 1 after printing an error for incompatible flags.
"""
def validate_agent_request(req: AgentRequest) -> int {
    if req.ui and req.tui {
        console.error("`jac ai`: `--ui` and `--tui` are mutually exclusive.");
        return 1;
    }
    return 0;
}
