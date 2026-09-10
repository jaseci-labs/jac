"""Typed transport for one completed native frontend request.

The module and diagnostics belong to the same materialization operation, so
diagnostic locations refer to nodes in the returned module. This transport is
distinct from the immutable semantic publication owned by later phases.
"""

import from jaclang.compiler.frontend.unitree { Module }
import from jaclang.compiler.frontend.parser.tokens { SrcDiag, CommentData }
import from jaclang.compiler.passes.transform { PassResult }

glob FRONTEND_ABI: int = 2;

obj EarlyPassResult(PassResult) {
    has name: str;
}

obj FrontendResult {
    has module: Module,
        parse_errors: int,
        lex_errors: int,
        diagnostics: list[SrcDiag],
        lex_diagnostics: list[SrcDiag],
        comments: list[CommentData],
        annexes: list[FrontendResult] = [],
        passes: list[EarlyPassResult] = [];

    def has_errors -> bool {
        if self.parse_errors != 0 or self.lex_errors != 0 {
            return True;
        }
        for annex in self.annexes {
            if annex.has_errors() {
                return True;
            }
        }
        return False;
    }
}
