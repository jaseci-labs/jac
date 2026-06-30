"""Full-stack cl test exercised by the cl test-runner integration tests.

Runs in the client codespace: this `test` block compiles to JS and executes
under bun, driving the real `@jac/runtime` fetch bridge against the sibling
`server.jac` that the cl test runner boots automatically -- here against
jac-scale's enhanced server. Covers signup -> login -> authenticated walker
spawn end to end.
"""

import from "@jac/runtime" { jacSignup, jacLogin, __doWalkerFetch, __setLocalStorage }

test "signup, save a note, and read it back" {
    __setLocalStorage("jac_token", "");
    await jacSignup("alice", "secret123");
    await jacLogin("alice", "secret123");

    saved = await __doWalkerFetch("save_note", "", {"text": "hello"});
    saved_reports = saved["result"]["reports"];
    assert saved_reports[0]["text"] == "hello";

    listed = await __doWalkerFetch("list_notes", "", {});
    listed_reports = listed["result"]["reports"];
    assert len(listed_reports) == 1;
    assert listed_reports[0]["text"] == "hello";
}
