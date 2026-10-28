obj Token {
    has text: str = "",
        kind: str = "plain";
}

obj LineScan {
    has tokens: list[Token] = [],
        mode: str = "";
}

glob KEYWORDS: list[str] = [
         "node",
         "edge",
         "walker",
         "obj",
         "enum",
         "class",
         "def",
         "can",
         "with",
         "entry",
         "exit",
         "has",
         "glob",
         "import",
         "from",
         "by",
         "async",
         "await",
         "return",
         "if",
         "else",
         "elif",
         "for",
         "while",
         "in",
         "not",
         "and",
         "or",
         "report",
         "visit",
         "spawn",
         "disengage",
         "skip",
         "del",
         "try",
         "except",
         "finally",
         "raise",
         "match",
         "case",
         "impl",
         "sem",
         "test",
         "own",
         "lambda",
         "cl",
         "sv",
         "na",
         "print",
         "yield",
         "as",
         "new",
         "pub",
         "priv"
     ],
     TYPES: list[str] = [
         "int",
         "str",
         "bool",
         "float",
         "list",
         "dict",
         "tuple",
         "set",
         "any",
         "bytes",
         "i32",
         "i64",
         "u8",
         "u32",
         "f32",
         "f64"
     ],
     LITERALS: list[str] = ["True", "False", "None"],
     SPECIALS: list[str] = ["root", "self", "here", "visitor", "super", "llm"],
     HIGHLIGHTED: list[str] = ["jac", "toml"];

def _is_alpha(c: str) -> bool;

def _is_word_char(c: str) -> bool;

def _is_digit(c: str) -> bool;

def:pub classify(w: str, next_c: str) -> str;

def:pub scan_line(line: str, mode: str = "") -> LineScan;

def:pub tokenize_lines(lines: list[str], lang: str = "jac") -> list[list[Token]];
