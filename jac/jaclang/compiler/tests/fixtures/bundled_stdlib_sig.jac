"""Native call resolution against the bundled na_stdlib signature (issue #7037).

A call to a bundled `na_stdlib` function from native code must type-check,
keyword-bind, and default-fill against the bundled `.jac` signature (the one
that is actually linked and run) -- NOT CPython's typeshed stub.

The bundled `json.dumps` once named its first parameter `value` where typeshed
says `obj`, and a keyword call resolved against the wrong one. The native
library now takes the interface's parameter names (`E5114`), so the keyword
form is `obj=` on every backend; this pins it against the positional baseline.

`json.dumps("hi")` produces the 4-character text `"hi"` (with the JSON quotes).
"""

import json;

def dumps_pos_len() -> int {
    return len(json.dumps("hi"));
}

def dumps_kw_len() -> int {
    return len(json.dumps(`obj="hi"));
}
