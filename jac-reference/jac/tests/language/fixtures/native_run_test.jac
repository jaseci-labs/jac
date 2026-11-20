"""Native-codespace (.jac) test file.

Exercises the collector's module-name derivation for compound codespace
suffixes: `foo.jac` must import as module `foo`, not `foo.na` (issue #7150).
A well-formed `.jac` test file must collect and run its `test` blocks rather
than silently collecting 0 items and passing.
"""

glob a = 5,
     b = 2;

test "na_pass" {
    assert a - b == 3;
}

test "na_fail" {
    assert a == b;
}
