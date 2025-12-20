"""JacFormatPass for Jaseci Ast.

This is a pass for formatting Jac code.
"""
import from collections { deque }
import jaclang.compiler.passes.tool.doc_ir as doc;
import jaclang.pycore.unitree as uni;
import from jaclang.pycore.passes { Transform }
"""JacFormat Pass format Jac code."""
class JacFormatPass(Transform[(uni.Module, uni.Module)]) {
    def pre_transform(self: JacFormatPass) -> None;
    def _probe_fits(
        self: JacFormatPass,
        <>node: doc.DocType,
        indent_level: int,
        width_remaining: int,
        *,
        max_steps: int = 2000
    ) -> bool;

    def transform(self: JacFormatPass, ir_in: uni.Module) -> uni.Module;
    def format_doc_ir(
        self: JacFormatPass,
        doc_node: (doc.DocType | None) = None,
        indent_level: int = 0,
        width_remaining: (int | None) = None,
        is_broken: bool = False,
        align_spaces: int = 0
    ) -> str;
}
