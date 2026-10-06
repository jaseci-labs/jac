import from jaclang.compiler.frontend.roles { Kid }
import from jaclang.compiler.passes.context { CompileContext, CompilerPass }
import type from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.native_iface { NativeIface, NativeExport }
import jaclang.compiler.frontend.unitree as uni;
import os;
import sys;
import from jaclang.runtime.scalars { ScalarShape }

import from jaclang.compiler.frontend.codeinfo {
    HDR_ALLOC_ID_OFF,
    HDR_DTOR_OFF,
    HDR_MAGIC,
    HDR_MAGIC_SHIFT_BASE,
    HDR_RC_OFF,
    HDR_TAG_OFF,
    HDR_TOTAL,
    JACSTR_DESC_FIELDS,
    NativeFuncLayout,
    RC_SENTINEL,
    is_package_keyed_path,
    native_unit_identity,
    str_len_tag,
    STR_LEN_TAG_BIT,
    STR_LEN_TAG_SHIFT
}
import from jaclang.compiler.frontend.constant {
    CodeContext,
    OwnershipKind,
    SymbolAccess,
    Tokens as Tok
}
import from jaclang.compiler.frontend.diagnostics {
    DiagnosticInfo,
    E5026,
    E5060,
    E5088,
    E5089,
    E5090,
    E5091,
    E5092,
    E5095,
    E9001,
    E9002
}
import from jaclang.compiler.intrinsic_registry { IntrinsicEntry }
import from jaclang.compiler.passes.layout_pass {
    accessor_slot_name,
    ACCESSOR_SLOT_SUFFIX,
    archetype_accessors,
    ArchetypeLayout,
    EnumLayout,
    VTABLE_HEADER_SLOTS
}
import from jaclang.compiler.type_registry { JacTypeEntry }
import from jaclang.compiler.frontend.module_facts { ModuleFacts }
import from jaclang.compiler.types.types {
    ClassType,
    ModuleType,
    Parameter,
    TypeBase,
    UnionType,
    FunctionType as SemanticFunctionType
}
import from jaclang.compiler.frontend.const_fold { fold_const }
import from jaclang.compiler.types.ct_value {
    CtBool,
    CtBytes,
    CtFloat,
    CtInt,
    CtNone,
    CtStr,
    CtValue,
    ct_iter,
    ct_mangle,
    ct_truthy
}
import type from jaclang.compiler.types.ct_eval { CtEvaluator }
import type from jaclang.compiler.passes.osp_analysis { OspSlot }
import from jaclang.runtime.osp_tag { stable_osp_tag }
import from jaclang.compiler.backends.native.na_constants {
    CLASS_DISPLAY_OFF,
    EXC_LINEAGE_BITS,
    EXC_LINEAGE_MIX,
    EXC_LINEAGE_SLOTS,
    JACVAL_ELLIPSIS_TAG,
    LIVE_NODE_NEXT_OFF,
    LIVE_NODE_RC_OFF,
    LIVE_NODE_SIZE,
    LIVE_NODE_TAG_OFF,
    LIVE_NODE_USER_OFF,
    NATIVE_CONTAINER_CODES,
    NATIVE_COPY_FUNCS,
    NATIVE_OS_FUNCS,
    NATIVE_OSPATH_FUNCS,
    NATIVE_RANDOM_FUNCS,
    NATIVE_STRUCT_FUNCS,
    RC_BUFFERED_BIT,
    RC_COLOR_BLACK,
    RC_COLOR_GRAY,
    RC_COLOR_PURPLE,
    RC_COLOR_SHIFT,
    RC_COLOR_WHITE,
    RC_CYCLE_PACE,
    RC_CYCLE_THRESHOLD,
    RC_UNTRACED_BIT
}
import from jaclang.compiler.c_interop {
    c_builtin_kind,
    c_type_arg,
    foreign_read_copies,
    foreign_struct_of_type,
    is_builtin_pin_call,
    is_pinned_type,
    is_ptr_type,
    is_ptr_view_type
}
import from jaclang.compiler.frontend.constant { SymbolType }
import from jaclang.compiler.driver.pipeline_types { AnalysisFact }
import from jaclang.compiler.passes.layout_pass { native_type_key }
import from jaclang.compiler.expr_keys { type_tag_borrows }
import from jaclang.runtime.scalars {
    range_of,
    shape_of,
    wrap_value
}

