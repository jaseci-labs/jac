import from jaclang.compiler.backends.native.llvm { binding as llvm }
import from jaclang.compiler.backends.native.llvm { ir }
import from jaclang.compiler.backends.native.na_ir_gen.state { NaIRGenState }
import from jaclang.compiler.frontend.constant { OwnershipKind }
import from jaclang.compiler.frontend.constant { Tokens as Tok }
import from jaclang.compiler.frontend.diagnostics { E5090, E5092 }
import jaclang.compiler.frontend.unitree as uni;

obj NaIRGenTypes(NaIRGenState) {
    def _jac_optional_type(payload: ir.Type) -> ir.Type;
    def _opt_payload_of(t: ir.Type) -> (ir.Type | None);
    def _opt_ptr_payload_of(t: ir.Type) -> (ir.Type | None);
    def _flow_narrowed_type_of(expr: (uni.UniNode | None)) -> (any | None);
    def _narrowed_flow_type(nd: uni.UniNode) -> (any | None);
    def _narrowing_blocked_by_none_test(nd: uni.UniNode) -> bool;
    def _narrowing_stable_in_loops(nd: uni.UniNode, name: str) -> bool;
    def _loop_rebinds_name(loop: uni.UniNode, name: str) -> bool;
    def _body_assigns_before(
        loop: uni.UniNode, child: (uni.UniNode | None), name: str
    ) -> bool;

    def _apply_flow_narrowing(nd: uni.UniNode, val: ir.Value) -> ir.Value;
    def _unbox_narrowed_member(nd: uni.AtomTrailer, val: ir.Value) -> ir.Value;
    def _lower_function_type_raw(t: any) -> ir.Type;
    def _stack_entry_alloca(var_type: ir.Type, name: str) -> ir.Value;
    def _abi_sizeof(t: ir.Type) -> int;
    def _resolve_jac_type(type_expr: (uni.UniNode | None)) -> ir.Type;
    def _lower_type_by_name(name: (str | None)) -> (ir.Type | None);
    def _lower_untyped_annotation(nd: uni.UniNode) -> (ir.Type | None);
    def _lower_list_for_elem(elem_llvm: ir.Type) -> ir.Type;
    def _resolve_decl_type(
        type_expr: (uni.UniNode | None), value: (uni.UniNode | None)
    ) -> ir.Type;

    def _widened_tuple_decl_type(
        type_expr: (uni.UniNode | None), value: (uni.UniNode | None)
    ) -> (ir.Type | None);

    def _tuple_struct_of(elem_types: list) -> ir.Type;
    def _resolve_sig_type(type_expr: (uni.UniNode | None)) -> ir.Type;
    def _resolve_field_type(var: uni.UniNode) -> ir.Type;
    def _foreign_optional_field(tb: any) -> bool;
    def _typevar_optional_field(tb: any) -> bool;
    def _erased_typevar_names(tb: any) -> list[str];
    def _erased_seq_type(tb: any) -> (ir.Type | None);
    def _type_base_is_unknown(tb: any) -> bool;
    def _emit_unlowerable_type(type_expr: uni.UniNode, tb: any) -> ir.Type;
    def _lower_type(t: any) -> (ir.Type | None);
    def _unify_repr_lowering(reprs: list) -> (ir.Type | None);
    def _lower_class_type(t: any) -> (ir.Type | None);
    def _lower_function_type(t: any) -> ir.Type;
    def _type_key_of(expr: (uni.UniNode | None)) -> (str | None);
    def _enum_name_of(expr: (uni.UniNode | None)) -> (str | None);
    def _tuple_key_of(expr: (uni.UniNode | None)) -> (str | None);
    def _set_spec_of(expr: (uni.UniNode | None)) -> (str | None);
    def _dict_key_of(expr: (uni.UniNode | None)) -> (str | None);
    def _list_spec_of(expr: (uni.UniNode | None)) -> (str | None);
    def _spec_of(
        expr: (uni.UniNode | None), names: tuple, registry: dict
    ) -> (str | None);

    def _struct_name_of(expr: (uni.UniNode | None)) -> (str | None);
    def _struct_name_for_key(tk: (str | None)) -> (str | None);
    def _erased_arch_base(tk: str) -> (str | None);
    def _split_union_key(tk: str) -> list[str];
    def _ptr_box_kind(rt: any) -> int;
    def _struct_ptr_pointee_name(val: ir.Value) -> (str | None);
    def _struct_array_elem_ptr(ptr: ir.Value, idx_val: ir.Value) -> ir.Value;
    def _list_elem_llvm_of(expr: (uni.UniNode | None)) -> (ir.Type | None);
    def _iter_elem_llvm_of(expr: (uni.UniNode | None)) -> (ir.Type | None);
    def _typed_elem_llvm_of(
        expr: (uni.UniNode | None), prefix: str
    ) -> (ir.Type | None);

    def _static_elem_llvm_of(expr: (uni.UniNode | None)) -> (ir.Type | None);
    def _elem_spec_of(expr: (uni.UniNode | None)) -> (str | None);
    def _get_name(nd: (uni.UniNode | None)) -> (str | None);
    def _to_bool(val: ir.Value) -> ir.Value;
    def _jacval_truthy(jv: ir.Value) -> ir.Value;
    def _jacval_is_none(jv: ir.Value, negate: bool) -> ir.Value;
    def _entry_alloca(var_type: ir.Type, name: str) -> ir.Value;
    def _zero_const(ty: ir.Type) -> ir.Constant;
    def _coerce_type(val: ir.Value, target_type: ir.Type) -> ir.Value;
    def _coerce_type_inner(val: ir.Value, target_type: ir.Type) -> ir.Value;
    def _promote_to_float(
        left: ir.Value, right: ir.Value, unsigned: bool = False
    ) -> tuple[(ir.Value, ir.Value)];

    def _emit_binary_op(
        op: str,
        left: ir.Value,
        right: ir.Value,
        unsigned: bool = False,
        checked: bool = False
    ) -> (ir.Value | None);

    def _unify_int_widths(
        left: ir.Value, right: ir.Value
    ) -> tuple[(ir.Value, ir.Value)];

    def _to_float_type(val: ir.Value, target: ir.Type, unsigned: bool) -> ir.Value;
    def _emit_arch_dunder_binop(
        op: str, left: ir.Value, right: ir.Value
    ) -> (ir.Value | None);

    def _emit_comparison(
        op: str, left: ir.Value, right: ir.Value, is_float: bool, unsigned: bool = False
    ) -> (ir.Value | None);

    def _is_jacval_ty(t: ir.Type) -> bool;
    def _is_jacval_boxable(t: ir.Type) -> bool;
    def _emit_jacval_ordering(
        op: str, jv: ir.Value, peer: ir.Value, jv_on_left: bool
    ) -> (ir.Value | None);

    def _emit_mixed_jacval_comparison(
        op: str, left: ir.Value, right: ir.Value
    ) -> (ir.Value | None);

    def _emit_optional_eq(
        op: str, left: ir.Value, right: ir.Value, is_float: bool
    ) -> (ir.Value | None);

    def _emit_jacval_eq(left: ir.Value, right: ir.Value) -> ir.Value;
    def _opt_membership_operand(left: ir.Value, slot_type: ir.Type) -> tuple;
    def _codegen_int_floor_divmod(
        left: ir.Value, right: ir.Value
    ) -> tuple[(ir.Value, ir.Value)];

    def _codegen_float_floor_div(left: ir.Value, right: ir.Value) -> ir.Value;
    def _codegen_float_floor_mod(left: ir.Value, right: ir.Value) -> ir.Value;
    def _spec_name_match(tk: str, names: tuple) -> bool;
    def _opt_sole_member(t: any) -> (any | None);
    def _spec_union_agreement(t: any, names: tuple) -> (any | None);
    def _elem_storage_llvm(t: any) -> (ir.Type | None);
    def _aos_elem_of(type_expr: uni.UniNode | None) -> (str | None);
    def _aos_elem_name(t: any) -> (str | None);
    def _lower_view_container(t: any) -> (ir.Type | None);
    def _program_has_subclasses(arch_name: str) -> bool;
    def _infer_type_name(val: ir.Value) -> (str | None);
    def _infer_list_elem_type(val: ir.Value) -> (str | None);
    def _infer_compr_elem_struct(compr: object) -> (str | None);
    def _resolve_clib_type(type_expr: (uni.UniNode | None)) -> ir.Type;
}
