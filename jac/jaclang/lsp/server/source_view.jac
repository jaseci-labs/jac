import from bisect { bisect_right }
import from jaclang.compiler.frontend.parser.lexer { tokenize_full }
import from jaclang.compiler.frontend.parser.tokens { TokenKind }

obj TextSpan {
    has start: tuple[int, int],
        end: tuple[int, int];
}

obj SourceView {
    has source: str,
        path: str,
        excluded: list[TextSpan] = [],
        starts: list[tuple[int, int]] = [];

    def postinit {
        (tokens, comments, _, _) = tokenize_full(self.source, self.path);
        string_kinds = {
            TokenKind.STRING,
            TokenKind.F_TEXT_DQ,
            TokenKind.F_TEXT_SQ,
            TokenKind.F_TEXT_TDQ,
            TokenKind.F_TEXT_TSQ
        };
        for token in tokens {
            if token.kind in string_kinds {
                loc = token.loc;
                self.excluded.append(
                    TextSpan(
                        (loc.line - 1, loc.col_start - 1),
                        (loc.end_line - 1, loc.col_end - 1)
                    )
                );
            }
        }
        for comment in comments {
            self.excluded.append(
                TextSpan(
                    (comment.line - 1, comment.col_start - 1),
                    (comment.end_line - 1, comment.col_end - 1)
                )
            );
        }
        self.excluded.sort(
            key=lambda (span: TextSpan) -> tuple[int, int] { return span.start; }
        );
        self.starts = [span.start for span in self.excluded];
    }

    def excludes(line: int, character: int) -> bool {
        position = (line, character);
        index = bisect_right(self.starts, position) - 1;
        return index >= 0 and position < self.excluded[index].end;
    }
}
