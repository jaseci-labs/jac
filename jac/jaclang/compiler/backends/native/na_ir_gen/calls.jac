import from jaclang.compiler.backends.native.llvm { ir }
import from jaclang.compiler.backends.native.na_ir_gen.state { NaIRGenState }
import from jaclang.runtime.scalars { ScalarShape }
import from jaclang.compiler.intrinsic_registry { IntrinsicEntry }
import from jaclang.compiler.frontend.codeinfo { HDR_TAG_OFF }
import from jaclang.compiler.frontend.constant { Tokens as Tok }
import from jaclang.compiler.frontend.diagnostics { E5092, E5095, E9001 }
import jaclang.compiler.frontend.unitree as uni;
import os;

obj NaIRGenCalls(NaIRGenState) {
    def _codegen_call(nd: uni.FuncCall) -> (ir.Value | None);
    def _codegen_sized_builtin_call(
        nd: uni.FuncCall, func_name: (str | None), call_kind: str
    ) -> (ir.Value | None);

    def _codegen_intrinsic(
        nd: uni.FuncCall, intr: IntrinsicEntry
    ) -> (ir.Value | None);

    def _emit_intrinsic_misuse(
        nd: uni.FuncCall, intr: IntrinsicEntry, reason: str
    ) -> None;

    def _intrinsic_operand(
        nd: uni.FuncCall, intr: IntrinsicEntry, arg: uni.Expr, spec: str
    ) -> (ir.Value | None);

    def _emit_intrinsic_rc_runtime(
        nd: uni.FuncCall, intr: IntrinsicEntry, args: list
    ) -> (ir.Value | None);

    def _emit_intrinsic_float_bits(
        nd: uni.FuncCall, intr: IntrinsicEntry, args: list
    ) -> (ir.Value | None);

    def _emit_intrinsic_bits_float(
        nd: uni.FuncCall, intr: IntrinsicEntry, args: list
    ) -> (ir.Value | None);

    def _emit_intrinsic_mem_load(
        nd: uni.FuncCall, intr: IntrinsicEntry, args: list
    ) -> (ir.Value | None);

    def _emit_intrinsic_mem_store(
        nd: uni.FuncCall, intr: IntrinsicEntry, args: list
    ) -> (ir.Value | None);

    def _emit_intrinsic_atomic_xchg(
        nd: uni.FuncCall, intr: IntrinsicEntry, args: list
    ) -> (ir.Value | None);

    def _emit_intrinsic_call_dtor(
        nd: uni.FuncCall, intr: IntrinsicEntry, args: list
    ) -> (ir.Value | None);

    def _native_module_call_target(nd: uni.FuncCall) -> (tuple | None);
    def _emit_unsupported_builtin_call(nd: uni.FuncCall, func_name: str) -> None;
    def _empty_ctor_args_of(nd: uni.FuncCall) -> list;
    def _container_type_args(t: any) -> list;
    def _unwrap_cfg_expr(e: any) -> any;
    def _spec_from_container_ptr(t: (ir.Type | None)) -> (str | None);
    def _call_args_lowered(
        nd: uni.UniNode, func: ir.Function, func_name: str, coerced: list
    ) -> bool;

    def _emit_new(nd: uni.FuncCall) -> (ir.Value | None);
    def _emit_take(nd: uni.FuncCall) -> (ir.Value | None);
    def _emit_swap(nd: uni.FuncCall) -> (ir.Value | None);
    def _codegen_decorated_call(nd: uni.FuncCall, func_name: str) -> (ir.Value | None);
    def _emit_isinstance(nd: uni.FuncCall) -> (ir.Value | None);
    def _emit_isinstance_ptr_tags(operand: ir.Value, tags: list[int]) -> ir.Value;
    def _isinstance_type_name(nd: uni.UniNode) -> (str | None);
    def _isinstance_target_names(
        nd: uni.FuncCall, operand: ir.Value, type_arg: uni.UniNode
    ) -> (list[str] | None);

    def _isinstance_operand_is_pyb(nd: uni.FuncCall, operand: ir.Value) -> bool;
    def _isinstance_abc_reduction(
        type_expr: uni.UniNode, name: str
    ) -> (list[str] | None);

    def _isinstance_static_verdict(name: str, operand: ir.Value) -> (bool | None);
    def _enum_union_tags(operand_expr: uni.UniNode, names: list[str]) -> tuple;
    def _arch_alias_target(nd: (uni.UniNode | None)) -> (str | None);
    def _emit_isinstance_user(
        nd: uni.FuncCall, operand: ir.Value, names: list[str]
    ) -> (ir.Value | None);

    def _emit_isinstance_core(
        nd: uni.FuncCall, operand: ir.Value
    ) -> (ir.Value | None);

    def _emit_isinstance_mixed(
        nd: uni.FuncCall, operand: ir.Value, tags: list[int], names: list[str]
    ) -> (ir.Value | None);

    def _jacval_tags_for_type(name: str) -> list[int];
    def _erased_generic_ctor(nd: uni.FuncCall) -> (str | None);
    def _linked_callee_decl(func: (ir.Function | None)) -> (uni.Ability | None);
    def _callee_sig_of(
        nd: uni.FuncCall, func: (ir.Function | None) = None
    ) -> (uni.FuncSignature | None);

    def _arch_init_sig_of(type_name: str) -> (uni.FuncSignature | None);
    def _codegen_call_args(nd: uni.FuncCall) -> list;
    def _coerce_narrowed_arg(
        nd: (uni.UniNode | None), val: (ir.Value | None)
    ) -> (ir.Value | None);

    def _codegen_receiver(nd: (uni.UniNode | None)) -> (ir.Value | None);
    def _emit_take_ref(value: ir.Value, op: str, loc: str = "") -> None;
    def _codegen_bound_args(
        nd: uni.FuncCall, func: ir.Function, self_offset: int = 0
    ) -> list;

    def _emit_pack_slot_refusal(nd: uni.FuncCall, star: str) -> None;
    def _codegen_varargs_list(
        nd: uni.FuncCall, extras: list, expected: (ir.Type | None)
    ) -> (ir.Value | None);

    def _codegen_kwargs_dict(
        nd: uni.FuncCall,
        leftover: dict,
        expected: (ir.Type | None),
        order: (list | None) = None,
        bind_records: (list | None) = None
    ) -> (ir.Value | None);

    def _merge_dict_into(
        dst: ir.Value,
        src: ir.Value,
        helpers: dict,
        dict_key: str,
        loc: str,
        skip_keys: (ir.Value | None) = None
    ) -> bool;

    def _prep_kwbind_record(
        name: str,
        slot_type: ir.Type,
        args_idx: int,
        stored: ir.Value,
        bound_kind: (str | None),
        required_kind: (str | None)
    ) -> dict;

    def _default_arg_fallback(t: ir.Type) -> ir.Value;
    def _try_flow_future(nd: uni.ConcurrentExpr) -> (ir.Value | None);
    def _flow_future_licensed(nd: uni.ConcurrentExpr) -> (uni.Name | None);
}
