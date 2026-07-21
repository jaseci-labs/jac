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

     ],
     softkwlist: list[str] = ["_", "case", "match", "type"];

def:pub iskeyword(s: str) -> bool {
    return s in kwlist;
}

def:pub issoftkeyword(s: str) -> bool {
    return s in softkwlist;
}
