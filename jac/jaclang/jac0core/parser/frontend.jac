import jaclang.jac0core.parser.lexer as na_lexer;

import from .lexer { Lexer }
import from .parser { Parser }
import from jaclang.jac0core.codeinfo { CodeLocInfo }
import from jaclang.jac0core.diagnostics { DIAGNOSTICS }
import from jaclang.jac0core.passes.transform { Alert }
import type from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.unitree { CommentToken, Module, Source, Token as UniToken }

glob _NATIVE_PARSE_MEMO: list = [];

def _native_parse -> any {
    import from jaclang.jac0core.native_brands { ensure_native_brands_bound }
    return ensure_native_brands_bound("frontend:_native_parse");
}

def _bind_native_parser_once -> any {
    if _NATIVE_PARSE_MEMO {
        return _NATIVE_PARSE_MEMO[0];
    }
    import from jaclang.jac0core.sealed { native_artifact_for }
    found = native_artifact_for("jaclang.compiler.native_materialize");
    if found is None {
        _NATIVE_PARSE_MEMO.append(None);
        return None;
    }
    import from jaclang.jac0core.parser.materialize { bind_native_parser }
    lib_path: str = found[0];
    layout_dict: dict[str, any] = found[1];
    np = bind_native_parser(lib_path, layout_dict);
    _NATIVE_PARSE_MEMO.append(np);
    return np;
}

def _require_bootstrap_tier(op: str) {
    import from jaclang.jac0core.sealed { native_tier_required }
    if native_tier_required() {
        raise RuntimeError(
            f"{op}: this sealed image declares native parser roots, but the "
            "bytecode parser was reached. The install is broken; reinstall "
            "or rebuild the payload."
        );
    }
}


def _replay_diags(diags: any, from_pass: type, prog: JacProgram, diag_src: Source) {
    for d in diags {
        loc = d.loc;
        dtok = UniToken(
            orig_src=diag_src,
            name="ERROR" if d.is_error else "WARNING",
            value="",
            line=loc.line,
            end_line=loc.end_line,
            col_start=loc.col_start,
            col_end=loc.col_end,
            pos_start=loc.pos_start,
            pos_end=loc.pos_end
        );
        code = DIAGNOSTICS.get(d.code_str) if d.code_str else None;
        help_text = getattr(d, "help", "");
        alrt = Alert(
            d.message,
            CodeLocInfo(dtok, dtok),
            from_pass,
            code=code,
            help_text=help_text
        );
        if d.is_error {
            prog.errors_had.append(alrt);
        } else {
            prog.warnings_had.append(alrt);
        }
    }
}

def parse_diags(source: str, file_path: str = "<input>") -> tuple[(bool, list, list)] {
    _np = _native_parse();
    if _np is not None {
        (p_errs, lex_errs, p_diags, lex_diags) = _np.parse_diags(source, file_path);
        return (p_errs > 0 or lex_errs > 0, list(p_diags), list(lex_diags));
    }
    _require_bootstrap_tier("parse_diags");
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
    _np = _native_parse();
    if _np is not None {
        (module, p_errs, p_diags, comments, lex_diags, lex_errs) = _np.parse(
            source, file_path
        );
    } else {
        _require_bootstrap_tier("parse");
        (tokens, comments, lex_diags, lex_errs) = na_lexer.tokenize_full(
            source, file_path
        );
        parser = Parser(tokens=tokens, file_path=file_path, source_code=source);
        module = parser.parse();
        p_errs = parser.error_count;
        p_diags = parser.diags;
    }

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
    had_error = p_errs > 0 or lex_errs > 0;
    return (module, had_error);
}
