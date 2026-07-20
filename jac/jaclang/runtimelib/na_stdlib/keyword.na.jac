"""Python-congruent ``keyword`` for the native pathway.

Mirrors CPython's kwlist/softkwlist verbatim, ordering included (CPython
generates these from its grammar; they have been stable since 3.10's
soft-keyword additions).
"""

glob kwlist: list[str] = [
         "False",
         "None",
         "True",
         "and",
         "as",
         "assert",
         "async",
         "await",
         "break",
         "class",
         "continue",
         "def",
         "del",
         "elif",
         "else",
         "except",
         "finally",
         "for",
         "from",
         "global",
         "if",
         "import",
         "in",
         "is",
         "lambda",
         "nonlocal",
         "not",
         "or",
         "pass",
         "raise",
         "return",
         "try",
         "while",
         "with",
         "yield",
     ];

glob softkwlist: list[str] = ["_", "case", "match", "type"];

def:pub iskeyword(s: str) -> bool {
    return s in kwlist;
}

def:pub issoftkeyword(s: str) -> bool {
    return s in softkwlist;
}
