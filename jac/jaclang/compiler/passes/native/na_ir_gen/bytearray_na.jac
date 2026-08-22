import from jaclang.compiler.passes.native.llvm { ir }
import from jaclang.compiler.passes.native.na_ir_gen.state { NaIRGenState }
import from jaclang.jac0core.diagnostics { E5092 }
import jaclang.jac0core.unitree as uni;

obj NaIRGenBytearrayNa(NaIRGenState) {
    def _ensure_bytearray_type -> ir.Type;
    def _bytearray_runtime_fns -> dict;
    def _bytearray_src_of(val: ir.Value) -> (tuple | None);
    def _dispatch_bytearray_method(
        method_name: str, recv: ir.Value, nd: uni.FuncCall
    ) -> (ir.Value | None);

    def _emit_struct_pack_into(
        nd: uni.FuncCall,
        params: list,
        fields: list[tuple[str, int, bool]],
        total: int,
        little: bool
    ) -> (ir.Value | None);
}
