"""Preprocessing tokens retain physical source locations and macro provenance."""
import from jaclang.compiler.frontend.unitree { Source, Token }

obj CToken {
    has kind: str,
        text: str,
        source: Source,
        start: int,
        end: int,
        line: int,
        column: int,
        end_line: int,
        end_column: int,
        space: bool = False,
        presumed_line: int = 0,
        presumed_path: str = "",
        hidden: set[str] = set(),
        expansion: list[str] = [];

    def as_unitree -> Token {
        return Token(self.source, "C_" + self.kind, self.text,
            self.line, self.end_line, self.column, self.end_column,
            self.start, self.end);
    }

    def copy(text: str = "", kind: str = "") -> CToken {
        return CToken(kind=kind or self.kind, text=text or self.text,
            source=self.source, start=self.start, end=self.end,
            line=self.line, column=self.column, end_line=self.end_line,
            end_column=self.end_column, space=self.space,
            presumed_line=self.presumed_line, presumed_path=self.presumed_path,
            hidden=set(self.hidden), expansion=list(self.expansion));
    }
}

obj CDiagnostic {
    has message: str,
        token: CToken,
        severity: str = "error";

    def __str__ -> str {
        return f"{self.token.source.file_path}:{self.token.line}:{self.token.column}: {self.severity}: {self.message}";
    }
}

obj CLexResult {
    has tokens: list[CToken] = [],
        diagnostics: list[CDiagnostic] = [];
}
