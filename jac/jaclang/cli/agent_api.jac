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
        cwd: str = "",
        code_intel: CodeIntelligence | None = None;
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
    quiet: bool = False
) -> AgentRequest {
    cwd = os.getcwd();
    return AgentRequest(
        prompt=prompt,
        model=model,
        n_ctx=n_ctx,
        safe=safe,
        quiet=quiet,
        cwd=cwd,
        code_intel=CodeIntelligence(proj_dir=cwd)
    );
}
