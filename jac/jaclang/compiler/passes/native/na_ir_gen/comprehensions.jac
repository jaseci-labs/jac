import from jaclang.compiler.passes.native.llvm { ir }
import from jaclang.compiler.passes.native.na_ir_gen.state { NaIRGenState }
import from jaclang.jac0core.diagnostics { E5092 }
import jaclang.jac0core.unitree as uni;
import os;

obj NaIRGenComprehensions(NaIRGenState) {
    def _codegen_list_compr(nd: uni.ListCompr) -> (ir.Value | None);
    def _codegen_dict_compr(nd: uni.DictCompr) -> (ir.Value | None);
    def _codegen_set_compr(nd: uni.SetCompr) -> (ir.Value | None);
    def _emit_compr_element(
        kind: str,
        acc: ir.Value,
        key_expr: uni.UniNode,
        val_expr: (uni.UniNode | None),
        spec: str
    ) -> None;

    def _codegen_compr_walk(
        comprs: list,
        idx: int,
        kind: str,
        acc: ir.Value,
        key_expr: uni.UniNode,
        val_expr: (uni.UniNode | None),
        spec: str
    ) -> None;

    def _codegen_compr_range_walk(
        inner: uni.InnerCompr,
        comprs: list,
        idx: int,
        kind: str,
        acc: ir.Value,
        key_expr: uni.UniNode,
        val_expr: (uni.UniNode | None),
        spec: str,
        conditionals: list
    ) -> None;
}
