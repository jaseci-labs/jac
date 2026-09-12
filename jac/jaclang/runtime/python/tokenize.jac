"""Python's streaming token iterator backed by the shared Jac scanner."""

import from typing { Never }
import from jaclang.compiler.frontend.python.tokenizer { tok_state, tokenizer_next }
import from jaclang.compiler.frontend.python.token_model {
    ENDMARKER,
    NEWLINE,
    INDENT,
    DEDENT,
    NUMBER,
    STRING,
    OP,
    FSTRING_MIDDLE,
    TSTRING_MIDDLE,
    NL,
    tok_diag
}

glob _encoding_unset: object = object();

def _character_column(line: str, column: int) -> int {
    if column < 0 {
        return column;
    }
    return len(line.encode("utf-8")[:column].decode("utf-8"));
}

obj _TokenizerIter {
    has reader: any,
        encoding: str | None,
        scanner: tok_state,
        lines: list[str] = [],
        finished: bool = False,
        input_finished: bool = False,
        last_line: str = "",
        last_line_number: int = 0;

    def __iter__ -> _TokenizerIter {
        return self;
    }

    def refill -> bool {
        if self.input_finished {
            return False;
        }
        try {
            line = self.reader();
        } except StopIteration {
            self.input_finished = True;
            return False;
        }
        if self.encoding is None {
            if not isinstance(line, str) {
                raise TypeError("readline() returned a non-string");
            }
        } else {
            if not isinstance(line, bytes) {
                raise TypeError("readline() returned a non-bytes object");
            }
            line = line.decode(self.encoding, "replace");
        }
        if not line {
            self.input_finished = True;
            return False;
        }
        parts = line.split("\n");
        self.lines.extend(part + "\n" for part in parts[:-1]);
        if parts[-1] {
            self.lines.append(parts[-1]);
        }
        decoded = line.replace("\r\n", "\n");
        if not decoded.endswith("\n") {
            decoded += "\n";
        }
        self.scanner.source += decoded;
        return True;
    }

    def source_line(lineno: int) -> str {
        return self.lines[lineno - 1] if 0 < lineno <= len(self.lines) else "";
    }

    def syntax_error(
        message: str, lineno: int, offset: int, kind: str = "SyntaxError"
    ) -> Never {
        self.finished = True;
        line = self.source_line(lineno).rstrip("\r\n");
        error_type = IndentationError
            if kind == "IndentationError"
            else TabError if kind == "TabError" else SyntaxError;
        raise error_type(message, ("<string>", lineno, offset, line, None, None));
    }

    def __next__ -> tuple {
        if self.finished {
            raise StopIteration("EOF");
        }
        item = tokenizer_next(self.scanner);
        if isinstance(item, tok_diag) {
            line = self.source_line(item.loc.lineno);
            column = _character_column(line, item.loc.col_offset);
            if item.kind in ("IndentationError", "TabError") {
                column = len(line.rstrip("\r\n"));
            }
            self.syntax_error(item.message, item.loc.lineno, column + 1, item.kind);
        }
        kind = item.tok_type;
        start_line = item.lineno;
        end_line = item.end_lineno;
        start = _character_column(self.source_line(start_line), item.col_offset);
        end = _character_column(self.source_line(end_line), item.end_col_offset);
        spelling = item.spelling;
        line = self.source_line(start_line);
        if kind in (STRING, FSTRING_MIDDLE, TSTRING_MIDDLE) {
            line = "".join(self.lines[start_line - 1:end_line]);
            if end_line > start_line {
                spelling = self.source_line(start_line)[start:]
                    + "".join(self.lines[start_line:end_line - 1])
                    + self.source_line(end_line)[:end];
            }
        }
        trailing = kind == ENDMARKER or (kind == DEDENT and self.input_finished);
        if kind == ENDMARKER {
            self.finished = True;
            if self.scanner.paren_level > 0 {
                self.syntax_error(
                    "unexpected EOF in multi-line statement", len(self.lines), 0
                );
            }
            if not self.scanner.extra_tokens and not self.lines {
                raise StopIteration("EOF");
            }
        }
        if trailing {
            if self.scanner.extra_tokens {
                start_line = end_line=len(self.lines) + 1;
                start = end=0;
                line = "";
            } else {
                start_line = end_line=max(1, len(self.lines));
                start = end=-1;
                line = self.last_line if start_line == self.last_line_number else "";
            }
        } elif kind in (NEWLINE, NL) {
            original = self.source_line(start_line);
            terminator = "\r\n"
                if original.endswith("\r\n")
                else "\n" if original.endswith("\n") else "";
            if self.scanner.extra_tokens {
                spelling = terminator;
                end = start + max(1, len(terminator));
            } else {
                spelling = "\r" if terminator == "\r\n" else "";
                comments = self.scanner.comments.get(start_line, []);
                if comments {
                    start = _character_column(original, comments[-1][0]);
                    spelling = original[start:].removesuffix("\n");
                }
                end = start + len(spelling);
            }
        }
        if kind == NUMBER {
            self.validate_number(spelling, start_line, start);
        }
        if self.scanner.extra_tokens and DEDENT < kind < OP {
            kind = OP;
        }
        if not trailing {
            self.last_line = self.source_line(end_line);
            self.last_line_number = end_line;
        }
        return (kind, spelling, (start_line, start), (end_line, end), line);
    }

    def validate_number(spelling: str, lineno: int, column: int) {
        base = spelling[:2].lower();
        description = {"0x": "hexadecimal", "0b": "binary", "0o": "octal"}.get(
            base, "decimal"
        );
        try {
            if base in ("0x", "0b", "0o") {
                int(spelling, 0);
            } elif spelling.endswith(("j", "J")) {
                complex(spelling);
            } elif any(ch in spelling for ch in ".eE") {
                float(spelling);
            } else {
                int(spelling, 10 if self.scanner.extra_tokens else 0);
            }
        } except ValueError {
            self.syntax_error(f"invalid {description} literal", lineno, column + 1);
        }
    }
}

def TokenizerIter(
    readline: any, /, *, extra_tokens: any, encoding: any = _encoding_unset
) -> _TokenizerIter {
    if encoding is _encoding_unset {
        encoding = None;
    } elif not isinstance(encoding, str) {
        raise TypeError("tokenizeriter() argument 'encoding' must be str");
    } elif "\x00" in encoding {
        raise ValueError("embedded null character");
    }
    scanner = tok_state(
        source="", filename="<string>", extra_tokens=bool(extra_tokens)
    );
    result = _TokenizerIter(reader=readline, encoding=encoding, scanner=scanner);
    scanner.refill = result.refill;
    return result;
}
