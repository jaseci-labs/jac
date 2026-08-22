import from jaclang.compiler.passes.native.llvm { ir }
import from jaclang.compiler.passes.native.na_ir_gen.state { NaIRGenState }
import jaclang.jac0core.unitree as uni;

obj NaIRGenFileIo(NaIRGenState) {
    def _get_file_struct_type -> ir.Type;
    def _get_binary_file_struct_type -> ir.Type;
    def _register_file_like_struct(name: str) -> ir.Type;
    def _emit_file_helpers -> None;
    def _emit_binary_file_helpers -> None;
    def _emit_file_like_helpers(
        struct_name: str, struct_type: ir.Type, binary: bool
    ) -> None;

    def _emit_open(nd: uni.FuncCall) -> (ir.Value | None);
}
