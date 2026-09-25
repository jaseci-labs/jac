import from collections { deque }

walker JacFormatPass {
    has ctx: CompileContext,
        module: uni.Module,
        indent_size: int = 4,
        MAX_LINE_LENGTH: int = 88,
        _probe_cache: dict[tuple[int, int, int], bool] = {},
        _pending_suffixes: list[str] = [],
        _line_has_content: bool = False,
        _rendering_suffix: bool = False;

    can prepare with entry;
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
    return run_utility(
        UtilityProduct.FORMAT,
        run_utility(UtilityProduct.DOC, mod, JacProgram()).module,
        JacProgram()
    ).module.gen.jac;
}
