import from jaclang.compiler.passes.layout_pass {
    ACCESSOR_SLOT_SUFFIX,
    ArchetypeLayout,
    accessor_slot_name,
    archetype_accessors
}
import from jaclang.compiler.backends.native.llvm { ir }
import from jaclang.compiler.backends.native.na_ir_gen.constants {
    NATIVE_OSPATH_FUNCS,
    NATIVE_OS_FUNCS,
    NATIVE_RANDOM_FUNCS,
    NATIVE_STRUCT_FUNCS,
    NATIVE_TIME_FUNCS
}
import from jaclang.compiler.backends.native.na_ir_gen.state { NaIRGenState }
import from jaclang.compiler.frontend.codeinfo {
    HDR_ALLOC_ID_OFF,
    HDR_DTOR_OFF,
    HDR_RC_OFF,
    HDR_TOTAL,
    RC_SENTINEL
}
import from jaclang.compiler.frontend.constant { CodeContext, Tokens as Tok }
import from jaclang.compiler.frontend.constant { OwnershipKind, SymbolAccess }
import from jaclang.compiler.frontend.diagnostics { E5090, E5091, E5092 }
import from jaclang.runtime.osp_model { stable_osp_tag }
import from jaclang.compiler.backends.py.module_codegen_pass { ModuleCodegenPass }
import jaclang.compiler.frontend.unitree as uni;
import os;
import sys;

