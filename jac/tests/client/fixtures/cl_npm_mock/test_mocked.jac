"""Both mock routes and the proxy fallback, resolved in one project.

`fake-editor` and `@fake/telemetry` are mapped by [test.client.mocks];
`fake-widgets` is found by the tests/__mocks__ convention; everything else
falls through to the universal Proxy stub.
"""

import from "fake-editor" { editor, recordedPriorities }
import from "@fake/telemetry" { track, trackedCount }
import from "fake-widgets" { widget, helper }
import from "unmapped-pkg" { whatever }

test "a mapped npm module returns real values" {
    picked = await editor.showQuickPick(["3.11", "3.12"]);
    assert picked == "3.12";
}

test "a mapped npm module records what it was called with" {
    editor.createStatusBarItem("left", 100);
    assert recordedPriorities()[0] == 100;
}

test "a jac-authored mock is compiled and staged like any client module" {
    assert track("boot") == "tracked:boot";
    assert trackedCount() == 1;
}

test "a tests/__mocks__ mock loads, and its own helper file was staged with it" {
    # "w1" comes from ./support/ids, so this passes only if it was staged.
    assert widget.id() == "w1";
}

test "a name re-exported from an unmapped package lands on the proxy" {
    helper();
    assert 1 + 1 == 2;
}

test "an unmapped npm module still falls back to the proxy stub" {
    whatever();
    whatever.deeply.nested.thing();
    assert 1 + 1 == 2;
}
