"""Regression test for the undefined JSX child crash.

The `__jacJsx` runtime in `plugin/impl/client_runtime.impl.jac` walks each
child in `childrenArray` and accesses `child.__jacUnsafeHtml`. If the guard
above that access only filters `None` (JS `null`), an `undefined` child --
which is what a missing prop, an unspread key, or a slot that early-returns
without a value compiles to -- crashes at render with:

    TypeError: Cannot read properties of undefined (reading '__jacUnsafeHtml')

This test pins the source-side fix: the per-child guard must reject both
`None` and `undefined` before the property access. It is a static check on
the runtime source, not a live bundle test, so it costs nothing in CI and
fails immediately if someone re-narrows the guard.
"""

import os;
import from pathlib { Path }


"""The `__jacJsx` per-child guard must filter both None and undefined."""
test "child guard handles undefined" {
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
