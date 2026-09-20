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
"""

import from jaclang.compiler.frontend.python.parser_actions {
    VALID_BYTES_ESCAPE_POINTS,
    VALID_ESCAPE_POINTS,
    pa_escape_line_offset
}


test "a bytes literal drops the three code-point escapes" {
    assert VALID_BYTES_ESCAPE_POINTS < VALID_ESCAPE_POINTS , (
        "bytes escapes must be a strict subset of the str escapes"
    );
    missing = VALID_ESCAPE_POINTS - VALID_BYTES_ESCAPE_POINTS;
    assert missing == {ord("u"), ord("U"), ord("N")} , sorted(missing);
}


test "the line offset counts the newlines before the escape" {
    # `b"""\nalpha\n\d beta\n"""` -- the body opens after the quotes, so
    # the escape at index 12 sits two newlines in, and CPython names the
    # literal's line plus two.
    body = "\nalpha\n\\d beta\n".encode("utf-8");
    at = body.index(92);
    assert pa_escape_line_offset(body, at) == 2 , pa_escape_line_offset(body, at);
    assert pa_escape_line_offset(body, 0) == 0;
    assert pa_escape_line_offset(body, len(body)) == 3;
}


test "a single-line body never shifts the line" {
    body = "one \\d two".encode("utf-8");
    assert pa_escape_line_offset(body, body.index(92)) == 0;
}
