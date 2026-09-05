import from jaclang.compiler.backends.native.llvm { ir }
import from jaclang.compiler.backends.native.na_ir_gen.constants {
    LIVE_NODE_NEXT_OFF,
    LIVE_NODE_TAG_OFF,
    LIVE_NODE_USER_OFF,
    RC_BUFFERED_BIT,
    RC_COLOR_PURPLE,
    RC_COLOR_SHIFT
}
import from jaclang.compiler.backends.native.na_ir_gen.state { NaIRGenState }
import from jaclang.compiler.frontend.codeinfo {
    HDR_ALLOC_ID_OFF,
    HDR_DTOR_OFF,
    HDR_MAGIC,
    HDR_MAGIC_SHIFT_BASE,
    HDR_RC_OFF,
    HDR_TAG_OFF,
    HDR_TOTAL,
    JACSTR_DESC_FIELDS,
    RC_SENTINEL,
    STR_LEN_TAG_BIT,
    STR_LEN_TAG_SHIFT
}
import jaclang.compiler.frontend.unitree as uni;

obj NaIRGenRefcount(NaIRGenState) {
    def _emit_jacval_slot_drop_fn(elem_mangle: str) -> (ir.Function | None);
    def _drop_fn_for(mangle: str) -> (ir.Function | None);
    def _drop_spec_for_mangle(mangle: str) -> (tuple | None);
    def _nogc_type_arg_mangles_of_str(m: str) -> list;
    def _gc_mode -> str;
    def _emit_rc_helpers -> None;
    def _emit_str_len_helpers -> None;
    def _emit_str_stamp_and_new -> None;
    def _call_str_len(b: ir.IRBuilder, ptr: ir.Value, name: str = "s.len") -> ir.Value;
    def _call_str_truthy(
        b: ir.IRBuilder, ptr: ir.Value, name: str = "s.truthy"
    ) -> ir.Value;

    def _stamp_str_len(b: ir.IRBuilder, ptr: ir.Value, len_val: ir.Value) -> None;
    def _emit_str_cmp_helper -> None;
    def _call_str_cmp(
        b: ir.IRBuilder, lhs: ir.Value, rhs: ir.Value, name: str = "s.cmp"
    ) -> ir.Value;

    def _emit_str_cmp3_helper -> None;
    def _call_str_cmp3(
        b: ir.IRBuilder,
        l_data: ir.Value,
        l_len: ir.Value,
        r_data: ir.Value,
        r_len: ir.Value,
        name: str = "s.cmp3"
    ) -> ir.Value;

    def _str_cmp_parts_of(val: ir.Value) -> (tuple | None);
    def _emit_str_dup_helper -> None;
    def _call_str_dup(b: ir.IRBuilder, ptr: ir.Value, name: str = "s.dup") -> ir.Value;
    def _emit_str_len_raw_helper -> None;
    def _call_str_len_raw(
        b: ir.IRBuilder, ptr: ir.Value, name: str = "s.rlen"
    ) -> ir.Value;

    def _str_desc_type -> ir.Type;
    def _str_desc_kind -> str;
    def _str_norm(val: ir.Value | None) -> (ir.Value | None);
    def _str_arg(val: ir.Value | None) -> (ir.Value | None);
    def _emit_str_desc_helpers -> None;
    def _membrane_str_out(b: ir.IRBuilder, val: ir.Value) -> ir.Value;
    def _membrane_str_in(b: ir.IRBuilder, val: ir.Value) -> ir.Value;
    def _str_alloc(b: ir.IRBuilder, size: ir.Value, name: str = "s.buf") -> ir.Value;
    def _str_finish(b: ir.IRBuilder, buf: ir.Value, len_val: ir.Value) -> None;
    def _rc_alloc(size: ir.Value, name: str = "rc.alloc") -> ir.Value;
    def _emit_rc_retain(ptr: ir.Value, op: str = "", loc: str = "") -> None;
    def _emit_rc_release_simple(ptr: ir.Value, op: str = "", loc: str = "") -> None;
    def _emit_rc_release_typed(val: ir.Value, op: str = "", loc: str = "") -> None;
    def _arch_is_acyclic(arch_name: str) -> bool;
    def _nogc_osp_skip(val: ir.Value) -> bool;
    def _nogc_headerless -> bool;
    def _nogc_owned_world -> bool;
    def _nogc_opt_slots_owned -> bool;
    def _nogc_drop_op_active(op: str) -> bool;
    def _arch_is_osp_name(arch_name: str) -> bool;
    def _arch_is_walker_name(arch_name: str) -> bool;
    def _emit_struct_drop_fn(type_name: str) -> (ir.Function | None);
    def _emit_nogc_field_drops(
        b: ir.IRBuilder, type_name: str, _dobj: ir.Value
    ) -> None;

    def _emit_container_drop_fn(cont_name: str) -> (ir.Function | None);
    def _nogc_elem_drop_slot_ty -> ir.Type;
    def _nogc_stamp_elem_drops(cont: ir.Value | None, elem_mangles: list) -> None;
    def _rc_unwrap_optional(val: ir.Value) -> ir.Value;
    def _is_move_site(expr: uni.UniNode | None) -> bool;
    def _nogc_consume_local(expr: uni.UniNode | None, owned_only: bool = True) -> bool;
    def _nogc_elem_prep(
        expr: uni.UniNode | None, val: ir.Value | None
    ) -> (ir.Value | None);

    def _nogc_type_arg_mangles(expr: uni.UniNode | None) -> list;
    def _drop_hook_for(type_name: str) -> (ir.Function | None);
    def _nogc_drop_fn_for(
        ptr_ty: ir.PointerType, self_type: str = ""
    ) -> (ir.Function | None);

    def _nogc_emit_drop(val: ir.Value, op: str = "", loc: str = "") -> bool;
    def _nogc_str_free_owned(val: ir.Value) -> None;
    def _nogc_free_scratch(val: ir.Value, op: str) -> None;
    def _emit_set_type_tag(b: ir.IRBuilder, ptr_i8: ir.Value, type_name: str) -> None;
    def _emit_magic_check(
        b: ir.IRBuilder, ptr: ir.Value, name_prefix: str = "mc"
    ) -> ir.Value;

    def _mark_owned(val: ir.Value) -> ir.Value;
    def _is_owned(val: ir.Value) -> bool;
    def _opt_result_owned(val: ir.Value, expr: object) -> bool;
    def _can_native_move_lower(nd: object) -> bool;
    def _release_owned_operands(
        left_orig: ir.Value, right_orig: ir.Value, op: str = ""
    ) -> None;

    def _release_owned_args(call_args: list, op: str = "call_arg") -> None;
    def _rc_call_with_ctx(
        fn: ir.Function, args: list, op: str, loc: str = "", name: str = ""
    ) -> ir.Value;

    def _emit_scope_cleanup(
        skip_var: (str | None) = None, ret_val: object = None, loc: str = ""
    ) -> None;

    def _emit_loop_iter_cleanup(body_locals: list, loc: str = "") -> None;
    def _bind_loop_coll_slot(val: ir.Value) -> (str | None);
    def _release_loop_coll_slot(var_name: str, op: str = "", loc: str = "") -> None;
    def _rc_strdup(ptr: ir.Value, name: str = "rc.str") -> ir.Value;
    def _emit_struct_release_fn(arch_name: str) -> None;
}
