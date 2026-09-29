import jaclang.compiler.frontend.parser.lexer as na_lexer;

import from .lexer { Lexer }
import from .parser { Parser, parse_expression as _parse_expression }
import from .tokens { CommentData, SrcDiag }
import from jaclang.compiler.frontend.diagnostics { DIAGNOSTICS }
import from jaclang.compiler.passes.context { Alert }
import type from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.srcloc { Span }
import from jaclang.compiler.frontend.unitree { CommentToken, Expr, Module, Source }
import from jaclang.compiler.passes.annex_weave {
    WovenAnnex,
    merge_annex_into,
    prune_generated_imports
}

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
    had_error = finish_parse(
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

def finish_parse(
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
        for comment in module.source.comments {
            ignored = ignore_directive(comment.value);
            if ignored is not None {
                codes = {c.strip() for c in ignored.split(',')};
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

def ignore_directive(text: str) -> (str | None) {
    marker = "jac:ignore[";
    start = text.find("#");
    while start >= 0 {
        pos = start + 1;
        while pos < len(text) and text[pos].isspace() {
            pos += 1;
        }
        if text.startswith(marker, pos) {
            body_start = pos + len(marker);
            body_end = text.find("]", body_start);
            if body_end > body_start {
                return text[body_start:body_end];
            }
        }
        start = text.find("#", start + 1);
    }
    return None;
}

def parse_woven(
    source_str: str,
    file_path: str,
    prog: (JacProgram | None),
    annexes: list[WovenAnnex],
    early_context: str = ""
) -> tuple[Module, bool] {
    import from jaclang.compiler.frontend.host { active_host }
    nat = active_host().native_parse(
        source_str, file_path, prog, annexes, early_context
    );
    if nat is not None {
        return nat;
    }
    (module, had_error) = parse(source_str, file_path, prog=prog);
    if had_error or not annexes {
        return (module, had_error);
    }
    for annex in annexes {
        (a_mod, _a_err) = parse(annex.source, annex.path, prog=prog);
        merge_annex_into(module, a_mod);
    }
    for annex in annexes {
        if annex.consumer {
            prune_generated_imports(module, annex.path, annex.consumer);
        }
    }
    return (module, had_error);
}

def annex_paths(file_path: str) -> list[str] {
    if not file_path.endswith(".jac") {
        return [];
    }
    try {
        import from jaclang.compiler.frontend.host { active_host }
        host = active_host();
        if host.base_file(file_path) is not None {
            return [];
        }
        found = host.annex_files(file_path, ".impl.jac")
            + host.annex_files(file_path, ".test.jac");
    } except Exception {
        return [];
    }
    unique: list[str] = [];
    for path in found {
        if path not in unique {
            unique.append(path);
        }
    }
    return unique;
}

def annex_sources(file_path: str) -> list[WovenAnnex] {
    import from jaclang.compiler.frontend.host { active_host }
    host = active_host();
    out: list[WovenAnnex] = [];
    for pth in annex_paths(file_path) {
        try {
            out.append(WovenAnnex(source=host.read_source(pth), path=pth));
        } except Exception {
            continue;
        }
    }
    try {
        import from jaclang.compiler.driver.wiring { wiring_annex_for }
        wired = wiring_annex_for(file_path);
        if wired is not None {
            out.append(wired);
        }
    } except Exception {}
    return out;
}
