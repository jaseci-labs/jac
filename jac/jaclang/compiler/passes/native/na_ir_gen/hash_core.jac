import from jaclang.compiler.passes.native.llvm { ir }
import from jaclang.compiler.passes.native.na_ir_gen.state { NaIRGenState }
import jaclang.jac0core.unitree as uni;

obj NaIRGenHashCore(NaIRGenState) {
    def _emit_hash_core_helpers(
        family: str,
        type_key: str,
        cont_ptr_type: ir.Type,
        key_type: ir.Type,
        val_type: (ir.Type | None),
        key_type_name: str,
        key_size: int,
        layout: dict
    ) -> dict;

    def _static_str_hash(key: str) -> int;
    def _static_key_hash_of(key_node: (uni.UniNode | None)) -> (int | None);
    def _static_key_op(
        helpers: dict, op: str, key_node: (uni.UniNode | None)
    ) -> tuple;
}
