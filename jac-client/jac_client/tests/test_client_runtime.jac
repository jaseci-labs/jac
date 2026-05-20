"""Static regression tests for `plugin/impl/client_runtime.impl.jac`.

These tests grep the runtime source for guards / shapes that broke in
production. They are static checks rather than live bundle tests, so they
cost nothing in CI and fail immediately if someone re-narrows a guard or
removes a load-bearing branch.

Add a new test here when a runtime regression is fixed and the fix can be
pinned to a recognisable source-level shape (guard, branch order, marker
access). Use this file rather than spawning a per-bug test file.
"""

import from pathlib { Path }


"""The `__jacJsx` per-child guard must filter both None and undefined.

Background: post-#6042 the guard only rejected `None` (JS `null`), so any
JSX child that evaluated to `undefined` -- missing prop, unspread key, slot
that early-returned without a value -- crashed at render with
`TypeError: Cannot read properties of undefined (reading '__jacUnsafeHtml')`.
"""
test "jacJsx child guard rejects None and undefined" {
    runtime_path = (
        Path(__file__).parent.parent / "plugin" / "impl" / "client_runtime.impl.jac"
    );
    assert runtime_path.exists();

    source = runtime_path.read_text();

    # Locate the for-loop body that walks childrenArray.
    loop_marker = "for child in childrenArray {";
    loop_idx = source.find(loop_marker);
    assert loop_idx != -1 , "expected `for child in childrenArray {` loop";

    access_marker = "child.__jacUnsafeHtml";
    access_idx = source.find(access_marker, loop_idx);
    assert access_idx != -1 , "expected `child.__jacUnsafeHtml` access in loop";

    guard_region = source[loop_idx:access_idx];

    # The guard must skip None.
    assert "child == None" in guard_region , ("per-child guard must still reject None");

    # The guard must also skip undefined -- this is the issue #6054 fix.
    assert "child == undefined" in guard_region , (
        "per-child guard must also reject undefined to avoid "
        "`TypeError: Cannot read properties of undefined "
        "(reading '__jacUnsafeHtml')` on a missing-prop child"
    );
}
