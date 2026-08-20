import from jaclang.compiler.passes.native.llvm { ir }
import from jaclang.compiler.passes.native.na_ir_gen.state { NaIRGenState }
import from jaclang.jac0core.constant { OwnershipKind }
import from jaclang.jac0core.constant { Tokens as Tok }
import from jaclang.jac0core.diagnostics { E5092 }
import jaclang.jac0core.unitree as uni;

obj NaIRGenExpr(NaIRGenState) {
    def _codegen_expr(nd: (uni.UniNode | None)) -> (ir.Value | None);
    def _codegen_required(nd: (uni.UniNode | None)) -> (ir.Value | None);
    def _current_fn_key -> (str | None);
    def _mark_local_unlowered(name: str) -> None;
    def _reads_unlowered_local(nd: uni.UniNode) -> bool;
    def _codegen_name(nd: uni.Name) -> (ir.Value | None);
    def _codegen_binary(nd: uni.BinaryExpr) -> (ir.Value | None);
    def _codegen_pipe_fwd(nd: uni.BinaryExpr) -> (ir.Value | None);
    def _codegen_walrus(nd: uni.BinaryExpr) -> (ir.Value | None);
    def _codegen_compare(nd: uni.CompareExpr) -> (ir.Value | None);
    def _codegen_compare_chain(
        nd: uni.CompareExpr, left: ir.Value
    ) -> (ir.Value | None);

    def _codegen_compare_link(
        op: str,
        left: ir.Value,
        right: ir.Value,
        left_node: uni.UniNode,
        right_node: uni.UniNode,
        release_operands: bool = True
    ) -> (ir.Value | None);

    def _identity_over_optional(
        left: ir.Value, right: ir.Value, negate: bool
    ) -> (ir.Value | None);

    def _codegen_unary(nd: uni.UnaryExpr) -> (ir.Value | None);
    def _codegen_yield(nd: uni.YieldExpr) -> (ir.Value | None);
    def _codegen_yield_from(nd: uni.YieldExpr) -> (ir.Value | None);
    def _emit_yield_suspend(v: ir.Value) -> None;
    def _codegen_lambda(nd: uni.LambdaExpr) -> (ir.Value | None);
    def _codegen_atom_trailer(nd: uni.AtomTrailer) -> (ir.Value | None);
    def _codegen_bool_expr(nd: uni.BoolExpr) -> (ir.Value | None);
    def _bool_expr_unify_type(a: ir.Type, b: ir.Type) -> (ir.Type | None);
    def _codegen_if_else_expr(nd: uni.IfElseExpr) -> (ir.Value | None);
    def _codegen_spawn(nd: uni.BinaryExpr) -> (ir.Value | None);
    def _codegen_kernel_spawn(
        walker_name: str, walker_val: ir.Value, loc_val: ir.Value
    ) -> (ir.Value | None);

    def _spawn_operand_name(nd: uni.UniNode) -> (str | None);
    def _is_walker_arch(name: str) -> bool;
    def _infer_dict_type(val: ir.Value) -> (tuple | None);
}
