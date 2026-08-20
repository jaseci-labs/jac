import from jaclang.compiler.passes.native.llvm { ir }
import from jaclang.compiler.passes.native.na_ir_gen.state { NaIRGenState }
import from jaclang.jac0core.codeinfo {
    HDR_ALLOC_ID_OFF,
    HDR_DTOR_OFF,
    HDR_MAGIC,
    HDR_MAGIC_SHIFT_BASE,
    HDR_RC_OFF,
    HDR_TAG_OFF,
    HDR_TOTAL,
    RC_SENTINEL
}
import jaclang.jac0core.unitree as uni;

obj NaIRGenArena(NaIRGenState) {
    def _try_partition_sugar_assign(nd: uni.Assignment) -> bool;
    def _emit_struct_drop_fields_fn(type_name: str) -> (ir.Function | None);
    def _emit_arena_helpers -> None;
    def _register_region_handle_var(nd: uni.Assignment, var_name: str) -> None;
    def _region_alloc(size: ir.Value, name: str = "region.alloc") -> ir.Value;
    def _region_log_dtor_if_needed(obj_i8: ir.Value, type_name: str) -> None;
    def _emit_region_handle_drop(alloca: object, var_name: str) -> None;
    def _open_anon_region(gidx: int) -> None;
    def _close_anon_region(gidx: int) -> None;
}
