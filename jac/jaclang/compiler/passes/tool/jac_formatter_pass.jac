"""JacFormatPass for Jaseci Ast.

This is a pass for formatting Jac code.
"""
import from collections { deque }
import jaclang.compiler.passes.tool.doc_ir as doc;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes { Transform }
"""JacFormat Pass format Jac code."""
obj JacFormatPass(Transform[(uni.Module, uni.Module)]) {
    def init(ir_in: uni.Module, prog: Any, cancel_token: Any = None) -> None;
    def pre_transform -> None;
    def _probe_fits(
        nd: doc.DocType,
        indent_level: int,
        width_remaining: int,
        *,
        max_steps: int = 2000
    ) -> bool;

    def transform(ir_in: uni.Module) -> uni.Module;
    def format_doc_ir(
        doc_node: (doc.DocType | None) = None,
        indent_level: int = 0,
        width_remaining: (int | None) = None,
        is_broken: bool = False,
        align_spaces: int = 0
    ) -> str;
}
