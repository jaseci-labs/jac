import from jaclang.compiler.passes.native.llvm { ir }
import from jaclang.compiler.passes.native.na_ir_gen.state { NaIRGenState }
import jaclang.jac0core.unitree as uni;

obj NaIRGenMath(NaIRGenState) {
    def _codegen_int_pow(base: ir.Value, exp: ir.Value) -> ir.Value;
    def _equalize_int_pow_operands(
        base: ir.Value, exp: ir.Value
    ) -> tuple[(ir.Value, ir.Value)];

    def _emit_float_pow(base: ir.Value, exp: ir.Value) -> ir.Value;
    def _emit_pow_zero_guard(base: ir.Value) -> None;
    def _codegen_pow(
        base: ir.Value, exp: ir.Value, exp_node: (uni.Expr | None) = None
    ) -> ir.Value;

    def _emit_math_call(name: str, nd: uni.FuncCall) -> (ir.Value | None);
    def _emit_math_const(name: str) -> (ir.Value | None);
}
