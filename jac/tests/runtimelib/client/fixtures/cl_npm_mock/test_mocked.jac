"""Mapped mocks and an unmapped package must both work in one file."""

import from "fake-editor" { editor, recordedPriorities }
import from "@fake/telemetry" { track, trackedCount }
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

test "an unmapped npm module still falls back to the proxy stub" {
    whatever();
    whatever.deeply.nested.thing();
    assert 1 + 1 == 2;
}
