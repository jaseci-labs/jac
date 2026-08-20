import from jaclang.compiler.passes.native.llvm { ir }
import from jaclang.compiler.passes.native.na_ir_gen.state { NaIRGenState }
import from jaclang.jac0core.codeinfo { HDR_DTOR_OFF }
import from jaclang.jac0core.diagnostics { E5092 }
import jaclang.jac0core.unitree as uni;

obj NaIRGenIterators(NaIRGenState) {
    def _adapter_callee(fn_expr: uni.UniNode) -> (tuple | None);
    def _adapter_clos_parts(clos: ir.Value) -> (tuple | None);
    def _make_bytes_iter(bytes_val: ir.Value) -> ir.Value;
    def _bytes_iter_next_fn -> ir.Function;
    def _ensure_iter_types -> None;
    def _register_iter_struct(
        name: str, field_names: list[str], field_types: list[ir.Type]
    ) -> None;

    def _alloc_iter_struct(name: str) -> ir.Value;
    def _make_jac_iter(next_fn: ir.Function, state_ptr: ir.Value) -> ir.Value;
    def _emit_iter_advance(
        b: ir.IRBuilder, iter_val: ir.Value, out_ptr: ir.Value
    ) -> ir.Value;

    def _list_iter_next_fn(elem_type_name: str, elem_type: ir.Type) -> ir.Function;
    def _str_iter_next_fn -> ir.Function;
    def _get_char_cache_gv -> ir.Value;
    def _make_list_iter(
        list_val: ir.Value, elem_type_name: str, elem_type: ir.Type
    ) -> ir.Value;

    def _make_str_iter(str_val: ir.Value) -> ir.Value;
    def _dict_iter_next_fn(dict_key: str) -> ir.Function;
    def _make_dict_iter(dict_val: ir.Value, dict_key: str) -> ir.Value;
    def _set_iter_next_fn(elem_type_name: str, elem_type: ir.Type) -> ir.Function;
    def _make_set_iter(
        set_val: ir.Value, elem_type_name: str, elem_type: ir.Type
    ) -> ir.Value;

    def _range_iter_next_fn -> ir.Function;
    def _make_range_iter(range_val: ir.Value) -> ir.Value;
    def _make_iter_from_value(val: ir.Value, expr: uni.UniNode) -> (tuple | None);
    def _build_iter_from_expr(expr: uni.UniNode) -> (tuple | None);
    def _codegen_next(nd: uni.FuncCall) -> (ir.Value | None);
    def _make_map_iter(up: tuple, callee: tuple) -> (tuple | None);
    def _make_filter_iter(up: tuple, callee: tuple) -> (tuple | None);
    def _make_enumerate_iter(up: tuple) -> (tuple | None);
    def _make_zip_iter(up_a: tuple, up_b: tuple) -> (tuple | None);
    def _resolve_method_owner(arch_name: str, method_name: str) -> (str | None);
    def _resolve_method(arch_name: str, method_name: str) -> (ir.Function | None);
    def _arch_implements_iter(arch_name: str) -> bool;
    def _user_iter_next_fn(
        iter_struct: str, next_method_fn: ir.Function, elem_type: ir.Type
    ) -> ir.Function;

    def _make_user_iter(it_obj: ir.Value, iter_struct: str) -> (tuple | None);
    def _make_user_iter_from_obj(
        obj_val: ir.Value, struct_name: str, expr: uni.UniNode
    ) -> (tuple | None);

    def _try_iter_protocol_for(nd: uni.InForStmt) -> bool;
}
