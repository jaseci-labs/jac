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

def _is_alpha(c: str) -> bool {
    return ("a" <= c and c <= "z") or ("A" <= c and c <= "Z") or c == "_";
}

def _is_word_char(c: str) -> bool {
    return _is_alpha(c) or ("0" <= c and c <= "9");
}

def _is_digit(c: str) -> bool {
    return "0" <= c and c <= "9";
}

def:pub classify(w: str, next_c: str) -> str {
    if w in KEYWORDS {
        return "kw";
    }
    if w in LITERALS {
        return "lit";
    }
    if w in SPECIALS {
        return "var";
    }
    if w in TYPES {
        return "ty";
    }
    if len(w) > 0 and ("A" <= w[0] and w[0] <= "Z") {
        return "ty";
    }
    if next_c == "(" {
        return "fn";
    }
    return "plain";
}

def:pub scan_line(line: str, mode: str = "") -> LineScan {
    toks: list[Token] = [];
    n = len(line);
    i = 0;

    if mode == "d3" or mode == "s3" {
        q = "\"" if mode == "d3" else "'";
        s = "";
        while i < n {
            if line[i] == q
                and i + 2 < n + 1
                and i + 2 <= n - 1
                and line[i + 1] == q
                and line[i + 2] == q {
                s = s + q + q + q;
                i = i + 3;
                mode = "";
                break;
            }
            s = s + line[i];
            i = i + 1;
        }
        toks.append(Token(text=s, kind="str"));
        if mode != "" {
            return LineScan(tokens=toks, mode=mode);
        }
    } elif mode == "mc" {
        s = "";
        while i < n {
            if line[i] == "*" and i + 1 <= n - 1 and line[i + 1] == "#" {
                s = s + "*#";
                i = i + 2;
                mode = "";
                break;
            }
            s = s + line[i];
            i = i + 1;
        }
        toks.append(Token(text=s, kind="com"));
        if mode != "" {
            return LineScan(tokens=toks, mode=mode);
        }
    }

    while i < n {
        c = line[i];
        if c == "#" {
            if i + 1 <= n - 1 and line[i + 1] == "*" {
                s = "#*";
                j = i + 2;
                closed = False;
                while j < n {
                    if line[j] == "*" and j + 1 <= n - 1 and line[j + 1] == "#" {
                        s = s + "*#";
                        j = j + 2;
                        closed = True;
                        break;
                    }
                    s = s + line[j];
                    j = j + 1;
                }
                toks.append(Token(text=s, kind="com"));
                i = j;
                if not closed {
                    mode = "mc";
                    break;
                }
                continue;
            }
            rest = "";
            j = i;
            while j < n {
                rest = rest + line[j];
                j = j + 1;
            }
            toks.append(Token(text=rest, kind="com"));
            break;
        }
        if c == "\"" or c == "'" {
            if i + 2 <= n - 1 and line[i + 1] == c and line[i + 2] == c {
                s = c + c + c;
                j = i + 3;
                closed = False;
                while j < n {
                    if line[j] == c
                        and j + 2 <= n - 1
                        and line[j + 1] == c
                        and line[j + 2] == c {
                        s = s + c + c + c;
                        j = j + 3;
                        closed = True;
                        break;
                    }
                    s = s + line[j];
                    j = j + 1;
                }
                toks.append(Token(text=s, kind="str"));
                i = j;
                if not closed {
                    mode = "d3" if c == "\"" else "s3";
                    break;
                }
                continue;
            }
            s = c;
            j = i + 1;
            while j < n and line[j] != c {
                s = s + line[j];
                j = j + 1;
            }
            if j < n {
                s = s + c;
                j = j + 1;
            }
            toks.append(Token(text=s, kind="str"));
            i = j;
            continue;
        }
        if _is_alpha(c) {
            w = "";
            j = i;
            while j < n and _is_word_char(line[j]) {
                w = w + line[j];
                j = j + 1;
            }
            nxt = line[j] if j < n else "";
            toks.append(Token(text=w, kind=classify(w, nxt)));
            i = j;
            continue;
        }
        if _is_digit(c) {
            num = "";
            j = i;
            while j < n
                and (
                    _is_digit(line[j])
                    or line[j] == "."
                    or line[j] == "x"
                    or ("a" <= line[j] and line[j] <= "f")
                    or ("A" <= line[j] and line[j] <= "F")
                ) {
                num = num + line[j];
                j = j + 1;
            }
            toks.append(Token(text=num, kind="num"));
            i = j;
            continue;
        }
        if c == "@" {
            w = c;
            j = i + 1;
            while j < n and _is_word_char(line[j]) {
                w = w + line[j];
                j = j + 1;
            }
            toks.append(Token(text=w, kind="dec"));
            i = j;
            continue;
        }
        if c == "+" or c == "-" or c == "<" or c == ">" or c == "&" {
            op = "";
            j = i;
            while j < n
                and (
                    line[j] == "+"
                    or line[j] == "-"
                    or line[j] == "<"
                    or line[j] == ">"
                    or line[j] == "&"
                    or line[j] == "="
                ) {
                op = op + line[j];
                j = j + 1;
            }
            toks.append(
                Token(text=op, kind="op" if (len(op) >= 2 or op == "&") else "plain")
            );
            i = j;
            continue;
        }
        toks.append(Token(text=c, kind="plain"));
        i = i + 1;
    }
    return LineScan(tokens=toks, mode=mode);
}

def:pub tokenize_lines(lines: list[str], lang: str = "jac") -> list[list[Token]] {
    out: list[list[Token]] = [];
    if lang not in HIGHLIGHTED {
        for ln in lines {
            out.append([Token(text=ln, kind="plain")]);
        }
        return out;
    }
    mode = "";
    for ln in lines {
        scan = scan_line(ln, mode);
        out.append(scan.tokens);
        mode = scan.mode;
    }
    return out;
}
