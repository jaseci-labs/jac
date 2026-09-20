"""The escape-warning inputs JacPython chooses, against CPython 3.14.

Two pieces are decided here rather than by the runtime: which escapes a
bytes literal accepts, and which line the warning names. The warning
itself goes through the runtime's `warn` hook, so the wiring is covered
by the JacPython oracle in the passes-native chunk; what is checked here
is the arithmetic and the set.

CPython 3.14 warns once per literal, at the line the first invalid
escape sits on, not the line the literal opens on (3.12 named the
opening line, so the reference has to be 3.14). A bytes literal takes
the str escapes minus the three that name a code point.

The frontend package is compiled into the native library and is not
importable from a sealed kit, so this skips there and runs from a
source checkout.
"""

def _escape_api -> (tuple[set[int], set[int], any] | None) {
    try {
        import from jaclang.compiler.frontend.python.parser_actions {
            VALID_BYTES_ESCAPE_POINTS,
            VALID_ESCAPE_POINTS,
            pa_escape_line_offset
        }
        return (VALID_ESCAPE_POINTS, VALID_BYTES_ESCAPE_POINTS, pa_escape_line_offset);
    } except ImportError {
        return None;
    }
}


test "a bytes literal drops the three code-point escapes" {
    api = _escape_api();
    if api is None {
        testskip("sealed kit: the JacPython frontend is not importable");
    }
    (str_points, bytes_points, _offset) = api;
    assert bytes_points < str_points , (
        "bytes escapes must be a strict subset of the str escapes"
    );
    missing = str_points - bytes_points;
    assert missing == {ord("u"), ord("U"), ord("N")} , sorted(missing);
}


test "the line offset counts the newlines before the escape" {
    api = _escape_api();
    if api is None {
        testskip("sealed kit: the JacPython frontend is not importable");
    }
    line_offset = api[2];
    body = "\nalpha\n\\d beta\n".encode("utf-8");
    at = body.index(92);
    assert line_offset(body, at) == 2 , line_offset(body, at);
    assert line_offset(body, 0) == 0;
    assert line_offset(body, len(body)) == 3;
}


test "a single-line body never shifts the line" {
    api = _escape_api();
    if api is None {
        testskip("sealed kit: the JacPython frontend is not importable");
    }
    line_offset = api[2];
    body = "one \\d two".encode("utf-8");
    assert line_offset(body, body.index(92)) == 0;
}
