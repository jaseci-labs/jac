"""Tests for the pluggable `run_ai_agent` hook.

`jac ai` dispatches through the `run_ai_agent` hook on `JacCmd`, so a plugin
can replace the built-in coding agent entirely. These tests verify the
request contract and that a registered plugin outranks the default.
"""

import from jaclang.jac0core.runtime { JacRuntime as Jac, hookimpl, plugin_manager }
import from jaclang.cli.agent_api { build_agent_request }


"""A plugin that replaces the agent -- proves the hook is overridable."""
class FakeAgentPlugin {
    @hookimpl
    static def run_ai_agent(req: object) -> int {
        return 4242;
    }
}


test "build_agent_request carries the flags and a CodeIntelligence handle" {
    req = build_agent_request("do a thing", "openai/gpt-4o", 16384, True);
    assert req.prompt == "do a thing";
    assert req.model == "openai/gpt-4o";
    assert req.n_ctx == 16384;
    assert req.safe == True;
    assert req.cwd;
    assert req.code_intel is not None;
}


test "a plugin can replace the run_ai_agent hook" {
    plug = FakeAgentPlugin();
    plugin_manager.register(plug, name="fake_agent_hook_test");
    try {
        req = build_agent_request("hello", "", 0, True);
        assert Jac.run_ai_agent(req) == 4242;
    } finally {
        plugin_manager.unregister(plug, name="fake_agent_hook_test");
    }
}
