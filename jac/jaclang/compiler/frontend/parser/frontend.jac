import jaclang.compiler.frontend.parser.lexer as na_lexer;

import from .lexer { Lexer }
import from .parser { Parser, parse_expression as _parse_expression }
import from .tokens { CommentData, SrcDiag }
import from jaclang.compiler.frontend.diagnostics { DIAGNOSTICS }
import from jaclang.compiler.passes.transform { Alert }
import type from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.srcloc { Span }
import from jaclang.compiler.frontend.unitree { CommentToken, Expr, Module, Source }

def _replay_diags(
    diags: list[SrcDiag], from_pass: type, prog: JacProgram, diag_src: Source
) {
    for d in diags {
        loc = d.loc;
        span = Span.make(
            diag_src.file_path,
            diag_src.code,
            (loc.line, loc.end_line),
            (loc.col_start, loc.col_end),
            (loc.pos_start, loc.pos_end)
        );
        code = DIAGNOSTICS.get(d.code_str) if d.code_str else None;
        help_text = d.help or None;
        alrt = Alert(d.message, span, from_pass, code=code, help_text=help_text);
        if d.is_error {
            prog.errors_had.append(alrt);
        } else {
            prog.warnings_had.append(alrt);
        }
    }
}

def parse_diags(
    source: str, file_path: str = "<input>"
) -> tuple[bool, list[SrcDiag], list[SrcDiag]] {
    (tokens, _comments, lex_diags, lex_errs) = na_lexer.tokenize_full(
        source, file_path
    );
    parser = Parser(tokens=tokens, file_path=file_path, source_code=source);
    parser.parse();
    return (parser.error_count > 0 or lex_errs > 0, parser.diags, lex_diags, );
}


def parse(
    source: str, file_path: str = "<input>", prog: (JacProgram | None) = None
) -> tuple[Module, bool] {
    (tokens, comments, lex_diags, lex_errs) = na_lexer.tokenize_full(source, file_path);
    parser = Parser(tokens=tokens, file_path=file_path, source_code=source);
    module = parser.parse();
    had_error = _finish_parse(
        module, parser.error_count, parser.diags, comments, lex_diags, lex_errs, prog
    );
    return (module, had_error);
}

def parse_expression(
    source: str, file_path: str = "<input>", prog: JacProgram | None = None
) -> tuple[Expr, bool] {
    (expression, had_error, parser_diags, lex_diags) = _parse_expression(
        source, file_path
    );
    if prog is not None {
        _replay_diags(lex_diags, Lexer, prog, expression.loc.orig_src);
        _replay_diags(parser_diags, Parser, prog, expression.loc.orig_src);
    }
    return (expression, had_error);
}


def _finish_parse(
    module: Module,
    p_errs: int,
    p_diags: list[SrcDiag],
    comments: list[CommentData],
    lex_diags: list[SrcDiag],
    lex_errs: int,
    prog: (JacProgram | None)
) -> bool {
    diag_src: Source | None = None;
    if prog is not None and lex_diags {
        diag_src = module.source;
        _replay_diags(lex_diags, Lexer, prog, diag_src);
    }
    if prog is not None and p_diags {
        if diag_src is None {
            diag_src = module.source;
        }
        _replay_diags(p_diags, Parser, prog, diag_src);
    }
    if module.source and comments {
        for cdata in comments {
            ct = CommentToken(
                orig_src=module.source,
                name="COMMENT",
                value=cdata.value,
                line=cdata.line,
                end_line=cdata.end_line,
                col_start=cdata.col_start,
                col_end=cdata.col_end,
                pos_start=cdata.pos_start,
                pos_end=cdata.pos_end,
                kid=[]
            );
            module.source.comments.append(ct);
        }
    }

    if module.source {
        import re;
        ignore_pattern = re.compile(r'#\s*jac:ignore\[([^\]]+)\]');
        for comment in module.source.comments {
            m = ignore_pattern.search(comment.value);
            if m {
                codes = {c.strip() for c in m.group(1).split(',')};
                line = comment.line_no;
                if line in module.source.inline_suppressions {
                    module.source.inline_suppressions[line].update(codes);
                } else {
                    module.source.inline_suppressions[line] = codes;
                }
            }
        }
    }
    return p_errs > 0 or lex_errs > 0;
}

def _native_parse_woven(
    source_str: str,
    file_path: str,
    prog: (JacProgram | None),
    annexes: list,
    early_context: str = ""
) -> (tuple | None) {
    import jaclang.compiler.native_compiler as _jc;
    kernel = _jc.ensure_loaded();
    if kernel is None {
        return None;
    }
    kernel.prepare_early(early_context if prog is not None else "");
    for (a_src, a_path) in annexes {
        kernel.annex(a_src, a_path);
    }
    if kernel.run(source_str, file_path) != 0 {
        return None;
    }
    module = kernel.take_module();
    if module is None {
        return None;
    }
    p_errs = kernel.err_count();
    lex_errs = kernel.lex_errs();
    p_diags = kernel.take_diags();
    lex_diags = kernel.take_lexdiags();
    comments = kernel.take_comments();
    had_error = _finish_parse(
        module, p_errs, p_diags, comments, lex_diags, lex_errs, prog
    );
    if prog is not None {
        results = kernel.take_pass_results();
        if results {
            prog.analysis.record_early(module, results);
        }
    }
    return (module, had_error);
}

def parse_woven(
    source_str: str,
    file_path: str,
    prog: (JacProgram | None),
    annexes: list,
    early_context: str = ""
) -> tuple {
    nat = _native_parse_woven(source_str, file_path, prog, annexes, early_context);
    if nat is not None {
        return nat;
    }
    (module, had_error) = parse(source_str, file_path, prog=prog);
    if had_error or not annexes {
        return (module, had_error);
    }
    import from jaclang.compiler.passes.annex_weave { merge_annex_into }
    for (a_src, a_path) in annexes {
        (a_mod, _a_err) = parse(a_src, a_path, prog=prog);
        merge_annex_into(module, a_mod);
    }
    return (module, had_error);
}

def annex_sources(file_path: str) -> list[tuple[str, str]] {
    if not file_path.endswith(".jac") {
        return [];
    }
    try {
        import from jaclang.compiler.driver.bccache {
            discover_annex_files,
            discover_base_file
        }
        import from jaclang.compiler.frontend.helpers { read_file_with_encoding }
        if discover_base_file(file_path) is not None {
            return [];
        }
        paths = [
            *discover_annex_files(file_path, ".impl.jac"),
            *discover_annex_files(file_path, ".test.jac")
        ];
    } except Exception {
        return [];
    }
    out: list[tuple[str, str]] = [];
    seen: set[str] = set();
    for pth in paths {
        if pth in seen {
            continue;
        }
        seen.add(pth);
        try {
            out.append((read_file_with_encoding(pth), pth, ));
        } except Exception {
            continue;
        }
    }
    return out;
}
