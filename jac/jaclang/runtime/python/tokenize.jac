"""Python's streaming token iterator backed by the shared Jac scanner."""

import type from typing { Never }
import from jaclang.compiler.frontend.python.compiler_diagnostics {
    report_token_warnings
}
import from jaclang.compiler.frontend.python.tokenizer {
    tok_state,
    token_source,
    tokenizer_next
}
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

import from jaclang.runtime.python.native_services {
    take_buffer,
    runtime_failure,
    parse_integer,
    parse_float
}
import from jaclang.compiler.frontend.python.syntax_error { syntax_failure }
import from c { def jacpy_readline(reader: u64, encoding: str, decode: i64) -> u64;  }
obj native_token {
    has kind: int,
        spelling: str,
        start_line: int,
        start: int,
        end_line: int,
        end: int,
        line: str;
}

def _character_column(line: str, column: int) -> int {
    if column < 0 {
        return column;
    }
    data = line.encode("utf-8");
    result = 0;
    for index in range(min(column, len(data))) {
        if (data[index] & 192) != 128 {
            result += 1;
        }
    }
    return result;
}

obj token_iterator_state(token_source) {
    has reader: u64,
        encoding: str | None,
        scanner: tok_state,
        lines: list[str] = [],
        finished: bool = False,
        input_finished: bool = False,
        last_line: str = "",
        last_line_number: int = 0;

    def __iter__ -> token_iterator_state {
        return self;
    }

    def refill -> bool {
        if self.input_finished {
            return False;
        }
        handle = jacpy_readline(
            self.reader, self.encoding or "", i64(0 if self.encoding is None else 1)
        );
        line = bytes(take_buffer(handle)).decode("utf-8", "surrogatepass");
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
        self.scanner.data = self.scanner.source.encode("utf-8");
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
        raise syntax_failure(
            message,
            filename="<string>",
            lineno=lineno,
            offset=offset,
            text=line,
            kind=kind
        );
    }

    def next_token -> native_token | None {
        if self.finished {
            return None;
        }
        item = tokenizer_next(self.scanner);
        report_token_warnings(self.scanner);
        if isinstance(item, tok_diag) {
            line = self.source_line(item.loc.lineno);
            column = _character_column(line, item.loc.col_offset);
            if item.kind in ("IndentationError", "TabError") {
                column = _character_column(
                    line, len(line.rstrip("\r\n").encode("utf-8"))
                );
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
                spelling = self.source_line(start_line).encode("utf-8")[item.col_offset:].decode(
                    "utf-8"
                )
                    + "".join(self.lines[start_line:end_line - 1])
                    + self.source_line(end_line).encode("utf-8")[:item.end_col_offset].decode(
                        "utf-8"
                    );
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
                return None;
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
                    spelling = original.encode("utf-8")[comments[-1][0]:].decode(
                        "utf-8"
                    ).removesuffix(
                        "\n"
                    );
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
        return native_token(
            kind=kind,
            spelling=spelling,
            start_line=start_line,
            start=start,
            end_line=end_line,
            end=end,
            line=line
        );
    }

    def validate_number(spelling: str, lineno: int, column: int) {
        base = spelling[:2].lower();
        description = {"0x": "hexadecimal", "0b": "binary", "0o": "octal"}.get(
            base, "decimal"
        );
        try {
            if base in ("0x", "0b", "0o") {
                parse_integer(spelling);
            } elif spelling.endswith(("j", "J")) {
                parse_float(spelling[:-1]);
            } elif ("." in spelling or "e" in spelling or "E" in spelling) {
                parse_float(spelling);
            } else {
                parse_integer(
                    spelling.lstrip("0") or "0"
                        if self.scanner.extra_tokens
                        else spelling
                );
            }
        } except syntax_failure {
            self.syntax_error(f"invalid {description} literal", lineno, column + 1);
        }
    }
}

def:pub token_iterator(
    reader: u64, encoding: str, decode: bool, extra: bool
) -> token_iterator_state {
    scanner = tok_state(source="", filename="<string>", extra_tokens=extra);
    result = token_iterator_state(
        reader=reader, encoding=encoding if decode else None, scanner=scanner
    );
    scanner.input = result;
    return result;
}

import from jaclang.compiler.backends.py.jacpython.request_result {
    native_result,
    error_packet
}
import from jaclang.compiler.backends.py.jacpython.marshal_writer { marshal_constant }
import from jaclang.runtime.python.objects { PyObj, PyInt, PyStr, PyTuple }
def:pub jacpy_token_next(iterator: token_iterator_state) -> native_result {
    try {
        value = iterator.next_token();
        if value is None {
            return native_result(eof=True);
        }
        start: list[PyObj] = [
            PyInt(t="int", val=value.start_line),
            PyInt(t="int", val=value.start)
        ];
        end: list[PyObj] = [
            PyInt(t="int", val=value.end_line),
            PyInt(t="int", val=value.end)
        ];
        parts: list[PyObj] = [
            PyInt(t="int", val=value.kind),
            PyStr(t="str", val=value.spelling),
            PyTuple(t="tuple", items=start),
            PyTuple(t="tuple", items=end),
            PyStr(t="str", val=value.line)
        ];
        return native_result(packet=marshal_constant(PyTuple(t="tuple", items=parts)));
    } except syntax_failure as error {
        return error_packet(error);
    } except runtime_failure {
        return native_result(runtime_error=True);
    } except Exception as error {
        return error_packet(syntax_failure(str(error), kind="SystemError"));
    }
}

def:pub jacpy_token_close(iterator: token_iterator_state) {
    iterator.scanner.input = None;
    iterator.finished = True;
}
