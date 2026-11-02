import time;
import from c { def PyList_New(n: int) -> int;  }
import from c { def PyList_SetItem(l: int, i: int, v: int) -> int;  }
import from c { def Py_DecRef(o: int) -> int;  }
import from c { def PyUnicode_FromString(p: int) -> int;  }
import from c { def __jac_region_depth -> int;  }
import from c { def __jac_region_unwind(depth: int) -> None;  }


obj JcState {
    has p_errs: int = 0,
        lex_errs: int = 0,
        mod_h: int = 0,
        diags_h: int = 0,
        lexdiags_h: int = 0,
        comments_h: int = 0,
        analysis_h: int = 0,
        compile_h: int = 0,
        early_context: int = 0,
        pass_times: list[float] = [],
        pass_names_h: list[int] = [],
        pass_errors_h: list[int] = [],
        pass_warnings_h: list[int] = [];
}

glob _JC: JcState = JcState(),
     _ANNEXES: list[tuple[str, str]] = [];

def:pub jc_probe -> int;

def:pub jc_set_asker(callback: int) -> int;

def:pub jc_answer(text: str) -> int;

def _drop_h(h: int);

def _clear_results;

def:pub jc_set_early(context: int) -> int;

def:pub jc_completed -> int;

def:pub jc_pass_time(index: int) -> float;

def:pub jc_take_pass_name(index: int) -> int;

def:pub jc_take_pass_alerts(index: int, warnings: int) -> int;

def:pub jc_annex(source: str, path: str) -> int;

def _weave(r: Region, mod: Module) -> int;

def _materialize(
    r: Region,
    mod: Module,
    p_diags: list[SrcDiag],
    comments: list[CommentData],
    lex_diags: list[SrcDiag]
) -> int;

def _has_absorb_import(mod: Module) -> bool;

def _run_early_passes(mod: Module) -> list[CompileContext];

def _finish_unit(
    r: Region,
    mod: Module,
    p_diags: list[SrcDiag],
    comments: list[CommentData],
    lex_diags: list[SrcDiag]
) -> int;

def _alert_tag -> int;

def _run_in_region(src: str, path: str) -> int;

def _drop_stale_regions;

def:pub jc_run(src: str, path: str) -> int;

def:pub jc_take_module -> int;

def:pub jc_take_diags -> int;

def:pub jc_take_lexdiags -> int;

def:pub jc_take_comments -> int;

def:pub jc_err_count -> int;

def:pub jc_lex_errs -> int;

def _mz_list(items: list[any], hint: int) -> int;

def _register_shape_keys;

def:pub jc_analyze(inputs: str, path: str, source: str, has_source: int) -> int;

def:pub jc_compile(inputs: str, path: str, source: str, has_source: int) -> int;

def:pub jc_take_compile -> int;

def:pub jc_take_analysis -> int;

def:pub jc_rc_debug(v: int) -> int;
