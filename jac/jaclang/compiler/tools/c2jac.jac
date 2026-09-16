"""C-to-Jac conversion through semantic lowering and the shared UniTree unparser."""
import from jaclang.compiler.frontend.c.parser { parse_c }
import from jaclang.compiler.frontend.c.preprocessor { CConfig }
import from jaclang.compiler.frontend.c.semantics { CEmitConfig }
import from jaclang.compiler.frontend.srcloc { Span }
import from jaclang.compiler.frontend.unitree { Module }
import from jaclang.compiler.passes.c_lower_pass { lower_c }
import from jaclang.compiler.passes.context { Alert, PassResult }
import from jaclang.compiler.tools.unparse_pass { unparse_module }

obj CEmitResult(PassResult) {
    has source: str = "",
        module: Module | None = None,
        origins: dict[int, Span] = {};
    has ok: bool { getter { return not self.errors_had; } }
    has diagnostics: list[Alert] {
        getter { return self.errors_had + self.warnings_had; }
    }
}

"""Return Jac source and the lowered Module, without executing generated code."""
def emit_c(source: str, file_path: str = "<c-input>",
           preprocess: CConfig | None = None, config: CEmitConfig | None = None) -> CEmitResult {
    parsed = parse_c(source, file_path, preprocess);
    lowered = lower_c(parsed, config);
    result = CEmitResult();
    result.errors_had = lowered.errors_had;
    result.warnings_had = lowered.warnings_had;
    result.module = lowered.module;
    result.origins = lowered.origins;
    module = lowered.module;
    if lowered.ok and module is not None {
        result.source = unparse_module(module);
    }
    return result;
}
