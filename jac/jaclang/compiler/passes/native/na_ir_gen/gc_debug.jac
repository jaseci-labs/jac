import from jaclang.compiler.passes.native.llvm { ir }
import from jaclang.compiler.passes.native.na_ir_gen.constants {
    LIVE_NODE_NEXT_OFF,
    LIVE_NODE_RC_OFF,
    LIVE_NODE_SIZE,
    LIVE_NODE_TAG_OFF,
    LIVE_NODE_USER_OFF
}
import from jaclang.compiler.passes.native.na_ir_gen.state { NaIRGenState }
import from jaclang.jac0core.codeinfo { HDR_ALLOC_ID_OFF, HDR_RC_OFF, HDR_TAG_OFF }

obj NaIRGenGcDebug(NaIRGenState) {
    def _set_rc_ctx(op: str, loc: str) -> None;
    def _clear_rc_ctx -> None;
    def _emit_live_list_remove(
        b: object,
        target_ptr: object,
        i8_ptr: object,
        i64_ptr: object,
        done_bb: object,
        free_bb: object
    ) -> None;

    def _emit_rc_live_dump -> None;
    def _emit_rc_debug_globals -> None;
    def _emit_ctx_load(b: ir.IRBuilder) -> tuple;
    def _emit_live_node_insert(
        b: ir.IRBuilder, aid: ir.Value, user: ir.Value, tag_raw: ir.Value
    ) -> None;

    def _emit_alloc_log_bb(
        func: ir.Function,
        ret_bb: ir.Block,
        aid: ir.Value,
        user: ir.Value,
        size_arg: ir.Value,
        tag_raw: ir.Value
    ) -> ir.Block;

    def _emit_retain_log_bb(
        func: ir.Function,
        done_bb: ir.Block,
        ptr: ir.Value,
        old_rc: ir.Value,
        new_rc: ir.Value
    ) -> ir.Block;

    def _emit_dbl_free_log_bb(
        func: ir.Function, done_bb: ir.Block, ptr: ir.Value
    ) -> ir.Block;

    def _emit_release_log_bb(
        func: ir.Function,
        done_bb: ir.Block,
        ptr: ir.Value,
        old_rc: ir.Value,
        new_rc: ir.Value
    ) -> ir.Block;

    def _emit_raw_free_bbs(
        func: ir.Function, done_bb: ir.Block, ptr: ir.Value
    ) -> ir.Block;

    def _emit_struct_free_log(
        func: ir.Function,
        log_free_struct_bb: ir.Block,
        actual_free_struct_bb: ir.Block,
        obj_i8: ir.Value,
        obj_raw: ir.Value,
        aid: ir.Value,
        tag: ir.Value
    ) -> None;
}