obj NaIRGenObjects(NaIRGenState) {
    def _emit_heap_object_alloc(
        nd: uni.UniNode, type_name: str, size: ir.Value, headerless: bool
    ) -> ir.Value;

    def _erased_sig_typevars(nd: uni.Archetype) -> dict;
    def _reject_scalar_type_args(nd: uni.UniNode, type_name: str) -> bool;
    def _emit_scalar_type_arg_refusal(
        nd: uni.UniNode, type_name: str, fname: str, tv_name: str, arg: any
    ) -> bool;

    def _empty_container_for_field(
        ftype: (ir.Type | None), label: str
    ) -> (ir.Value | None);

    def _opt_unwrap_attr(obj_val: ir.Value) -> ir.Value;
    def _opt_unwrap_guarded(
        val: (ir.Value | None), what: str, msg: str
    ) -> (ir.Value | None);

    def _opt_unwrap_iterable(coll_val: (ir.Value | None)) -> (ir.Value | None);
    def _opt_unwrap_subscript(val: (ir.Value | None)) -> (ir.Value | None);
    def _forward_declare_archetype_names(module: uni.Module) -> None;
    def _native_archetypes(module: uni.Module) -> list[uni.Archetype];
    def _register_archetypes(module: uni.Module) -> None;
    def _codegen_archetype(nd: uni.Archetype, imported: bool = False) -> None;
    def _register_static_fields(arch_name: str, archhas: uni.ArchHas) -> None;
    def _register_class_consts(
        nd: uni.Archetype, arch_name: str, block: uni.ModuleCode
    ) -> None;

    def _jc_abi_offsets(field_types: list) -> tuple;
    def _build_jc_layout -> dict;
    def _register_one_class_const(
        arch_name: str,
        fname: str,
        target: uni.UniNode,
        assign: uni.Assignment,
        owns: bool
    ) -> None;

    def _class_const_enum_init(
        value: uni.UniNode, ftype: ir.Type
    ) -> (ir.Constant | None);

    def _forward_declare_method(
        arch_name: str,
        method: uni.Ability,
        field: (uni.HasVar | None) = None,
        imported: bool = False
    ) -> None;

    def _visit_nonprimary_ancestor_methods(arch: uni.Archetype, declare: bool) -> None;
    def _codegen_method(
        arch_name: str,
        method: uni.Ability,
        symbol_override: (str | None) = None,
        field: (uni.HasVar | None) = None
    ) -> None;

    def _method_slot_name(method: uni.Ability, field: (uni.HasVar | None)) -> str;
    def _accessor_slot_of(type_name: str, field_name: str, kind: str) -> (str | None);
    def _own_accessor_result(result: ir.Value) -> ir.Value;
    def _codegen_accessor_call(
        obj_val: ir.Value, type_name: str, slot: str, args: list[ir.Value]
    ) -> (ir.Value | None);

    def _emit_dispatched_field_ptr(
        obj_val: ir.Value,
        type_name: str,
        field_name: str,
        ftype: (ir.Type | None),
        parts: (list[str] | None) = None
    ) -> (ir.Value | None);

    def _receiver_union_parts(nd: (uni.UniNode | None)) -> (list[str] | None);
    def _narrow_receiver_ptr(obj_val: ir.Value, type_name: str) -> (ir.Value | None);
    def _class_const_global(
        arch_name: str, field_name: str
    ) -> (ir.GlobalVariable | None);

    def _class_const_variants(arch_name: str, field_name: str) -> tuple;
    def _codegen_class_const_read(
        obj_val: ir.Value, type_name: str, field_name: str
    ) -> (ir.Value | None);

    def _class_const_declarer(arch_name: str, field_name: str) -> (str | None);
    def _emit_class_routed_call(
        nd: uni.FuncCall,
        _sfull: str,
        _mnames: list[str],
        _given_recv: (ir.Value | None),
        _given_recv_cls: (str | None)
    ) -> (ir.Value | None);

    def _receiver_routed_method_fn(
        nd: uni.UniNode, _sfull: str, _mnames: list[str], _recv_cls: (str | None)
    ) -> (ir.Function | None);

    def _demote_method_if_unlowerable(
        full_name: str,
        func: ir.Function,
        local_mark: int,
        keep_func: bool = False,
        stub_body: bool = True
    ) -> bool;

    def _seam_warnings_on -> bool;
    def _opaque_field_if_unlowerable(
        arch_name: str, fname: str, local_mark: int
    ) -> (ir.Type | None);

    def _refuse_opaque_field(
        nd: (uni.UniNode | None), type_name: (str | None), fname: str
    ) -> bool;

    def _constructor_slots -> tuple;
    def _constructor_ability_for(cls: str, slot: str) -> (uni.Ability | None);
    def _predemote_capability_constructors -> None;
    def _codegen_constructors_first(archetypes: list) -> None;
    def _demoted_init_of(type_name: str) -> (str | None);
    def _codegen_no_sig_method(arch_name: str, method: uni.Ability) -> None;
    def _forward_declare_event_method(arch_name: str, method: uni.Ability) -> None;
    def _codegen_event_method(arch_name: str, method: uni.Ability) -> None;
    def _trigger_member_structs(tag: (uni.UniNode | None)) -> list[str];
    def _trigger_struct_names(method: uni.Ability) -> list[str];
    def _union_layout_conflict(members: list[str]) -> (str | None);
    def _codegen_instantiation(
        nd: (uni.FuncCall | uni.Name),
        type_name_override: (str | None) = None,
        ctor_params: (list | None) = None
    ) -> (ir.Value | None);

    def _codegen_method_call(nd: uni.FuncCall) -> (ir.Value | None);
    def _unregistered_class_target(target: uni.UniNode) -> (str | None);
    def _emit_obj_str(val: ir.Value) -> (ir.Value | None);
    def _emit_default_obj_repr(val: ir.Value, type_name: str) -> ir.Value;
    def _codegen_field_access(
        obj_val: ir.Value,
        field_name: str,
        type_name: str,
        nd: (uni.UniNode | None) = None
    ) -> (ir.Value | None);

    def _codegen_field_aug_assign(
        target: uni.AtomTrailer,
        rhs: ir.Value,
        aug_op: str,
        rhs_node: (uni.Expr | None) = None
    ) -> (ir.Value | None);

    def _codegen_field_assign(
        target: uni.AtomTrailer, value: ir.Value, skip_narrow_coerce: bool = False
    ) -> None;

    def _read_field_or_refuse(
        nd: uni.UniNode, obj_val: ir.Value, field_name: str, arch_name: str
    ) -> (ir.Value | None);

    def _unadopted_field_owner(arch_name: str, field_name: str) -> (str | None);
    def _emit_field_access_refusal(
        nd: uni.UniNode, arch_name: str, field_name: str
    ) -> None;

    def _mro_of(arch_name: str) -> list[str];
    def _arch_layout(arch_name: str) -> (ArchetypeLayout | None);
    def _arch_has_vtable(arch_name: str) -> bool;
    def _devirt_closed_world(arch_name: str) -> bool;
    def _hasvar_is_own(var: uni.UniNode) -> bool;
    def _store_inline_field(
        type_name: str,
        fname: str,
        field_ptr: ir.Value,
        value: (ir.Value | None),
        drop_old: bool
    ) -> None;

    def _stack_alloc_target_ok(nd: uni.UniNode) -> bool;
}
