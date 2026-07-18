"""Tests for the `jac ai` agent request contract.

`jac ai` calls `run_ai_agent` on `JacCmd` to launch the built-in byLLM coding
agent. `run_ai_agent` is a plain direct method on the runtime interface (not a
plugin hook), so this verifies the request contract only.
"""

import from jaclang.cli.agent_api { build_agent_request }


test "build_agent_request carries the flags and a CodeIntelligence handle" {
    req = build_agent_request("do a thing", "openai/gpt-4o", 16384, True);
    assert req.prompt == "do a thing";
    assert req.model == "openai/gpt-4o";
    assert req.n_ctx == 16384;
    assert req.safe == True;
    assert req.cwd;
    assert req.code_intel is not None;
}
