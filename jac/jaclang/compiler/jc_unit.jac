import time;
import from jaclang.compiler.passes.context { CompileContext }
import from c { def PyList_New(n: int) -> int;  }
import from c { def PyList_SetItem(l: int, i: int, v: int) -> int;  }
import from c { def Py_DecRef(o: int) -> int;  }
import from c { def PyUnicode_FromString(p: int) -> int;  }

import from jaclang.compiler.jc_materialize {
    hint_commentdata,
    hint_srcdiag,
    jc_mz_obj,
    jc_mz_run,
    jc_mz_shape_keys
}

import from jaclang.compiler.frontend.parser.parser { parse_program }
import from jaclang.compiler.frontend.parser.tokens { SrcDiag, CommentData }
import from jaclang.compiler.frontend.unitree { Module, Import }
import from jaclang.compiler.frontend.roles { AccessorsRole, BodyRole, SpecRole }
import from jaclang.compiler.frontend.constant { CodeContext }
import from jaclang.compiler.passes.early_passes { EARLY_PASSES, SymTabBuildPass }
import from jaclang.compiler.passes.context { Alert }
import from jaclang.compiler.passes.annex_weave {
    merge_annex_into,
    prune_generated_imports
}

obj JcState {
    has p_errs: int = 0,
        lex_errs: int = 0,
        mod_h: int = 0,
        diags_h: int = 0,
        lexdiags_h: int = 0,
        comments_h: int = 0,
        early_context: int = 0,
        pass_times: list[float] = [],
        pass_names_h: list[int] = [],
        pass_errors_h: list[int] = [],
        pass_warnings_h: list[int] = [];
}

glob _JC: JcState = JcState(),
     _ANNEXES: list[tuple[str, str, str]] = [];

def:pub jc_probe -> int {
    return 44061;
}

def _drop_h(h: int) {
    if h != 0 {
        Py_DecRef(h);
    }
}

def _clear_results {
    _drop_h(_JC.mod_h);
    _drop_h(_JC.diags_h);
    _drop_h(_JC.lexdiags_h);
    _drop_h(_JC.comments_h);
    for h in _JC.pass_names_h {
        _drop_h(h);
    }
    for h in _JC.pass_errors_h {
        _drop_h(h);
    }
    for h in _JC.pass_warnings_h {
        _drop_h(h);
    }
    _JC.pass_times.clear();
    _JC.pass_names_h.clear();
    _JC.pass_errors_h.clear();
    _JC.pass_warnings_h.clear();
    _JC.mod_h = 0;
    _JC.diags_h = 0;
    _JC.lexdiags_h = 0;
    _JC.comments_h = 0;
    _JC.p_errs = 0;
    _JC.lex_errs = 0;
}

def:pub jc_set_early(context: int) -> int {
    _JC.early_context = context;
    return 0;
}

def:pub jc_completed -> int {
    return len(_JC.pass_times);
}

def:pub jc_pass_time(index: int) -> float {
    return _JC.pass_times[index];
}

def:pub jc_take_pass_name(index: int) -> int {
    h = _JC.pass_names_h[index];
    _JC.pass_names_h[index] = 0;
    return h;
}

def:pub jc_take_pass_alerts(index: int, warnings: int) -> int {
    handles = _JC.pass_warnings_h if warnings != 0 else _JC.pass_errors_h;
    h = handles[index];
    handles[index] = 0;
    return h;
}

def:pub jc_annex(source: str, path: str, consumer: str) -> int {
    _ANNEXES.append((source, path, consumer));
    return 0;
}

def _weave(r: Region, mod: Module) -> int {
    for (source, path, _consumer) in _ANNEXES {
        (a_mod, a_errs, _pd, _cm, _ld, a_lex_errs) = parse_program(source, path);
        if a_errs > 0 or a_lex_errs > 0 {
            return 1;
        }
        merge_annex_into(mod, a_mod);
    }
    for (_source, path, consumer) in _ANNEXES {
        if consumer {
            prune_generated_imports(mod, path, consumer);
        }
    }
    return 0;
}

