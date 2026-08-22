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
    had_error = _finish_parse(
        module, p_errs, p_diags, comments, lex_diags, lex_errs, prog
    );
    return (module, had_error);
}

def _finish_parse(
    module: Module,
    p_errs: int,
    p_diags: any,
    comments: any,
    lex_diags: any,
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

def _replay_prefix_rows(rows: any, claimed: tuple, prog: JacProgram, diag_src: Source) {
    import from jaclang.jac0core.compiler {
        deliver_alerts,
        get_ir_gen_sched,
        get_symtab_ir_sched
    }

    pool: dict[str, any] = {};
    for sched in [
        get_ir_gen_sched(gen_mtir=True),
        get_ir_gen_sched(gen_mtir=False),
        get_symtab_ir_sched()
    ] {
        for p in sched {
            pool[p.__name__] = p;
        }
    }
    errs: list = [];
    warns: list = [];
    for rr in rows {
        sev = int(rr[0]);
        code_str = str(rr[1]);
        pass_idx = int(rr[8]);
        rtok = UniToken(
            orig_src=diag_src,
            name="ERROR" if sev else "WARNING",
            value="",
            line=int(rr[4]),
            end_line=int(rr[4]),
            col_start=int(rr[5]),
            col_end=int(rr[5]),
            pos_start=int(rr[6]),
            pos_end=int(rr[7])
        );
        from_pass: any = None;
        if pass_idx >= 0 and pass_idx < len(claimed) {
            from_pass = pool.get(str(claimed[pass_idx]));
        }
        if from_pass is None {
            from_pass = Parser;
        }
        alrt = Alert(
            str(rr[2]),
            CodeLocInfo(rtok, rtok),
            from_pass,
            code=DIAGNOSTICS.get(code_str) if code_str else None,
            help_text=str(rr[3])
        );
        if sev {
            errs.append(alrt);
        } else {
            warns.append(alrt);
        }
    }
    deliver_alerts(errs, warns, prog);
}

def parse_and_run_prefix(
    source_str: str,
    file_path: str,
    prog: (JacProgram | None),
    claimed: tuple,
    facts: any
) -> tuple {
    _np = _native_parse();
    if _np is None or not _np.serves_prefix() {
        raise RuntimeError(
            "parse_and_run_prefix was entered without a prefix-serving "
            "artifact; the flip predicate gates on the bound parser and "
            "must have declined before reaching this entry"
        );
    }
    import from jaclang.jac0core.prefix_flip { PREFIX_IR_GEN_NO_CGEN }
    claimed_t = tuple(claimed or ());
    claimed_n = len(claimed_t) if len(claimed_t) < 6 else 6;
    if list(claimed_t[:claimed_n]) != list(PREFIX_IR_GEN_NO_CGEN[:claimed_n]) {
        (module, had_error) = parse(source_str, file_path, prog=prog);
        return (
            module,
            had_error,
            (),
            "option-shape-unsupported",
            "the claimed schedule does not lead with the sealed prefix order",

        );
    }
    proj_root = facts?.jac_project_root;
    r = _np.parse_and_run_prefix(
        source_str,
        file_path,
        claimed_n,
        str(proj_root) if proj_root is not None else "",
        1 if proj_root is not None else 0,
        1 if facts?.access_enforced else 0
    );
    (module, p_errs, p_diags, comments, lex_diags, lex_errs) = (
        r[0],
        r[1],
        r[2],
        r[3],
        r[4],
        r[5],

    );
    (executed_n, clause, detail, rows) = (int(r[6]), str(r[7]), str(r[8]), r[9], );
    had_error = _finish_parse(
        module, p_errs, p_diags, comments, lex_diags, lex_errs, prog
    );
    if had_error {
        return (module, had_error, (), "prefix-declined", "the source did not parse");
    }
    if prog is not None and rows {
        _replay_prefix_rows(rows, claimed_t, prog, module.source);
    }
    return (module, had_error, tuple(claimed_t[:executed_n]), clause, detail);
}
