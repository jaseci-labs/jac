import from jaclang.compiler.passes.native.llvm { ir }
import from jaclang.compiler.passes.native.na_ir_gen.state { NaIRGenState }
import from jaclang.jac0core.codeinfo { HDR_ALLOC_ID_OFF, HDR_DTOR_OFF, HDR_TAG_OFF }
import from jaclang.jac0core.constant { Tokens as Tok }
import from jaclang.jac0core.diagnostics { E5092 }
import jaclang.jac0core.unitree as uni;

obj NaIRGenContainerHelpers(NaIRGenState) {
    def _emit_key_comparison(
        b: ir.IRBuilder,
        key_type: ir.Type,
        stored_val: ir.Value,
        search_val: ir.Value,
        key_size: int = 0
    ) -> ir.Value;

    def _elem_kind(elem_type: ir.Type) -> str;
    def _emit_jacval_retain_fn -> ir.Function;
    def _emit_jacval_release_fn -> ir.Function;
    def _emit_jacval_rc_fn(fn_name: str, is_retain: bool) -> ir.Function;
    def _container_managed_fields(layout: dict) -> list;
    def _reject_ptr_into_raw_slot(
        nd: (uni.UniNode | None), value: ir.Value, elem_type: ir.Type, what: str
    ) -> bool;

    def _spread_operand(nd: (uni.UniNode | None)) -> (uni.Expr | None);
    def _container_src_info(val: (ir.Value | None)) -> (dict | None);
    def _spread_elem_storage(
        src_info: dict, operand: (uni.Expr | None)
    ) -> (ir.Type | None);

    def _reject_spread_slot_mismatch(
        nd: (uni.UniNode | None), src_elem: ir.Type, dest_elem: ir.Type, what: str
    ) -> bool;

    def _emit_spread_copy(
        src: ir.Value,
        src_helpers: dict,
        dest: ir.Value,
        dest_helpers: dict,
        dest_kind: str,
        loc: str
    ) -> None;

    def _emit_elem_retain(b: ir.IRBuilder, elem_type: ir.Type, val: ir.Value) -> None;
    def _emit_elem_release(b: ir.IRBuilder, elem_type: ir.Type, val: ir.Value) -> None;
    def _container_layout_dense(data_types: list) -> dict;
    def _container_layout_hash(key_type: ir.Type, val_type: (ir.Type | None)) -> dict;
    def _container_struct_fields(layout: dict) -> list;
    def _emit_live_slot_loop(
        fn: ir.Function,
        b: ir.IRBuilder,
        cont: ir.Value,
        layout: dict,
        tag: str,
        body_cb: object,
        fields: (list | None) = None
    ) -> ir.IRBuilder;

    def _emit_rc_alloc_container(
        b: ir.IRBuilder, container_ptr_type: ir.Type, layout: dict, initial_cap: int = 8
    ) -> tuple;

    def _emit_grow_array(
        b: ir.IRBuilder,
        arr_ptr: ir.Value,
        elem_type: ir.Type,
        cur_len: ir.Value,
        cap_ptr: ir.Value,
        cur_cap: ir.Value
    ) -> ir.Value;

    def _emit_rc_destructor_preamble(
        release_fn: ir.Function, ptr_type: ir.Type
    ) -> tuple;

    def _emit_container_new_fn(
        fn_name: str,
        container_ptr_type: ir.Type,
        layout: dict,
        dtor_fn: (ir.Function | None) = None
    ) -> ir.Function;

    def _emit_container_len_fn(
        fn_name: str, container_ptr_type: ir.Type
    ) -> ir.Function;

    def _emit_container_release_fn(
        fn_name: str, container_ptr_type: ir.Type, layout: dict
    ) -> ir.Function;

    def _emit_release_header_free(
        release_fn: ir.Function, b: ir.IRBuilder, done_bb: ir.Block
    ) -> None;

    def _emit_array_get_fn(
        fn_name: str,
        container_ptr_type: ir.Type,
        elem_type: ir.Type,
        data_field_idx: int
    ) -> ir.Function;

    def _tuple_box_release_fn(
        struct_type: ir.LiteralStructType
    ) -> (ir.Function | None);

    def _tuple_box_trace_fn(struct_type: ir.LiteralStructType) -> (ir.Function | None);
    def _emit_tuple_box_lifecycle(
        raw: ir.Value, struct_type: ir.LiteralStructType
    ) -> None;

    def _container_type_name(dtor_fn: object) -> str;
    def _emit_container_trace_fn(
        trace_fn_name: str, container_ptr_type: ir.Type, layout: dict
    ) -> ir.Function;
}