def _materialize(
    r: Region,
    mod: Module,
    p_diags: list[SrcDiag],
    comments: list[CommentData],
    lex_diags: list[SrcDiag]
) -> int {
    _register_shape_keys();
    out = jc_mz_run(id(mod));
    if out == 0 {
        return 1;
    }
    _JC.mod_h = out;
    _JC.diags_h = _mz_list(p_diags, hint_srcdiag());
    _JC.lexdiags_h = _mz_list(lex_diags, hint_srcdiag());
    _JC.comments_h = _mz_list(comments, hint_commentdata());
    return 0;
}

def _has_absorb_import(mod: Module) -> bool {
    for imp in mod.get_all_sub_nodes(Import) {
        if imp.is_absorb {
            return True;
        }
    }
    return False;
}

def _run_early_passes(mod: Module) -> list[CompileContext] {
    done: list[CompileContext] = [];
    if _JC.early_context == 0 or _JC.p_errs != 0 or _JC.lex_errs != 0 {
        return done;
    }
    if _JC.early_context == 2 {
        mod.set_code_context(CodeContext.CLIENT);
    } elif _JC.early_context == 3 {
        mod.set_code_context(CodeContext.NATIVE);
    }
    for pass_type in EARLY_PASSES {
        if pass_type is SymTabBuildPass and _has_absorb_import(mod) {
            break;
        }
        ctx = CompileContext(
            current_node=mod, from_pass=pass_type, pass_name=pass_type.__name__
        );
        started = time.time();
        mod spawn pass_type(module=mod, ctx=ctx);
        ctx.time_taken = time.time() - started;
        done.append(ctx);
    }
    return done;
}

def _finish_unit(
    r: Region,
    mod: Module,
    p_diags: list[SrcDiag],
    comments: list[CommentData],
    lex_diags: list[SrcDiag]
) -> int {
    done = _run_early_passes(mod);
    status = _materialize(r, mod, p_diags, comments, lex_diags);
    if status != 0 {
        return status;
    }
    tag = _alert_tag();
    for ctx in done {
        _JC.pass_times.append(ctx.time_taken);
        _JC.pass_names_h.append(PyUnicode_FromString(id(ctx.pass_name)));
        _JC.pass_errors_h.append(_mz_list(ctx.errors_had, tag));
        _JC.pass_warnings_h.append(_mz_list(ctx.warnings_had, tag));
    }
    return 0;
}

def _alert_tag -> int {
    import from jaclang.runtime.osp_tag { stable_osp_tag }
    return stable_osp_tag("Alert");
}

def _run_in_region(src: str, path: str) -> int {
    status = 0;
    r = Region();
    in r {
        (mod, p_errs, p_diags, comments, lex_diags, lex_errs) = parse_program(
            src, path
        );
        _JC.p_errs = p_errs;
        _JC.lex_errs = lex_errs;
        if p_errs == 0 and lex_errs == 0 {
            status = _weave(r, mod);
        }
        if status == 0 {
            status = _finish_unit(r, mod, p_diags, comments, lex_diags);
        }
    }
    return status;
}

def:pub jc_run(src: str, path: str) -> int {
    _clear_results();
    status = _run_in_region(src, path);
    _ANNEXES.clear();
    _JC.early_context = 0;
    return status;
}

def:pub jc_take_module -> int {
    h = _JC.mod_h;
    _JC.mod_h = 0;
    return h;
}

def:pub jc_take_diags -> int {
    h = _JC.diags_h;
    _JC.diags_h = 0;
    return h;
}

def:pub jc_take_lexdiags -> int {
    h = _JC.lexdiags_h;
    _JC.lexdiags_h = 0;
    return h;
}

def:pub jc_take_comments -> int {
    h = _JC.comments_h;
    _JC.comments_h = 0;
    return h;
}

def:pub jc_err_count -> int {
    return _JC.p_errs;
}

def:pub jc_lex_errs -> int {
    return _JC.lex_errs;
}

def _mz_list(items: list[any], hint: int) -> int {
    out = PyList_New(len(items));
    i = 0;
    for it in items {
        PyList_SetItem(out, i, jc_mz_obj(id(it), hint));
        i += 1;
    }
    return out;
}

def _register_shape_keys {
    probe: dict[type, str] = {};
    probe[BodyRole] = "one";
    probe[SpecRole] = "one";
    probe[AccessorsRole] = "one";
    jc_mz_shape_keys(id(probe));
}

def:pub jc_rc_debug(v: int) -> int {
    if v != 0 {
        __rc_debug_enable();
    } else {
        __rc_debug_disable();
    }
    return 0;
}