obj NativeLowering {
    has module: uni.Module,
        prog: JacProgram,
        ctx: CompileContext,
        clib_struct_names: set[str] = set(),
        _foreign_modules: list[uni.Module] = [],
        _foreign_structs: (dict[str, list[tuple[str, str | None]]] | None) = None,
        _foreign_model_nmods: int = -1,
        _foreign_fn_decls: (dict[str, dict[str, any]] | None) = None,
        _foreign_fns_nmods: int = -1,
        enum_string_values: dict[str, list[tuple[str, str, int]]] = {},
        struct_field_indices: dict[str, dict[str, int]] = {},
        struct_field_order: dict[str, list[str]] = {},
        struct_field_opaque: dict[str, dict[str, str]] = {},
        struct_field_erased_tv: dict[str, dict[str, list[str]]] = {},
        _subclassed_arch_names: (set[str] | None) = None,
        func_ret_type_key: dict[str, str] = {},
        func_ret_elem_keys: dict[str, list[str | None]] = {},
        arch_ast_map: dict[str, uni.Archetype] = {},
        _struct_source_mod: dict[str, str] = {},
        _native_skipped_import_origin: dict[str, set[str]] = {},
        _short_mro_reach: (dict[str, list[str]] | None) = None,
        imported_osp_archs: dict[str, tuple[str, str]] = {},
        _unit_prefix: str = "",
        _unit_prefixes: dict[str, str] = {},
        _native_dep_paths: list[str] = [],
        _full_ast_cache: dict[str, uni.Module] = {},
        _pub_symbols: set[str] = set(),
        _unit_exports: dict[str, NativeExport] = {},
        _exc_type_registry: dict[str, int] = {"Exception": 0},
        region_handle_vars: set[str] = set(),
        _native_stdlib_modules: set[str] = set(),
        _native_module_imports: set[str] = set(),
        _pyb_base_memo: dict[str, tuple[str, str] | None] = {},
        _mono_solution: (dict[str, TypeBase] | None) = None,
        _mono_mangle_map: (dict[str, str] | None) = None,
        _ct_bindings: dict[str, CtValue] = {},
        closure_cell_vars: set[str] = set(),
        _loop_rebind_memo: dict[tuple[int, str], bool] = {};

    def emit(
        diag: DiagnosticInfo,
        node_override: (uni.UniNode | None) = None,
        related: (list[tuple[str, uni.UniNode]] | None) = None,
        help_text: (str | None) = None,
        **kwargs: any
    ) -> bool;

    def _register_region_handle_var(nd: uni.Assignment, var_name: str) -> None;

    def _fstring_spec_text(spec: uni.Expr) -> (str | None);

    def _fstring_spec_to_printf(spec: str, kind: str) -> (tuple[str, str] | None);

    def _decode_literal(arg_node: (uni.UniNode | None)) -> (str | None);

    def _emit_intrinsic_misuse(
        nd: uni.FuncCall, intr: IntrinsicEntry, reason: str
    ) -> None;

    def _native_module_call_target(nd: uni.FuncCall) -> tuple[str, str] | None;

    def _stdlib_intercept_covers(module_name: str, func_name: str) -> bool;

    def _from_imported_intercept(nd: uni.FuncCall) -> tuple[str, str] | None;

    def _emit_unsupported_builtin_call(nd: uni.FuncCall, func_name: str) -> None;

    def _empty_ctor_args_of(nd: uni.FuncCall) -> list[TypeBase];

    def _container_type_args(t: any) -> list[TypeBase];

    def _unwrap_cfg_expr(e: any) -> any;

    def _source_may_hold_bytes(source_type: (TypeBase | None)) -> bool;

    def _isinstance_type_name(nd: uni.UniNode) -> (str | None);

    def _enum_union_tags(
        operand_expr: uni.UniNode, names: list[str]
    ) -> tuple[list[int], list[str]];

    def _arch_alias_target(nd: (uni.UniNode | None)) -> (str | None);

    def _jacval_tags_for_type(name: str) -> list[int];

    def _arch_init_sig_of(type_name: str) -> (uni.FuncSignature | None);

    def _emit_pack_slot_refusal(nd: uni.FuncCall, star: str) -> None;

    def _emit_kw_spread_refusal(nd: uni.FuncCall) -> None;

    def _flow_future_licensed(nd: uni.ConcurrentExpr) -> (uni.Name | None);

    def _clib_struct_layout(name: str) -> tuple[int, int, list[tuple[int, bool, int]]];

    def _foreign_model -> dict[str, list[tuple[str, str | None]]];

    def _foreign_fns -> dict[str, dict[str, any]];

    def _foreign_struct_name_of_type(t: any) -> (str | None);

    def _clib_ret_is_cptr(sig: uni.FuncSignature) -> bool;

    def _c_decl_type_of(type_expr: uni.UniNode) -> any;

    def _scan_closure_escapes(nd: uni.UniNode, body: Sequence[uni.UniNode]) -> None;

    def _emit_closure_escape_error(var_name: str, nd: uni.UniNode) -> None;

    def _is_boolean_result_expr(nd: (uni.UniNode | None)) -> bool;

    def _spread_operand(nd: (uni.UniNode | None)) -> (uni.Expr | None);

    def _ctxmgr_callee(expr: (uni.UniNode | None)) -> (uni.Ability | None);

    def _permuted_walk_order(
        mods: list[tuple[str, uni.Module]]
    ) -> list[tuple[str, uni.Module]];

    def _extract_import_module_name(imp: uni.Import) -> (str | None);

    def _register_imported_hierarchy(imported_mod: uni.Module) -> None;

    def _own_prefix -> str;

    def _prefix_of_module(mod: (uni.Module | None)) -> str;

    def _prefix_of_path(path: str) -> str;

    def _symbol_for(
        name: str, owner: (uni.Module | None) = None, is_pub: bool = False
    ) -> str;

    def _record_export(
        name: str, symbol: str, kind: str, is_pub: bool = False
    ) -> None;

    def _note_native_dep(path: str) -> None;

    def _is_catalog_module(mod: uni.Module) -> bool;

    def _full_ast_of(full_path: str) -> (uni.Module | None);

    def _dep_iface(imported_mod: uni.Module) -> (NativeIface | None);

    def _dep_is_native_unit(imported_mod: uni.Module, path: str) -> bool;

    def _load_native_unit_module(path: str) -> (uni.Module | None);

    def _is_kernel_unit -> bool;

    def _vtable_symbol(arch_name: str) -> str;

    def _ensure_dep_inference(dep_mod: uni.Module) -> None;

    def _imported_function_demotions(imported_mod: uni.Module) -> (set | None);

    def _primitive_method_takes_kwargs(type_name: str, method_name: str) -> bool;

    def _split_call_kwargs(nd: uni.FuncCall) -> dict[str, uni.UniNode];

    def _ct_ctor_slots(target: uni.UniNode) -> list[tuple[str, uni.UniNode]];

    def _na_debug_on -> bool;

    def _enum_methods(nd: uni.Enum) -> list[uni.Ability];

    def _enum_ctor_layout(enum_name: str) -> (EnumLayout | None);

    def _enum_ctor_target(nd: uni.FuncCall) -> (str | None);

    def _emit_enum_ctor_refusal(nd: uni.FuncCall, enum_name: str, why: str) -> None;

    def _enum_is_string_valued(enum_name: str) -> bool;

    def _get_or_register_exc_type(exc_name: str) -> int;

    def _get_exc_descendants(type_name: str) -> list[str];

    def _exception_member_name(member: uni.UniNode) -> (str | None);

    def _exception_handler_targets(ex: uni.Expr | None) -> (list[str] | None);

    def _exc_message_slot(type_name: str) -> (int | None);

    def _raise_has_frame_handler(nd: uni.RaiseStmt) -> bool;

    def _ct_type_param_owner(nd: uni.Name) -> (str | None);

    def _is_root_walker_operand(nd: uni.UniNode) -> bool;

    def _is_walker_arch(name: str) -> bool;

    def _ability_is_generator(nd: uni.Ability) -> bool;

    def _normalize_type_key(key: str) -> str;

    def _elem_keys_of_annotation(
        ann: (uni.UniNode | None)
    ) -> (list[str | None] | None);

    def _record_ret_facts(
        name: str, sig: uni.FuncSignature, imported: (NativeFuncLayout | None) = None
    ) -> None;

    def _ct_eval -> CtEvaluator;

    def _ct_value_with_bindings(nd: uni.Expr) -> tuple[bool, (CtValue | None)];

    def _ct_origin(nd: uni.Expr) -> bool;

    def _ct_only_name(nd: uni.Name) -> bool;

    def _ability_has_ct_params(ability: uni.Ability) -> bool;

    def _solve_ct_args(
        ability: uni.Ability, nd: uni.FuncCall
    ) -> (dict[str, CtValue] | None);

    def _bind_ct_target(tgt: uni.UniNode, v: CtValue) -> None;

    def _mangled_of(t: any) -> (str | None);

    def _syntactic_bind_type_params(
        tag_node: (uni.UniNode | None),
        actual: any,
        tp_names: list[str],
        solution: dict[str, TypeBase]
    ) -> None;

    def _solve_generic_call(
        ability: uni.Ability, nd: uni.FuncCall
    ) -> (dict[str, TypeBase] | None);

    def _record_generic_definition(ability: uni.Ability) -> None;

    def _find_source_ability(mod_name: str, func_name: str) -> (uni.Ability | None);

    def _glob_native_use_exists(target: uni.UniNode) -> bool;

    def _resolve_method_owner(arch_name: str, method_name: str) -> (str | None);

    def _skip_is_other_module(
        nd: uni.FuncCall, func_name: str, mod_qual: (str | None)
    ) -> bool;

    def _complex_aug_token(aug_op: str) -> (str | None);

    def _emit_scalar_type_arg_refusal(
        nd: uni.UniNode, type_name: str, fname: str, tv_name: str, arg: any
    ) -> bool;

    def _arch_key(arch: uni.Archetype) -> str;

    def _arch_ref_key(nd: (uni.UniNode | None)) -> (str | None);

    def _arch_display(arch_name: str) -> str;

    def _native_archetypes(module: uni.Module) -> list[uni.Archetype];

    def _method_slot_name(method: uni.Ability, field: (uni.HasVar | None)) -> str;

    def _class_const_declarer(arch_name: str, field_name: str) -> (str | None);

    def _seam_warnings_on -> bool;

    def _refuse_opaque_field(
        nd: (uni.UniNode | None), type_name: (str | None), fname: str
    ) -> bool;

    def _constructor_slots -> tuple[str, ...];

    def _constructor_ability_for(cls: str, slot: str) -> (uni.Ability | None);

    def _event_from_walker(method: uni.Ability) -> bool;

    def _unadopted_field_owner(arch_name: str, field_name: str) -> (str | None);

    def _emit_field_access_refusal(
        nd: uni.UniNode, arch_name: str, field_name: str
    ) -> None;

    def _mro_of(arch_name: str) -> list[str];

    def _arch_layout(arch_name: str) -> (ArchetypeLayout | None);

    def _devirt_closed_world(arch_name: str) -> bool;

    def _hasvar_is_own(var: uni.UniNode) -> bool;

    def _stack_alloc_target_ok(nd: uni.UniNode) -> bool;

    def _compute_osp_model(archetypes: list[uni.Archetype]) -> None;

    def _osp_edge_class_name(expr: uni.UniNode) -> (str | None);

    def _derived_field_decls(nd: uni.Archetype) -> dict[str, uni.HasVar];

    def _class_expr_bound(
        expr: (uni.UniNode | None), unbounded: (str | None) = None
    ) -> (str | None);

    def _class_ancestors(type_name: str) -> list[str];

    def _osp_pins_refs -> bool;

    def _osp_active -> bool;

    def _xmod_osp_help(names: list[str | None]) -> (str | None);

    def _osp_disc_list_operand(expr: (uni.UniNode | None)) -> bool;

    def _elem_arch_name_of(expr: (uni.UniNode | None)) -> (str | None);

    def _pyb_base_of(arch_name: str) -> (tuple[str, str] | None);

    def _pyb_shadow_postinit_owner(arch_name: str) -> (str | None);

    def _pyb_ret_key(nd: uni.FuncCall) -> (str | None);

    def _copy_call_kind(nd: uni.FuncCall) -> (str | None);

    def _emit_copy_refusal(nd: uni.UniNode, kind: str, why: str) -> None;

    def _copy_hint_name(hint: (TypeBase | None)) -> str;

    def _copy_field_hints(arch: str) -> dict[str, (TypeBase | None)];

    def _nogc_type_arg_mangles_of_str(m: str) -> list[str];

    def _gc_mode -> str;

    def _str_desc_kind -> str;

    def _arch_is_acyclic(arch_name: str) -> bool;

    def _nogc_headerless -> bool;

    def _arch_is_osp_name(arch_name: str) -> bool;

    def _arch_is_walker_name(arch_name: str) -> bool;

    def _nogc_type_arg_mangles(expr: uni.UniNode | None) -> list[str];

    def _print_stream_name(value: uni.Expr) -> (str | None);

    def _split_type_args(s: str, sep: str = ",") -> list[str];

    def _scalar_shape(nd: (uni.UniNode | None)) -> (ScalarShape | None);

    def _scalar_shape_named(name: (str | None)) -> (ScalarShape | None);

    def _is_unsigned_node(nd: (uni.UniNode | None)) -> bool;

    def _is_sized_node(nd: (uni.UniNode | None)) -> bool;

    def _is_signed_sized_node(nd: (uni.UniNode | None)) -> bool;

    def _del_target_holds_graph(target: uni.Expr) -> bool;

    def _match_seq_parts(
        pat: uni.MatchSequence
    ) -> tuple[list[uni.MatchPattern], uni.MatchStar | None, list[uni.MatchPattern]];

    def _match_subj_ty(expr: (uni.UniNode | None)) -> (TypeBase | None);

    def _match_elem_ty_of(
        subj_ty: (TypeBase | None), prefix: str, idx: int
    ) -> (TypeBase | None);

    def _match_arch_fields(
        pat: uni.MatchArch, arch_name: str
    ) -> (list[tuple[str, uni.MatchPattern]] | None);

    def _na_chunks_shape(expr: object) -> (tuple[uni.Expr, uni.Expr] | None);

    def _require_trace_fn(type_name: str, participates: bool, has_trace: bool) -> None;

    def _flow_narrowed_type_of(expr: (uni.UniNode | None)) -> (TypeBase | None);

    def _narrowed_flow_type(nd: uni.UniNode) -> (TypeBase | None);

    def _narrowing_blocked_by_none_test(nd: uni.UniNode) -> bool;

    def _narrowing_stable_in_loops(nd: uni.UniNode, name: str) -> bool;

    def _loop_rebinds_name(loop: uni.UniNode, name: str) -> bool;

    def _target_bound_names(target: uni.UniNode) -> list[uni.Name];

    def _body_assigns_before(
        loop: uni.WhileStmt | uni.ForeverStmt | uni.InForStmt | uni.IterForStmt,
        child: (uni.UniNode | None),
        name: str
    ) -> bool;

    def _erased_decl(tb: any) -> bool;

    def _erased_field(type_name: str, fname: str) -> bool;

    def _erased_decl_names(tb: any) -> list[str];

    def _type_base_is_unknown(tb: any) -> bool;

    def _type_key_of(expr: (uni.UniNode | None)) -> (str | None);

    def _enum_name_of(expr: (uni.UniNode | None)) -> (str | None);

    def _split_union_key(tk: str) -> list[str];

    def _get_name(nd: (uni.UniNode | None)) -> (str | None);

    def _sort_key_return_type(nd: (uni.UniNode | None)) -> (TypeBase | None);

    def _sort_key_orderable(ty: (TypeBase | None)) -> (bool | None);

    def _sort_key_unsigned(nd: (uni.UniNode | None)) -> bool;

    def _agg_key_args(
        key_ret: (TypeBase | None), agg_name: str
    ) -> (list[TypeBase] | None);

    def _key_elem_unsigned(et: (TypeBase | None)) -> bool;

    def _container_class_name(ty: (TypeBase | None)) -> (str | None);

    def _is_graph_type(ty: (TypeBase | None)) -> bool;

    def _cmp_static_type(
        left_node: uni.UniNode, right_node: uni.UniNode
    ) -> (TypeBase | None);

    def _spec_name_match(tk: str, names: tuple[str, ...]) -> bool;

    def _opt_sole_member(t: any) -> (TypeBase | None);

    def _isinstance_unprovable_class(
        names: list[str], operand_arch: (str | None)
    ) -> (str | None);

    def _module_class_name(expr: uni.UniNode) -> (str | None);

    def _is_runtime_class_tuple(t: any) -> bool;

    def _callee_ability_of(nd: uni.FuncCall) -> (uni.Ability | None);

    def _nogc_owned_param(p: uni.ParamVar) -> bool;

    def _container_is_view(nd: uni.UniNode) -> bool;

    def _nogc_owned_world -> bool;

    def _nogc_opt_slots_owned -> bool;

    def _is_move_site(expr: uni.UniNode | None) -> bool;

    def _drop_member_of(owner: str) -> (uni.Ability | None);

    def _nogc_borrow_local_assign(nd: object) -> bool;

    def _program_has_subclasses(arch_name: str) -> bool;

    def _copy_call_arg(kind: str, nd: uni.FuncCall) -> (uni.Expr | uni.KWPair | None);

    def _delete_location_subscript(target: uni.AtomTrailer, nd: uni.DeleteStmt) -> (tuple[bool, uni.Slice] | None);

    def _delete_list_slice_unstepped(slice_node: uni.Slice, nd: uni.DeleteStmt) -> bool;

    def _if_ct_taken(nd: uni.IfStmt) -> (bool | None);

    def _match_tuple_seq_heads(pat: uni.MatchSequence) -> (list[uni.MatchPattern] | None);

    def _assignment_environ_store(nd: uni.Assignment, target_expr: uni.AtomTrailer) -> bool;

    def _assignment_tag_bare_container(tag: uni.Expr) -> bool;

    def _assignment_borrows_source(nd: uni.Assignment) -> bool;

    def _assignment_sole_target_owned(nd: uni.Assignment) -> bool;

    def _assignment_target_module_global(target_expr: uni.Expr) -> bool;

    def _for_ct_items(nd: uni.InForStmt) -> (CtValue | None);

    def _for_dict_items_unpack(nd: uni.InForStmt) -> bool;

    def _for_builtin_range(nd: uni.InForStmt) -> bool;

    def _try_flow_for_parallel_is_flow(nd: uni.InForStmt) -> bool;

    def _try_flow_for_parallel_reduce_candidates(nd: uni.InForStmt) -> list[tuple[str, str]];

    def _try_flow_for_parallel_body_names(nd: uni.InForStmt) -> list[uni.Name];

    def _try_flow_for_parallel_decl_inside(anm: uni.Name, nd: uni.InForStmt) -> bool;

    def _for_indexed_has_yield(nd: uni.InForStmt) -> bool;

}

glob _READY: dict[int, NativeLowering] = {};

def take_native_lowering(
    module: uni.Module, prog: JacProgram, ctx: CompileContext
) -> NativeLowering;

walker NaLowerAnalysisPass(CompilerPass) {
    def _run_impl(ir_in: uni.Module) -> uni.Module;
    can run_walk with uni.Module entry;
}
