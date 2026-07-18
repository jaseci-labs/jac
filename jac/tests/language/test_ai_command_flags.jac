"""Command-surface tests for `jac ai` flag forwarding."""

import from jaclang.cli.agent_api { build_agent_request, validate_agent_request }


test "build_agent_request forwards ui and tui flags" {
    req = build_agent_request("task", "", 0, False, True, True, False);
    assert req.prompt == "task";
    assert req.quiet is True;
    assert req.ui is True;
    assert req.tui is False;
}

test "validate_agent_request rejects ui and tui together" {
    req = build_agent_request("", "", 0, False, False, True, True);
    assert validate_agent_request(req) == 1;
    req = build_agent_request("", "", 0, False, False, True, False);
    assert validate_agent_request(req) == 0;
    req = build_agent_request("", "", 0, False, False, False, True);
    assert validate_agent_request(req) == 0;
}
