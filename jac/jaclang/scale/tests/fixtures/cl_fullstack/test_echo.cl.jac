"""Full-stack cl test exercised by the cl test-runner integration tests.

Runs in the client codespace: these `test` blocks compile to JS and execute
under bun, driving the real `@jac/runtime` fetch bridge against the sibling
`server.jac` that the cl test runner boots automatically -- here against
jac-scale's enhanced server. Covers signup -> login -> authenticated walker
spawn end to end, plus the function-call 401 self-heal (issue #7638).
"""

import from "@jac/runtime" {
    jacSignup,
    jacLogin,
    __doWalkerFetch,
    __doFuncFetch,
    __setLocalStorage,
    __getLocalStorage
}

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

test "function call self-heals on 401 by dropping a foreign jac_token" {
    # A stale/foreign token, as if leaked from another app on the same origin.
    __setLocalStorage("jac_token", "foreign-invalid-token");

    # whoami requires auth, so the server 401s. The fixed __doFuncFetch must
    # drop the dead token (and no-op reload) instead of leaving it to wedge the
    # app across reloads. Regression guard for issue #7638.
    await __doFuncFetch("whoami", {});

    assert not __getLocalStorage("jac_token");
}

test "function call keeps a valid jac_token on success" {
    # Control: the 401 branch must be targeted -- a good token is NOT cleared.
    __setLocalStorage("jac_token", "");
    await jacSignup("carol", "secret123");
    await jacLogin("carol", "secret123");

    result = await __doFuncFetch("whoami", {});
    assert result["who"] == "authenticated";
    assert __getLocalStorage("jac_token");
}
