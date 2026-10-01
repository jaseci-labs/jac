import from c { def Py_DecRef(o: int) -> int;  }
import from c { def PyUnicode_FromString(p: int) -> int;  }
import from c { def __jac_region_depth -> int;  }
import from c { def __jac_region_unwind(depth: int) -> None;  }
import from jaclang.compiler.frontend.kernel_analyze {
    ANALYSIS_CRASHED,
    AnalysisReport,
    CompileReport,
    run_kernel_analysis,
    run_kernel_compile
}

obj JcState {
    has analysis_h: int = 0,
        compile_h: int = 0;
}

glob _JC: JcState = JcState();

def _drop_h(h: int) {
    if h != 0 {
        Py_DecRef(h);
    }
}

def _drop_stale_regions {
    if __jac_region_depth() != 0 {
        __jac_region_unwind(0);
    }
}

def _published(previous: int, text: str) -> int {
    _drop_h(previous);
    return PyUnicode_FromString(id(text));
}

def:pub jc_analyze(inputs: str, path: str, source: str, has_source: int) -> int {
    _drop_stale_regions();
    status = ANALYSIS_CRASHED;
    try {
        outcome = run_kernel_analysis(
            inputs, path, source if has_source != 0 else None
        );
        status = outcome.status;
        text = outcome.to_json();
    } except Exception as err {
        text = AnalysisReport(
            status=ANALYSIS_CRASHED, message=f"kernel analysis raised: {err}"
        ).to_json();
    }
    _JC.analysis_h = _published(_JC.analysis_h, text);
    return status;
}

def:pub jc_take_analysis -> int {
    h = _JC.analysis_h;
    _JC.analysis_h = 0;
    return h;
}

def:pub jc_compile(inputs: str, path: str, source: str, has_source: int) -> int {
    _drop_stale_regions();
    status = ANALYSIS_CRASHED;
    try {
        outcome = run_kernel_compile(inputs, path, source if has_source != 0 else None);
        status = outcome.analysis.status;
        text = outcome.to_json();
    } except Exception as err {
        text = CompileReport(
            analysis=AnalysisReport(
                status=ANALYSIS_CRASHED, message=f"kernel compile raised: {err}"
            )
        ).to_json();
    }
    _JC.compile_h = _published(_JC.compile_h, text);
    return status;
}

def:pub jc_take_compile -> int {
    h = _JC.compile_h;
    _JC.compile_h = 0;
    return h;
}
