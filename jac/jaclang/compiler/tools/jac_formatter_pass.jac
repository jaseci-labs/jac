import from collections { deque }
import jaclang.compiler.tools.doc_ir as doc;
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.diagnostics { W5050, E5051 }
import from jaclang.compiler.passes { Transform }

walker JacFormatPass(Transform) {
    has indent_size: int = 4,
        MAX_LINE_LENGTH: int = 88,
        _probe_cache: dict[tuple[int, int, int], bool] = {},
        _pending_suffixes: list[str] = [],
        _line_has_content: bool = False,
        _rendering_suffix: bool = False;

    def pre_transform -> None;
    def _flush_suffixes -> str;
    def _probe_fits(
        nd: doc.DocType,
        indent_level: int,
        width_remaining: int,
        *,
        max_steps: int = 2000
    ) -> bool;

    def _flat_first_line_width(
        nd: doc.DocType, base: int = 0, is_broken: bool = False
    ) -> int;

    def transform(ir_in: uni.Module) -> uni.Module;
    def _run_impl(ir_in: uni.Module) -> uni.Module;
    can run_walk with uni.Module entry;
    def format_doc_ir(
        doc_node: (doc.DocType | None) = None,
        indent_level: int = 0,
        width_remaining: (int | None) = None,
        is_broken: bool = False,
        align_spaces: int = 0,
        trailing_width: int = 0
    ) -> str;
}

def format_module(mod: uni.Module) -> str {
    import from jaclang.compiler.tools.doc_ir_gen_pass { DocIRGenPass }
    import from jaclang.compiler.driver.pipeline { run_utility, UtilityProduct }
    import from jaclang.compiler.driver.program { JacProgram }
    return run_utility(
        UtilityProduct.FORMAT,
        run_utility(UtilityProduct.DOC, mod, JacProgram()).ir_out,
        JacProgram()
    ).ir_out.gen.jac;
}
