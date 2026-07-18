"""Native call resolution against the bundled na_stdlib signature (issue #7037).

A call to a bundled `na_stdlib` function from native code must type-check,
keyword-bind, and default-fill against the bundled `.na.jac` signature (the one
that is actually linked and run) -- NOT CPython's typeshed stub.

The bundled `json.dumps(value: any)` diverges from typeshed's
`json.dumps(obj, *, ...)`. Before the fix, `dumps(value="hi")` resolved against
the typeshed stub (which has no `value` parameter) and failed to compile with
`error[E1050]: ... 'obj'`. The positional form matched typeshed trivially and
always worked, so this pins the keyword form against the positional baseline.

`json.dumps("hi")` produces the 4-character text `"hi"` (with the JSON quotes).
"""

na {
    import json;

    def dumps_pos_len() -> int {
        return len(json.dumps("hi"));
    }

    def dumps_kw_len() -> int {
        return len(json.dumps(value="hi"));
    }
}
