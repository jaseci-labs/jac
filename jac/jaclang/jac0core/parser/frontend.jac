import jaclang.jac0core.parser.lexer as na_lexer;

import from .lexer { Lexer }
import from .parser { Parser }
import from jaclang.jac0core.codeinfo { CodeLocInfo }
import from jaclang.jac0core.diagnostics { DIAGNOSTICS }
import from jaclang.jac0core.passes.transform { Alert }
import type from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.unitree { CommentToken, Module, Source, Token as UniToken }

glob _NATIVE_SCAN_MEMO: list = [];

def _native_scan -> any {
    if _NATIVE_SCAN_MEMO {
        return _NATIVE_SCAN_MEMO[0];
    }
    fn: any = None;
    try {
        import from jaclang.jac0core.sealed { native_artifact_for }
        found = native_artifact_for("jaclang.jac0core.parser.lexer");
        if found is not None {
            import from jaclang.jac0core.native_dylib { DylibEngine, layout_from_dict }
            import from jaclang.jac0core.native_marshal {
                build_ctypes_classes,
                build_enum_maps,
                wrap_native_function
            }
            (lib_path, layout_dict) = found;
            eng = DylibEngine(lib_path);
            eng.initialize();
            layout = layout_from_dict(layout_dict);
            ns = na_lexer.__dict__;
            cc = build_ctypes_classes(layout);
            em = build_enum_maps(layout, ns);
            pc: dict = {};
            for sn in layout.structs {
                if ns.get(sn) is not None {
                    pc[sn] = ns[sn];
                }
            }
            fl = layout.functions.get("tokenize_full");
            if fl is not None {
                fn = wrap_native_function(eng, fl, cc, em, pc, layout=layout);
                if fn is not None {
                    fn.__jac_engine__ = eng;
                }
            }
        }
    } except Exception {
        fn = None;
    }
    _NATIVE_SCAN_MEMO.append(fn);
    return fn;
}

def parse(
    source: str, file_path: str = "<input>", prog: (JacProgram | None) = None
) -> tuple[Module, bool] {
    _scan = _native_scan();
    if _scan is not None {
        (tokens, comments, diags, lex_error_count) = _scan(source, file_path);
    } else {
        (tokens, comments, diags, lex_error_count) = na_lexer.tokenize_full(
            source, file_path
        );
    }

    if prog is not None and diags {
        diag_src = Source(source, mod_path=file_path);
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
            alrt = Alert(d.message, CodeLocInfo(dtok, dtok), Lexer, code=code);
            if d.is_error {
                prog.errors_had.append(alrt);
            } else {
                prog.warnings_had.append(alrt);
            }
        }
    }
    parser = Parser(tokens=tokens, file_path=file_path, source_code=source, prog=prog);
    module = parser.parse();

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
    had_error = parser.error_count > 0 or lex_error_count > 0;
    return (module, had_error);
}
