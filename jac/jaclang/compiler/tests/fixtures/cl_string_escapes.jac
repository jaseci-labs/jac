"""String escape-sequence cross-backend equivalence fixture.

Regression guard for #6476 item 1: the ECMAScript (cl) target used to emit
string-literal escape sequences verbatim (e.g. `\n` stayed a backslash + 'n')
instead of interpreting them the way the Python (sv) reference does, so the same
literal meant different things per backend. Every backend must decode escapes
identically, so the returned strings compare equal across sv / cl / na.
"""

# Shared escape-sequence literals, expressed once per backend body so the only
# variable under test is how each emitter lowers the *same* source token.
def escapes_py() -> dict {
    return {
        "newline": "x\ny",
        "tab": "a\tb",
        "carriage": "a\rb",
        "backslash": "c:\\path",
        "dquote": "say \"hi\"",
        "squote": 'it\'s',
        "hex": "esc\x1b[0m",
        "unicode": "café",
        "mixed": "line1\nline2\tend\\done",
        "concat": "a\nb" "c\td",
    };
}

cl def escapes_cl() -> dict {
    return {
        "newline": "x\ny",
        "tab": "a\tb",
        "carriage": "a\rb",
        "backslash": "c:\\path",
        "dquote": "say \"hi\"",
        "squote": 'it\'s',
        "hex": "esc\x1b[0m",
        "unicode": "café",
        "mixed": "line1\nline2\tend\\done",
        "concat": "a\nb" "c\td",
    };
}

na {
    def escapes_na() -> dict[str, any] {
        return {
            "newline": "x\ny",
            "tab": "a\tb",
            "carriage": "a\rb",
            "backslash": "c:\\path",
            "dquote": "say \"hi\"",
            "squote": 'it\'s',
            "mixed": "line1\nline2\tend\\done",
            "concat": "a\nb" "c\td",
        };
    }
}
