import jaclang.jac0core.parser.lexer as na_lexer;

import from .lexer { Lexer }
import from .parser { Parser }
import from jaclang.jac0core.codeinfo { CodeLocInfo }
import from jaclang.jac0core.diagnostics { DIAGNOSTICS }
import from jaclang.jac0core.passes.transform { Alert }
import type from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.unitree { CommentToken, Module, Source, Token as UniToken }

glob _NATIVE_PARSE_MEMO: list[any] = [];

def _native_parse -> any {
    if _NATIVE_PARSE_MEMO {
        return _NATIVE_PARSE_MEMO[0];
    }
    fn: any = None;
    try {
        import from jaclang.jac0core.sealed { native_artifact_for }
        found = native_artifact_for("jaclang.jac0core.parser.parser");
        if found is not None {
            import jaclang.jac0core.parser.parser as na_parser;
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
            ns = na_parser.__dict__;
            cc = build_ctypes_classes(layout);
            em = build_enum_maps(layout, ns);

            import jaclang.jac0core.unitree as _sc_unitree;
            import jaclang.jac0core.srcloc as _sc_srcloc;
            pc: dict[str, any] = {};
            for sn in layout.structs {
                for _sc_ns in (ns, _sc_unitree.__dict__, _sc_srcloc.__dict__) {
                    if _sc_ns.get(sn) is not None {
                        pc[sn] = _sc_ns[sn];
                        break;
                    }
                }
            }
            fl = layout.functions.get("parse_program");
            if fl is not None {
                fn = wrap_native_function(eng, fl, cc, em, pc, layout=layout);
                if fn is not None {
                    fn.__jac_engine__ = eng;
                }
            }
            if fn is not None and not _canary_ok(fn) {
                fn = None;
            }
        }
    } except Exception {
        fn = None;
    }
    _NATIVE_PARSE_MEMO.append(fn);
    return fn;
}


glob _CANARY_LINES: tuple[str, ...] = (
         "import os;",
         "glob G: int = 42, H: str = 'control-flow harness (Branch 4)';",
         "enum E { A = 1, B = 2 }",
         "obj Canary {",
         "    has a: int = 0, b: (str | None) = None, c: list[int] = [];",
         "    def m(p: int = 3) -> int;",
         "}",
         "impl Canary.m(p: int = 3) -> int {",
         "    if p > 1 and p < 10 or not p {",
         "        for i in range(p) {",
         "            self.a += i * 2 - 1;",
         "        }",
         "    } elif p == 0 {",
         "        while self.a {",
         "            self.a -= 1;",
         "        }",
         "    } else {",
         "        try {",
         "            self.b = f'v={p} w={self.a}';",
         "        } except Exception as e {",
         "            raise;",
         "        }",
         "    }",
         "    return self.a if self.a else -1;",
         "}",
         "test \"canary t\" { assert Canary(a=5).m(2) >= -1; }",
         "with entry { print({'k': [1, 2.5, True, None]}); }",

     );

def _canary_src -> str {
    nl = chr(10);
    return nl.join(list(_CANARY_LINES));
}


def _canary_ok(fn: any) -> bool {
    import from jaclang.compiler.passes.tool.unparse_pass { unparse_node }
    try {
        r = fn(_canary_src(), "__seal_selfcheck__.jac");
        native_mod = r[0];
        (tokens, _c, _ld, _le) = na_lexer.tokenize_full(
            _canary_src(), "__seal_selfcheck__.jac"
        );
        pyp = Parser(
            tokens=tokens, file_path="__seal_selfcheck__.jac", source_code=_canary_src()
        );
        py_mod = pyp.parse();
        return (
            r[1] == pyp.error_count
            and len(native_mod._in_mod_nodes) == len(py_mod._in_mod_nodes)
            and unparse_node(native_mod) == unparse_node(py_mod)
        );
    } except Exception {
        return False;
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

def parse_diags(
    source: str, file_path: str = "<input>"
) -> tuple[(bool, list[any], list[any])] {
    _np = _native_parse();
    if _np is not None {
        (_mod, p_errs, p_diags, _comments, lex_diags, lex_errs) = _np(
            source, file_path
        );
        return (p_errs > 0 or lex_errs > 0, list(p_diags), list(lex_diags));
    }
    (tokens, _comments, lex_diags, lex_errs) = na_lexer.tokenize_full(
        source, file_path
    );
    parser = Parser(tokens=tokens, file_path=file_path, source_code=source);
    parser.parse();
    return (parser.error_count > 0 or lex_errs > 0, parser.diags, lex_diags, );
}


def parse(
    source: str,
    file_path: str = "<input>",
    prog: (JacProgram | None) = None,
    expand: bool = True
) -> tuple[Module, bool] {
    import os as _fe_os;
    _np = _native_parse() if _fe_os.environ.get("JAC_NATIVE_PARSE_TREES") else None;
    if _np is not None {
        (module, p_errs, p_diags, comments, lex_diags, lex_errs) = _np(
            source, file_path
        );
    } else {
        (tokens, comments, lex_diags, lex_errs) = na_lexer.tokenize_full(
            source, file_path
        );
        parser = Parser(tokens=tokens, file_path=file_path, source_code=source);
        module = parser.parse();
        p_errs = parser.error_count;
        p_diags = parser.diags;
    }

    ct_errs: list[tuple[int, int, int, int, str]] = [];
    if expand and p_errs == 0 and lex_errs == 0 {
        import from jaclang.jac0core.ct_expand { expand_module, module_has_ct }
        if module_has_ct(module) {
            ct_errs = expand_module(module, file_path);
        }
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
    if ct_errs {
        if diag_src is None {
            diag_src = module.source;
        }
        for d in ct_errs {
            dtok = UniToken(
                orig_src=diag_src,
                name="ERROR",
                value="",
                line=d[0],
                end_line=max(d[1], d[0]),
                col_start=d[2],
                col_end=max(d[3], d[2]),
                pos_start=0,
                pos_end=0
            );
            alrt = Alert(
                d[4], CodeLocInfo(dtok, dtok), Parser, code=DIAGNOSTICS.get("E0108")
            );
            if prog is not None {
                prog.errors_had.append(alrt);
            }
        }
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
    had_error = p_errs > 0 or lex_errs > 0 or len(ct_errs) > 0;
    return (module, had_error);
}
