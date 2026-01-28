"""Native LLVM IR generation pass for na {} blocks.

Compiles Jac AST nodes in NATIVE context to LLVM IR using llvmlite.
All code in na {} or .na.jac is guaranteed to compile to native LLVM IR.

Uses manual tree-walking (not the visitor exit_* pattern) because LLVM IR
requires instructions to be emitted into specific basic blocks in order,
which the bottom-up visitor pattern cannot handle for control flow.
"""

import from llvmlite { ir }
import jaclang.pycore.unitree as uni;
import from jaclang.pycore.passes.uni_pass { UniPass }
import from jaclang.pycore.constant { CodeContext, Tokens as Tok }

"""Compile na-context Jac AST to LLVM IR using llvmlite.

Uses manual tree-walking for function bodies to properly handle
control flow basic blocks (if/else, while loops).
"""
obj NaIRGenPass(UniPass) {
    def init(
        ir_in: uni.Module, prog: object, cancel_token: (object | None) = None
    ) -> None;
    # Pass entry / context pruning
    def enter_node(<>node: uni.UniNode) -> None;
    def exit_node(<>node: uni.UniNode) -> None;
    # Module
    def exit_module(<>node: uni.Module) -> None;
    def exit_native_block(<>node: uni.NativeBlock) -> None;
    # Forward declaration
    def before_pass -> None;
    def _forward_declare_functions(module: uni.Module) -> None;
    def _maybe_declare_ability(node: uni.ElementStmt) -> None;
    # Ability (function definition) - manual codegen
    def _codegen_ability(<>node: uni.Ability) -> None;
    # Body / statement codegen
    def _codegen_body(stmts: (list | tuple)) -> None;
    def _codegen_stmt(node: uni.UniNode) -> None;
    def _codegen_return(node: uni.ReturnStmt) -> None;
    def _codegen_if(node: uni.IfStmt) -> None;
    def _codegen_while(node: uni.WhileStmt) -> None;
    def _codegen_assignment(node: uni.Assignment) -> None;
    # Expression codegen
    def _codegen_expr(node: (uni.UniNode | None)) -> (ir.Value | None);
    def _codegen_name(node: uni.Name) -> (ir.Value | None);
    def _codegen_binary(node: uni.BinaryExpr) -> (ir.Value | None);
    def _codegen_compare(node: uni.CompareExpr) -> (ir.Value | None);
    def _codegen_unary(node: uni.UnaryExpr) -> (ir.Value | None);
    def _codegen_call(node: uni.FuncCall) -> (ir.Value | None);
    # Print support
    def _get_printf -> ir.Function;
    def _emit_print(node: uni.FuncCall) -> (ir.Value | None);
    def _get_fmt_string(fmt: str) -> ir.GlobalVariable;
    # Helper methods
    def _resolve_jac_type(type_expr: (uni.UniNode | None)) -> ir.Type;
    def _get_name(node: (uni.UniNode | None)) -> (str | None);
    def _to_bool(val: ir.Value) -> ir.Value;
    def _coerce_type(val: ir.Value, target_type: ir.Type) -> ir.Value;
    def _promote_to_float(
        left: ir.Value, right: ir.Value
    ) -> tuple[(ir.Value, ir.Value)];

    def _emit_binary_op(op: str, left: ir.Value, right: ir.Value) -> (ir.Value | None);
    def _emit_comparison(
        op: str, left: ir.Value, right: ir.Value, is_float: bool
    ) -> (ir.Value | None);
}
