import from jaclang.compiler.passes.native.llvm { ir }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes.module_codegen_pass { ModuleCodegenPass }
import from jaclang.jac0core.constant { CodeContext, Tokens as Tok }
import from jaclang.jac0core.diagnostics {
    E2018,
    E5026,
    E5060,
    E5090,
    E5091,
    E5092,
    E9002
}
import from jaclang.jac0core.osp_model { OspAnalysis, OspModel, stable_osp_tag }

import from jaclang.compiler.passes.main.layout_pass { VTABLE_HEADER_SLOTS }

glob NATIVE_TIME_FUNCS: set[str] = {
         "time",
         "monotonic",
         "perf_counter",
         "time_ns",
         "monotonic_ns",
         "perf_counter_ns",
         "sleep",

     };

glob NATIVE_OS_FUNCS: set[str] = {
         "getpid",
         "getcwd",
         "getenv",
         "chdir",
         "mkdir",
         "makedirs",
         "rmdir",
         "remove",
         "unlink",
         "rename",
         "system",

     };

glob NATIVE_RANDOM_FUNCS: set[str] = {
         "seed",
         "random",
         "getrandbits",
         "randint",
         "randrange",
         "uniform",

     };

glob NATIVE_STRUCT_FUNCS: set[str] = {"pack", "unpack", "calcsize", "pack_into", };

glob RC_SENTINEL: int = 0x7FFFFFFFFFFFFFFF;

glob HDR_ALLOC_ID_OFF: int = -32,
     HDR_TAG_OFF: int = -24,
     HDR_RC_OFF: int = -16,
     HDR_DTOR_OFF: int = -8,
     HDR_TOTAL: int = 32;

glob RC_COLOR_BLACK: int = 0,
     RC_COLOR_WHITE: int = 1,
     RC_COLOR_GRAY: int = 2,
     RC_COLOR_PURPLE: int = 3,
     RC_BUFFERED_BIT: int = 4,
     RC_COLOR_SHIFT: int = 48,
     RC_CYCLE_THRESHOLD: int = 1000;

glob LIVE_NODE_ID_OFF: int = 0,
     LIVE_NODE_USER_OFF: int = 8,
     LIVE_NODE_TAG_OFF: int = 16,
     LIVE_NODE_RC_OFF: int = 24,
     LIVE_NODE_NEXT_OFF: int = 32,
     LIVE_NODE_SIZE: int = 40;

glob HDR_MAGIC: int = 44061,
     HDR_MAGIC_SHIFT_BASE: int = 44061 * 4294967296;

obj NaIRGenPass(ModuleCodegenPass) {
    has llvm_module: ir.Module postinit,
        type_map: dict[str, ir.Type] postinit,
        complex_struct_type: object postinit,
        range_struct_type: object postinit,
        slice_struct_type: object postinit,
        jacval_type: object postinit,
        _builder: (ir.IRBuilder | None) = None,
        func_symtab: dict[str, ir.Function] = {},
        local_vars: dict[str, ir.AllocaInstr] = {},
        param_vars: set[str] = set(),
        has_native_code: bool = False,
        native_tests: list = [],
        _fmt_strings: dict[str, ir.GlobalVariable] = {},
        _interned_strs: dict[str, ir.GlobalVariable] = {},
        extern_funcs: dict[str, ir.Function] = {},
        clib_extern_names: set[str] = set(),
        clib_struct_names: set[str] = set(),
        clib_struct_abi_types: dict[str, ir.Type] = {},
        _foreign_modules: list = [],
        _foreign_structs: (dict | None) = None,
        _foreign_model_nmods: int = -1,
        _foreign_fn_decls: (dict | None) = None,
        _foreign_fns_nmods: int = -1,
        clib_fn_abi: dict[str, dict] = {},
        clib_vtable_structs: set[str] = set(),
        clib_trampoline_funcs: dict[str, ir.Function] = {},
        enum_values: dict[str, ir.Constant] = {},
        enum_types: dict[str, ir.IntType] = {},
        enum_string_values: dict[str, list] = {},
        enum_value_arrays: dict[str, object] = {},
        enum_name_arrays: dict[str, object] = {},
        enum_member_ordinal: dict[str, int] = {},
        struct_field_enum_type: dict[str, dict] = {},
        loop_stack: list[tuple] = [],
        _str_count: int = 0,
        struct_types: dict[str, object] = {},
        struct_field_indices: dict[str, dict] = {},
        struct_field_order: dict[str, list] = {},
        struct_field_types: dict[str, dict] = {},
        struct_field_defaults: dict[str, object] = {},
        struct_field_opaque: dict[str, set] = {},
        method_funcs: dict[str, ir.Function] = {},
        static_methods: dict[str, bool] = {},
        static_fields: dict[str, object] = {},
        static_field_types: dict[str, object] = {},
        func_ret_type_key: dict[str, str] = {},
        func_ret_elem_keys: dict[str, list] = {},
        list_types: dict[str, object] = {},
        list_helpers: dict[str, dict] = {},
        var_list_elem_struct: dict[str, object] = {},
        _pending_list_elem_struct: (object | None) = None,
        _self_arch: (str | None) = None,
        parent_field_start: dict[str, dict[str, int]] = {},
        arch_ast_map: dict[str, object] = {},
        vtable_layouts: dict[str, list[str]] = {},
        vtable_method_indices: dict[str, dict] = {},
        vtable_globals: dict[str, ir.GlobalVariable] = {},
        _non_overridden_methods: dict[str, set[str]] = {},
        _native_skipped_methods: set[str] = set(),
        _class_name_consts: dict[str, ir.Value] = {},
        osp_type_tag_field: dict[str, int] = {},
        osp_reports_field: dict[str, int] = {},
        osp_thunk_funcs: dict[str, ir.Function] = {},
        _osp_thunk_uid: int = 0,
        imported_osp_archs: dict[str, tuple] = {},
        _osp_kernel_mod: (object | None) = None,
        _fmt_kernel_mod: (object | None) = None,
        _osp_desc_global: (object | None) = None,
        _osp_rt_global: (object | None) = None,
        _osp_setup_fn: (object | None) = None,
        _osp_ensure_fn: (object | None) = None,
        _osp_kernel_inited_gv: (object | None) = None,
        _osp_kernel_glob_init_fn: (object | None) = None,
        _osp_filter_fn: (object | None) = None,
        _osp_h2i_fn: (object | None) = None,
        _osp_is_a_fn: (object | None) = None,
        tuple_types: dict[str, object] = {},
        global_vars: dict[str, ir.GlobalVariable] = {},
        global_var_types: dict[str, ir.Type] = {},
        dict_types: dict[str, object] = {},
        dict_helpers: dict[str, dict] = {},
        set_types: dict[str, object] = {},
        set_helpers: dict[str, dict] = {},
        _exc_state_type: (object | None) = None,
        _exc_handler_global: (object | None) = None,
        _exc_push_fn: (object | None) = None,
        _exc_pop_fn: (object | None) = None,
        _exc_raise_fn: (object | None) = None,
        _exc_type_registry: dict[str, int] = {"Exception": 0},
        _exc_type_counter: int = 1,
        _rt_error_msgs: dict[str, object] = {},
        _file_struct_type: (object | None) = None,
        _file_helpers_emitted: bool = False,
        _binary_file_struct_type: (object | None) = None,
        _binary_file_helpers_emitted: bool = False,
        _bytes_struct_type: (object | None) = None,
        _bytes_repr_function: (object | None) = None,
        _float_repr_function: (object | None) = None,
        _repr_fns: dict[str, ir.Function] = {},
        _jac_iter_type: (object | None) = None,
        _iter_structs_registered: bool = False,
        _iter_next_fns: dict[str, ir.Function] = {},
        _iter_uid: int = 0,
        _native_emitters: (dict[str, object] | None) = None,
        _native_builtin_emitter: (object | None) = None,
        _primitive_method_name_cache: (dict[str, set[str]] | None) = None,
        _rc_debug_codegen: bool = False,
        rc_helpers_emitted: bool = False,
        rc_alloc_fn: (ir.Function | None) = None,
        rc_retain_fn: (ir.Function | None) = None,
        rc_release_simple_fn: (ir.Function | None) = None,
        rc_release_impl_fn: (ir.Function | None) = None,
        rc_set_type_fn: (ir.Function | None) = None,
        rc_gc_disable_fn: (ir.Function | None) = None,
        rc_gc_enable_fn: (ir.Function | None) = None,
        rc_gc_disabled_gv: object = None,
        rc_cycles_enable_fn: (ir.Function | None) = None,
        rc_cycles_enabled_gv: object = None,
        rc_debug_gv: object = None,
        rc_alloc_id_gv: object = None,
        rc_live_head_gv: object = None,
        rc_ctx_op_gv: object = None,
        rc_ctx_loc_gv: object = None,
        malloc_fn: (ir.Function | None) = None,
        free_fn: (ir.Function | None) = None,
        rc_safe_free_fn: (ir.Function | None) = None,
        rc_roots_buf_gv: object = None,
        rc_roots_cap_gv: object = None,
        rc_roots_count_gv: object = None,
        rc_collecting_gv: object = None,
        rc_push_root_fn: (ir.Function | None) = None,
        rc_collect_cycles_fn: (ir.Function | None) = None,
        rc_trace_lookup_fn: (ir.Function | None) = None,
        rc_trace_pairs: dict[str, tuple] = {},
        rc_retains_emitted: int = 0,
        rc_releases_emitted: int = 0,
        rc_ops_elided: int = 0,
        struct_trace_fns: dict[str, ir.Function] = {},
        struct_release_fns: dict[str, ir.Function] = {},
        struct_drop_fns: dict[str, ir.Function] = {},
        container_drop_fns: dict[str, ir.Function] = {},
        struct_drop_hooks: dict[str, ir.Function] = {},
        struct_drop_fields_fns: dict[str, ir.Function] = {},
        arena_helpers_emitted: bool = False,
        region_new_fn: (ir.Function | None) = None,
        region_alloc_fn: (ir.Function | None) = None,
        region_log_dtor_fn: (ir.Function | None) = None,
        region_drop_fn: (ir.Function | None) = None,
        osp_anchor_alloc_fn: (ir.Function | None) = None,
        region_handle_of_fn: (ir.Function | None) = None,
        region_stack: list = [],
        region_handle_vars: set[str] = set(),
        region_anon_count: int = 0,
        rc_region_allocs: int = 0,
        nogc_stack_vars: set[str] = set(),
        list_release_fns: dict[str, ir.Function] = {},
        dict_release_fns: dict[str, ir.Function] = {},
        set_release_fns: dict[str, ir.Function] = {},
        _struct_bodies_done: set[str] = set(),
        _native_stdlib_modules: set[str] = set(),
        _native_module_imports: set[str] = set(),
        _stdlib_helpers_emitted: set[str] = set(),
        _global_origins: dict[str, str] = {},
        _clib_paths: list[str] = [],
        _clib_symbol_lib: dict[str, str] = {},
        _native_emit_ctx_class: (type | None) = None,
        _lowered_type_cache: dict[str, ir.Type] = {},
        di_file: object = None,
        di_cu: object = None,
        _di_current_sp: object = None,
        _func_loc: dict[str, int] = {};

    static has REQUIRES: tuple = (
        'inference',
        'cfg',
        'ownership',
        'capability',
        'rc-facts'
    );

    has builder: ir.IRBuilder { getter; }

    def postinit -> None;
    def transform(ir_in: uni.Module) -> uni.Module;
    def _register_enums(module: uni.Module) -> None;
    def _forward_declare_functions(module: uni.Module) -> None;
    def _maybe_declare_ability(nd: uni.ElementStmt) -> None;
    def _codegen_ability(nd: uni.Ability) -> None;
    def _codegen_nested_ability(nd: uni.Ability) -> None;
    def _predeclare_nested_siblings(nd: uni.Ability) -> None;
    def _codegen_test(nd: uni.Test) -> None;
    def _codegen_body(stmts: (list | tuple)) -> None;
    def _codegen_stmt(nd: uni.UniNode) -> None;
    def _codegen_return(nd: uni.ReturnStmt) -> None;
    def _codegen_if(nd: uni.IfStmt) -> None;
    def _codegen_switch(nd: uni.SwitchStmt) -> None;
    def _codegen_while(nd: uni.WhileStmt) -> None;
    def _codegen_open_stmt(nd: uni.OpenStmt) -> None;
    def _codegen_forever(nd: uni.ForeverStmt) -> None;
    def _codegen_assignment(nd: uni.Assignment) -> None;
    def _codegen_expr(nd: (uni.UniNode | None)) -> (ir.Value | None);
    def _codegen_required(nd: (uni.UniNode | None)) -> (ir.Value | None);
    def _codegen_name(nd: uni.Name) -> (ir.Value | None);
    def _codegen_binary(nd: uni.BinaryExpr) -> (ir.Value | None);
    def _codegen_pipe_fwd(nd: uni.BinaryExpr) -> (ir.Value | None);
    def _codegen_walrus(nd: uni.BinaryExpr) -> (ir.Value | None);
    def _codegen_compare(nd: uni.CompareExpr) -> (ir.Value | None);
    def _codegen_compare_chain(
        nd: uni.CompareExpr, left: ir.Value
    ) -> (ir.Value | None);

    def _codegen_compare_link(
        op: str,
        left: ir.Value,
        right: ir.Value,
        left_node: uni.UniNode,
        right_node: uni.UniNode,
        release_operands: bool = True
    ) -> (ir.Value | None);

    def _codegen_unary(nd: uni.UnaryExpr) -> (ir.Value | None);
    def _codegen_call(nd: uni.FuncCall) -> (ir.Value | None);
    def _codegen_rc_intrinsic(func_name: str) -> bool;
    def _native_module_call_target(nd: uni.FuncCall) -> (str | None);
    def _emit_unsupported_builtin_call(nd: uni.FuncCall, func_name: str) -> None;
    def _emit_new(nd: uni.FuncCall) -> (ir.Value | None);

    has lambda_captures: dict[str, list[tuple]] = {},
        _pending_lambda_captures: (list[tuple] | None) = None,
        nested_captures: dict[str, tuple] = {},
        _nested_predecl: dict = {},
        _bytearray_fns: dict = {},
        generator_fns: dict[str, uni.Ability] = {},
        generic_fns: dict[str, uni.Ability] = {},
        _generic_methods: dict[str, uni.Ability] = {},
        _mono_fns: dict[str, ir.Function] = {},
        _mono_solution: (dict | None) = None,
        _mono_mangle_map: (dict | None) = None,
        _gen_ctx: (dict | None) = None,
        _gen_try_stack: list = [],
        decorated_fns: dict[str, tuple] = {},
        closure_cell_vars: set[str] = set(),
        closure_cell_handles: dict[str, ir.Value] = {},
        closure_sig_registry: dict[str, tuple] = {},
        _closure_sig_keys: dict[str, str] = {},
        _closure_cell_structs: dict[str, str] = {},
        closure_thunks: dict[str, ir.Function] = {},
        _closure_uid: int = 0,
        _opt_struct_types: dict[str, ir.Type] = {};

    def _jac_optional_type(payload: ir.Type) -> ir.Type;
    def _opt_payload_of(t: ir.Type) -> (ir.Type | None);
    def _scan_closure_escapes(nd: uni.UniNode, body: (list | tuple)) -> None;
    def _closure_sig_struct(fnty: ir.FunctionType) -> tuple;
    def _closure_struct_of(val_type: ir.Type) -> (str | None);
    def _closure_cell_struct(slot_type: ir.Type) -> str;
    def _emit_closure_cell(var_name: str, slot_type: ir.Type) -> ir.Value;
    def _emit_closure_thunk(
        target_fn: ir.Function, declared_count: int, cap_info: list
    ) -> ir.Function;

    def _emit_closure_pair(
        target_fn: ir.Function, declared_fnty: ir.FunctionType, cap_info: list
    ) -> (ir.Value | None);

    def _emit_closure_value(var_name: str, nd: uni.UniNode) -> (ir.Value | None);
    def _emit_closure_escape_error(var_name: str, nd: uni.UniNode) -> None;
    def _codegen_closure_call(
        nd: uni.FuncCall, clos_val: ir.Value, struct_name: str
    ) -> (ir.Value | None);

    def _lower_function_type_raw(t: any) -> ir.Type;
    def _apply_static_decorators -> None;
    def _codegen_decorated_call(nd: uni.FuncCall, func_name: str) -> (ir.Value | None);
    def _ability_is_generator(nd: uni.Ability) -> bool;
    def _codegen_yield(nd: uni.YieldExpr) -> (ir.Value | None);
    def _codegen_yield_from(nd: uni.YieldExpr) -> (ir.Value | None);
    def _emit_yield_suspend(v: ir.Value) -> None;
    def _stack_entry_alloca(var_type: ir.Type, name: str) -> ir.Value;
    def _mangled_of(t: any) -> (str | None);
    def _solve_generic_call(ability: uni.Ability, nd: uni.FuncCall) -> (dict | None);
    def _instantiate_generic(nd: uni.FuncCall, func_name: str) -> (ir.Function | None);
    def _stamp_mono_fn(
        ability: uni.Ability, spec_name: str, memo_key: str
    ) -> (ir.Function | None);

    def _instantiate_generic_method(
        nd: uni.FuncCall, owner_arch: str, method_name: str
    ) -> (ir.Function | None);

    def _instantiate_generic_for_target(
        func_name: str, tag_node: uni.UniNode
    ) -> (ir.Function | None);

    def _stamp_mono_method(
        ability: uni.Ability,
        arch_name: str,
        method_name: str,
        spec_name: str,
        memo_key: str
    ) -> (ir.Function | None);

    def _find_source_ability(mod_name: str, func_name: str) -> (uni.Ability | None);
    def _codegen_chained_filter(nd: uni.AtomTrailer) -> (ir.Value | None);
    def _adapter_callee(fn_expr: uni.UniNode) -> (tuple | None);
    def _adapter_clos_parts(clos: ir.Value) -> (tuple | None);
    def _generator_elem_type(nd: uni.Ability) -> (ir.Type | None);
    def _codegen_generator(nd: uni.Ability, func: ir.Function) -> None;
    def _emit_generator_drop_fn(name: str, slots: list[tuple]) -> ir.Function;
    def _abi_sizeof(t: ir.Type) -> int;
    def _codegen_lambda(nd: uni.LambdaExpr) -> (ir.Value | None);
    def _get_or_declare_extern(
        name: str, ret_type: ir.Type, arg_types: list[ir.Type], var_arg: bool = False
    ) -> ir.Function;

    def _get_printf -> ir.Function;
    def _emit_print(nd: uni.FuncCall) -> (ir.Value | None);
    def _emit_isinstance(nd: uni.FuncCall) -> (ir.Value | None);
    def _isinstance_type_name(nd: uni.UniNode) -> (str | None);
    def _emit_isinstance_user(
        nd: uni.FuncCall, operand: ir.Value, names: list[str]
    ) -> (ir.Value | None);

    def _emit_isinstance_mixed(
        nd: uni.FuncCall, operand: ir.Value, tags: list[int], names: list[str]
    ) -> (ir.Value | None);

    def _jacval_tags_for_type(name: str) -> list[int];
    def _get_fmt_string(fmt: str) -> ir.GlobalVariable;
    def _get_snprintf_fmt(fmt: str) -> ir.GlobalVariable;
    def _resolve_jac_type(type_expr: (uni.UniNode | None)) -> ir.Type;
    def _try_resolve_field_type(var: uni.UniNode) -> tuple;
    def _type_base_is_unknown(tb: any) -> bool;
    def _emit_unlowerable_type(type_expr: uni.UniNode, tb: any) -> ir.Type;
    def _lower_type(t: any) -> (ir.Type | None);
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
    def _struct_ptr_pointee_name(val: ir.Value) -> (str | None);
    def _struct_array_elem_ptr(ptr: ir.Value, idx_val: ir.Value) -> ir.Value;
    def _list_elem_llvm_of(expr: (uni.UniNode | None)) -> (ir.Type | None);
    def _iter_elem_llvm_of(expr: (uni.UniNode | None)) -> (ir.Type | None);
    def _typed_elem_llvm_of(
        expr: (uni.UniNode | None), prefix: str
    ) -> (ir.Type | None);

    def _elem_spec_of(expr: (uni.UniNode | None)) -> (str | None);
    def _callee_sig_of(nd: uni.FuncCall) -> (uni.FuncSignature | None);
    def _arch_init_sig_of(type_name: str) -> (uni.FuncSignature | None);
    def _codegen_call_args(nd: uni.FuncCall) -> list;
    def _emit_take_ref(value: ir.Value, op: str, loc: str = "") -> None;
    def _codegen_bound_args(
        nd: uni.FuncCall, func: ir.Function, self_offset: int = 0
    ) -> list;

    def _codegen_varargs_list(
        nd: uni.FuncCall, extras: list, expected: (ir.Type | None)
    ) -> (ir.Value | None);

    def _codegen_kwargs_dict(
        nd: uni.FuncCall, leftover: dict, expected: (ir.Type | None)
    ) -> (ir.Value | None);

    def _default_arg_fallback(t: ir.Type) -> ir.Value;
    def _get_name(nd: (uni.UniNode | None)) -> (str | None);
    def _to_bool(val: ir.Value) -> ir.Value;
    def _jacval_truthy(jv: ir.Value) -> ir.Value;
    def _jacval_is_none(jv: ir.Value, negate: bool) -> ir.Value;
    def _entry_alloca(var_type: ir.Type, name: str) -> ir.Value;
    def _coerce_type(val: ir.Value, target_type: ir.Type) -> ir.Value;
    def _coerce_type_inner(val: ir.Value, target_type: ir.Type) -> ir.Value;
    def _promote_to_float(
        left: ir.Value, right: ir.Value
    ) -> tuple[(ir.Value, ir.Value)];

    def _emit_binary_op(op: str, left: ir.Value, right: ir.Value) -> (ir.Value | None);
    def _emit_arch_dunder_binop(
        op: str, left: ir.Value, right: ir.Value
    ) -> (ir.Value | None);

    def _emit_comparison(
        op: str, left: ir.Value, right: ir.Value, is_float: bool
    ) -> (ir.Value | None);

    def _codegen_int_pow(base: ir.Value, exp: ir.Value) -> ir.Value;
    def _codegen_enum(nd: uni.Enum) -> None;
    def _build_enum_string_table(
        enum_name: str, entries: list, with_values: bool = True
    ) -> None;

    def _codegen_enum_value_lookup(
        enum_name: str, ordinal_val: ir.Value, use_name: bool = False
    ) -> (ir.Value | None);

    def _codegen_atom_trailer(nd: uni.AtomTrailer) -> (ir.Value | None);
    def _codegen_bool_expr(nd: uni.BoolExpr) -> (ir.Value | None);
    def _bool_expr_unify_type(a: ir.Type, b: ir.Type) -> (ir.Type | None);
    def _codegen_ctrl(nd: uni.CtrlStmt) -> None;
    def _codegen_for(nd: uni.InForStmt) -> None;
    def _codegen_for_indexed(
        nd: uni.InForStmt,
        kind: str,
        collection_val: ir.Value,
        helpers: (dict | None),
        var_names: list,
        var_types: list,
        rc_vars: bool,
        coll_release_op: str,
        range_start: (ir.Value | None) = None,
        elem_cast: (ir.Type | None) = None,
        unpack_target: (uni.TupleVal | None) = None,
        range_step: (ir.Value | None) = None
    ) -> None;

    def _codegen_iter_for(nd: uni.IterForStmt) -> None;
    def _codegen_match(nd: uni.MatchStmt) -> None;
    def _match_pattern_cond(
        pat: uni.MatchPattern, subj: ir.Value, subj_ty: (object | None) = None
    ) -> (ir.Value | None);

    def _match_seq_cond(
        pat: uni.MatchSequence, subj: ir.Value, subj_ty: (object | None) = None
    ) -> (ir.Value | None);

    def _match_tuple_seq_cond(
        pat: uni.MatchSequence, subj: ir.Value, subj_ty: (object | None) = None
    ) -> (ir.Value | None);

    def _match_map_cond(
        pat: uni.MatchMapping, subj: ir.Value, subj_ty: (object | None) = None
    ) -> (ir.Value | None);

    def _match_arch_cond(
        pat: uni.MatchArch, subj: ir.Value, subj_ty: (object | None) = None
    ) -> (ir.Value | None);

    def _match_seq_parts(pat: uni.MatchSequence) -> tuple;
    def _match_subj_ty(expr: (uni.UniNode | None)) -> (object | None);
    def _match_elem_ty_of(
        subj_ty: (object | None), prefix: str, idx: int
    ) -> (object | None);

    def _match_cast_elem(elem: ir.Value, elem_ty: (object | None)) -> ir.Value;
    def _match_map_key(kv: uni.MatchKVPair, helpers: dict) -> (ir.Value | None);
    def _match_arch_fields(pat: uni.MatchArch, arch_name: str) -> (list | None);
    def _match_value_eq(subj: ir.Value, value_node: uni.UniNode) -> (ir.Value | None);
    def _bind_match_pattern(
        pat: uni.MatchPattern, subj: ir.Value, subj_ty: (object | None) = None
    ) -> None;

    def _bind_match_capture(cap_name: str, val: ir.Value, owned: bool = False) -> None;
    def _bind_match_seq(
        pat: uni.MatchSequence, subj: ir.Value, subj_ty: (object | None) = None
    ) -> None;

    def _bind_match_map(
        pat: uni.MatchMapping, subj: ir.Value, subj_ty: (object | None) = None
    ) -> None;

    def _bind_match_arch(
        pat: uni.MatchArch, subj: ir.Value, subj_ty: (object | None) = None
    ) -> None;

    def _codegen_if_else_expr(nd: uni.IfElseExpr) -> (ir.Value | None);
    def _codegen_multistring(nd: uni.MultiString) -> (ir.Value | None);
    def _codegen_string(nd: uni.String) -> (ir.Value | None);
    def _codegen_fstring(nd: uni.FString) -> (ir.Value | None);
    def _fstring_spec_text(spec: uni.Expr) -> (str | None);
    def _fstring_spec_to_printf(spec: str, kind: str) -> (tuple | None);
    def _ensure_fmt_kernel -> bool;
    def _get_fmt_kernel_fn(name: str) -> (ir.Function | None);
    def _emit_fstr_repr(val: ir.Value, part: uni.FormattedValue) -> (ir.Value | None);
    def _emit_dyn_spec_format(
        val: ir.Value, spec_val: ir.Value, part: uni.FormattedValue
    ) -> (ir.Value | None);

    def _make_global_string(text: str, name_prefix: str = ".str") -> ir.Value;
    def _forward_declare_archetype_names(module: uni.Module) -> None;
    def _native_archetypes(module: uni.Module) -> list[uni.Archetype];
    def _register_imported_struct_types -> None;
    def _ensure_imported_module_inferred(imported_mod: uni.Module) -> None;
    def _extract_import_module_name(imp: uni.Import) -> (str | None);
    def _walk_imported_module_types(imported_mod: uni.Module) -> None;
    def _walk_imported_module_type_names(imported_mod: uni.Module) -> None;
    def _walk_imported_module_abilities(imported_mod: uni.Module) -> None;
    def _register_imported_hierarchy(imported_mod: uni.Module) -> None;
    def _register_imported_archetype(arch: uni.Archetype) -> None;
    def _forward_declare_archetype_methods(arch: uni.Archetype) -> None;
    def _register_imported_globals(nd: uni.GlobalVars, source_path: str = "") -> None;
    def _forward_declare_imported_ability(nd: uni.Ability) -> None;
    def _register_archetypes(module: uni.Module) -> None;
    def _compute_osp_model(archetypes: list[uni.Archetype]) -> None;
    def _osp_active -> bool;
    def _xmod_osp_help(names: list) -> (str | None);
    def _register_osp_kernel_module -> None;
    def _emit_osp_thunk(arch_name: str, method: uni.Ability) -> None;
    def _emit_osp_setup -> None;
    def _osp_rc_new(struct_name: str) -> (ir.Value | None);
    def _osp_make_immortal(ptr: ir.Value) -> None;
    def _osp_build_slot(trig_tag: int, thunk: ir.Function) -> (ir.Value | None);
    def _osp_build_descriptor(
        struct_name: str, type_tag: int, entry_slots: list, exit_slots: list
    ) -> (ir.Value | None);

    def _osp_build_slot_list(pairs: list) -> ir.Value;
    def _osp_collect_slots(arch_name: str, is_entry: bool) -> list;
    def _osp_emit_h2i_fn(hash_global: ir.GlobalVariable, n: int) -> ir.Function;
    def _osp_emit_callbacks(isa_global: ir.GlobalVariable, n: int) -> dict;
    def _osp_emit_filter_fn(
        isa_global: ir.GlobalVariable, n: int
    ) -> (ir.Function | None);

    def _osp_isa_bases(arch_name: str) -> list[int];
    def _codegen_archetype(nd: uni.Archetype) -> None;
    def _register_static_fields(arch_name: str, archhas: uni.ArchHas) -> None;
    def _forward_declare_method(arch_name: str, method: uni.Ability) -> None;
    def _visit_nonprimary_ancestor_methods(arch: uni.Archetype, declare: bool) -> None;
    def _codegen_method(arch_name: str, method: uni.Ability) -> None;
    def _demote_method_if_unlowerable(
        full_name: str, func: ir.Function, err_mark: int, local_mark: int
    ) -> bool;

    def _codegen_no_sig_method(arch_name: str, method: uni.Ability) -> None;
    def _forward_declare_event_method(arch_name: str, method: uni.Ability) -> None;
    def _codegen_event_method(arch_name: str, method: uni.Ability) -> None;
    def _trigger_member_structs(tag: (uni.UniNode | None)) -> list[str];
    def _trigger_struct_names(method: uni.Ability) -> list[str];
    def _union_layout_conflict(members: list[str]) -> (str | None);
    def _codegen_spawn(nd: uni.BinaryExpr) -> (ir.Value | None);
    def _codegen_kernel_spawn(
        walker_name: str, walker_val: ir.Value, loc_val: ir.Value
    ) -> (ir.Value | None);

    def _codegen_visit(nd: uni.VisitStmt) -> None;
    def _codegen_disengage(nd: uni.DisengageStmt) -> None;
    def _codegen_report(nd: uni.ReportStmt) -> None;
    def _codegen_connect(nd: uni.BinaryExpr) -> (ir.Value | None);
    def _codegen_edge_ref_trailer(nd: uni.EdgeRefTrailer) -> (ir.Value | None);
    def _emit_osp_predicate_filter(
        src: ir.Value, arch_name: str, compares: list[uni.CompareExpr], nd: uni.UniNode
    ) -> (ir.Value | None);

    def _elem_arch_name_of(expr: (uni.UniNode | None)) -> (str | None);
    def _osp_visit_targets(target: uni.UniNode) -> (ir.Value | None);
    def _osp_generic_edge -> (ir.Value | None);
    def _spawn_operand_name(nd: uni.UniNode) -> (str | None);
    def _is_walker_arch(name: str) -> bool;
    def _codegen_instantiation(
        nd: (uni.FuncCall | uni.Name),
        type_name_override: (str | None) = None,
        ctor_params: (list | None) = None
    ) -> (ir.Value | None);

    def _codegen_method_call(nd: uni.FuncCall) -> (ir.Value | None);
    def _emit_obj_str(val: ir.Value) -> (ir.Value | None);
    def _emit_default_obj_repr(val: ir.Value, type_name: str) -> ir.Value;
    def _emit_container_repr(
        val: ir.Value, type_key: (str | None)
    ) -> (ir.Value | None);

    def _repr_fn_for_type_key(type_key: str) -> (ir.Function | None);
    def _repr_str_fn -> ir.Function;
    def _repr_leaf_fn(kind: str) -> (ir.Function | None);
    def _repr_obj_fn(arch_name: str) -> ir.Function;
    def _repr_list_fn(type_key: str) -> (ir.Function | None);
    def _repr_dict_fn(type_key: str) -> (ir.Function | None);
    def _repr_set_fn(type_key: str) -> (ir.Function | None);
    def _repr_tuple_fn(type_key: str) -> (ir.Function | None);
    def _repr_seq_fn(
        fn_name: str,
        cont_ptr_ty: ir.Type,
        elem_fn: ir.Function,
        open_text: str,
        close_text: str,
        empty_text: (str | None)
    ) -> ir.Function;

    def _repr_elem_spec_of_key(elem_key: str) -> (tuple | None);
    def _repr_field_llvm_of_key(field_key: str) -> (ir.Type | None);
    def _split_type_args(s: str, sep: str = ",") -> list[str];
    def _repr_const_str(text: str) -> ir.Value;
    def _repr_acc_concat(acc_slot: ir.Value, piece: ir.Value, own_piece: bool) -> None;
    def _repr_maybe_sep(
        fn: ir.Function, i_val: ir.Value, acc_slot: ir.Value, sep_g: ir.Value
    ) -> None;

    def _repr_call_elem_fn(elem_fn: ir.Function, elem: ir.Value) -> ir.Value;
    def _codegen_field_access(
        obj_val: ir.Value, field_name: str, type_name: str
    ) -> (ir.Value | None);

    def _codegen_field_aug_assign(
        target: uni.AtomTrailer, rhs: ir.Value, aug_op: str
    ) -> (ir.Value | None);

    def _apply_scalar_aug_op(
        current: ir.Value, rhs: ir.Value, aug_op: str
    ) -> (ir.Value | None);

    def _codegen_field_assign(target: uni.AtomTrailer, value: ir.Value) -> None;
    def _emit_key_comparison(
        b: ir.IRBuilder,
        key_type: ir.Type,
        stored_val: ir.Value,
        search_val: ir.Value,
        key_size: int = 0
    ) -> ir.Value;

    def _dict_key_spec(key_type: ir.Type) -> tuple;
    def _dict_val_spec(val_type: ir.Type) -> str;
    def _emit_rc_alloc_container(
        b: ir.IRBuilder,
        container_ptr_type: ir.Type,
        data_types: list,
        initial_cap: int = 8
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

    def _emit_rc_release_elem_loop(
        b: ir.IRBuilder,
        release_fn: ir.Function,
        container_arg: ir.Value,
        data_field_idx: int
    ) -> ir.IRBuilder;

    def _emit_container_new_fn(
        fn_name: str,
        container_ptr_type: ir.Type,
        data_types: list,
        dtor_fn: (ir.Function | None) = None
    ) -> ir.Function;

    def _emit_container_len_fn(
        fn_name: str, container_ptr_type: ir.Type
    ) -> ir.Function;

    def _emit_container_release_fn(
        fn_name: str, container_ptr_type: ir.Type, data_fields: list
    ) -> ir.Function;

    def _emit_linear_search_loop(
        func: ir.Function,
        entry_builder: ir.IRBuilder,
        search_val: ir.Value,
        arr: ir.Value,
        arr_len: ir.Value,
        elem_type: ir.Type,
        elem_size: int = 0
    ) -> tuple;

    def _emit_array_get_fn(
        fn_name: str,
        container_ptr_type: ir.Type,
        elem_type: ir.Type,
        data_field_idx: int
    ) -> ir.Function;

    def _emit_list_helpers(elem_type_name: str, elem_type: ir.Type) -> None;
    def _codegen_list_val(nd: uni.ListVal) -> (ir.Value | None);
    def _codegen_index(
        target_val: ir.Value, index_val: ir.Value, elem_type_name: str
    ) -> (ir.Value | None);

    def _codegen_any_subscript(
        jacval: ir.Value, key_val: ir.Value
    ) -> (ir.Value | None);

    def _codegen_any_len(jacval: ir.Value) -> ir.Value;
    def _codegen_index_set(
        target_val: ir.Value, index_val: ir.Value, value: ir.Value, elem_type_name: str
    ) -> None;

    def _build_vtable(arch_name: str) -> None;
    def _emit_vtable_global(arch_name: str) -> None;
    def _emit_class_name_const(arch_name: str) -> ir.Value;
    def _codegen_class_name(nd: uni.AtomTrailer) -> (ir.Value | None);
    def _mro_of(arch_name: str) -> list[str];
    def _arch_has_vtable(arch_name: str) -> bool;
    def _codegen_virtual_call(
        obj_val: ir.Value, method_name: str, args: list[ir.Value], obj_type_name: str
    ) -> (ir.Value | None);

    def _generate_inherited_method_wrappers -> None;
    def _infer_type_name(val: ir.Value) -> (str | None);
    def _infer_list_elem_type(val: ir.Value) -> (str | None);
    def _infer_compr_elem_struct(compr: object) -> (str | None);
    def _infer_unpack_struct_ptr(nd: object) -> (ir.Type | None);
    def _codegen_string_index(
        target_val: ir.Value, index_val: ir.Value
    ) -> (ir.Value | None);

    def _emit_is_strip_char(ch: ir.Value, charset: (ir.Value | None)) -> ir.Value;
    def _codegen_str_strip_chars(
        str_val: ir.Value, charset: (ir.Value | None), do_left: bool, do_right: bool
    ) -> (ir.Value | None);

    def _codegen_str_split(str_val: ir.Value, sep_val: ir.Value) -> (ir.Value | None);
    def _emit_norm_slice_bounds(
        slice_node: object, src_len: ir.Value
    ) -> (tuple | None);

    def _codegen_list_slice(
        target_val: ir.Value, slice_node: object, elem_type_name: str
    ) -> (ir.Value | None);

    def _codegen_string_slice(
        target_val: ir.Value, slice_node: object
    ) -> (ir.Value | None);

    def _emit_sys_argv -> (ir.Value | None);
    def _emit_sys_stream(stream: str) -> (ir.Value | None);
    def _emit_sys_exit(args: list[ir.Value]) -> (ir.Value | None);
    def _emit_math_call(name: str, nd: uni.FuncCall) -> (ir.Value | None);
    def _emit_math_const(name: str) -> (ir.Value | None);
    def _emit_time_call(name: str, nd: uni.FuncCall) -> (ir.Value | None);
    def _emit_clock_gettime(clock_id: int) -> tuple;
    def _emit_os_call(name: str, nd: uni.FuncCall) -> (ir.Value | None);
    def _emit_os_environ_call(name: str, nd: uni.FuncCall) -> (ir.Value | None);
    def _emit_ospath_call(name: str, nd: uni.FuncCall) -> (ir.Value | None);
    def _mt_ensure -> None;
    def _emit_random_call(name: str, nd: uni.FuncCall) -> (ir.Value | None);
    def _emit_struct_call(name: str, nd: uni.FuncCall) -> (ir.Value | None);
    def _ensure_bytearray_type -> ir.Type;
    def _bytearray_runtime_fns -> dict;
    def _bytearray_src_of(val: ir.Value) -> (tuple | None);
    def _dispatch_bytearray_method(
        method_name: str, recv: ir.Value, nd: uni.FuncCall
    ) -> (ir.Value | None);

    def _emit_struct_pack_into(
        nd: uni.FuncCall,
        params: list,
        fields: list[tuple[str, int, bool]],
        total: int,
        little: bool
    ) -> (ir.Value | None);

    def _emit_struct_pack(
        nd: uni.FuncCall, params: list, fields: list, total: int, little: bool
    ) -> (ir.Value | None);

    def _emit_struct_unpack(
        nd: uni.FuncCall, params: list, fields: list, total: int, little: bool
    ) -> (ir.Value | None);

    def _get_bytes_struct_type -> ir.Type;
    def _bytes_alloc(n: ir.Value) -> ir.Value;
    def _bytes_data_ptr(bv: ir.Value) -> ir.Value;
    def _bytes_len_val(bv: ir.Value) -> ir.Value;
    def _bytes_from_raw(src: ir.Value, n: ir.Value) -> ir.Value;
    def _make_global_bytes(data: bytes) -> ir.Value;
    def _is_bytes_value(v: ir.Value) -> bool;
    def _codegen_bytes_index(bv: ir.Value, idx: ir.Value) -> (ir.Value | None);
    def _codegen_bytes_slice(bv: ir.Value, slice_node: object) -> (ir.Value | None);
    def _emit_bytes_eq(left: ir.Value, right: ir.Value, negate: bool) -> ir.Value;
    def _is_bytes_type(t: ir.Type) -> bool;
    def _emit_bytes_truthy(bv: ir.Value) -> ir.Value;
    def _emit_bytes_repeat(bv: ir.Value, count: ir.Value) -> ir.Value;
    def _emit_bytes_contains(needle: ir.Value, haystack: ir.Value) -> ir.Value;
    def _emit_bytes_cmp(left: ir.Value, right: ir.Value, op_sym: str) -> ir.Value;
    def _emit_bytes_repr(bv: ir.Value) -> ir.Value;
    def _bytes_repr_fn -> ir.Function;
    def _emit_float_repr(fv: ir.Value) -> ir.Value;
    def _float_repr_fn -> ir.Function;
    def _make_bytes_iter(bytes_val: ir.Value) -> ir.Value;
    def _bytes_iter_next_fn -> ir.Function;
    def _define_function(name: str, fnty: ir.FunctionType) -> ir.Function;
    def _codegen_entry(nodes: list[uni.ModuleCode]) -> None;
    def _codegen_tuple_val(nd: uni.TupleVal) -> (ir.Value | None);
    def _codegen_tuple_unpack(
        targets: list, tuple_val: ir.Value, tuple_node: (object | None)
    ) -> bool;

    def _codegen_tuple_index(
        tuple_val: ir.Value, idx_val: ir.Value, struct_type: ir.LiteralStructType
    ) -> (ir.Value | None);

    def _get_struct_size(struct_type: ir.LiteralStructType) -> int;
    def _sizeof_llvm(ty: ir.Type) -> ir.Value;
    def _box_value_tuple(val: ir.Value, loc: str = "") -> ir.Value;
    def _coerce_tuple_to_struct(val: ir.Value, target_struct: ir.Type) -> ir.Value;
    def _codegen_list_compr(nd: uni.ListCompr) -> (ir.Value | None);
    def _codegen_dict_compr(nd: uni.DictCompr) -> (ir.Value | None);
    def _codegen_set_compr(nd: uni.SetCompr) -> (ir.Value | None);
    def _emit_compr_element(
        kind: str,
        acc: ir.Value,
        key_expr: uni.UniNode,
        val_expr: (uni.UniNode | None),
        spec: str
    ) -> None;

    def _codegen_compr_walk(
        comprs: list,
        idx: int,
        kind: str,
        acc: ir.Value,
        key_expr: uni.UniNode,
        val_expr: (uni.UniNode | None),
        spec: str
    ) -> None;

    def _codegen_compr_range_walk(
        inner: uni.InnerCompr,
        comprs: list,
        idx: int,
        kind: str,
        acc: ir.Value,
        key_expr: uni.UniNode,
        val_expr: (uni.UniNode | None),
        spec: str,
        conditionals: list
    ) -> None;

    def _register_globals(module: uni.Module) -> None;
    def _register_entry_globals(module: uni.Module) -> None;
    def _codegen_global_vars(nd: uni.GlobalVars) -> None;
    def _infer_global_init_type(value_node: uni.UniNode) -> (ir.Type | None);
    def _codegen_const_expr(
        nd: uni.UniNode, target_type: ir.Type
    ) -> (ir.Constant | None);

    def _emit_dict_helpers(
        key_type_name: str,
        val_type_name: str,
        key_type: ir.Type,
        val_type: ir.Type,
        key_size: int = 0
    ) -> None;

    def _box_to_jacval(value: ir.Value) -> ir.Value;
    def _unbox_from_jacval(jv: ir.Value, target_type: ir.Type) -> ir.Value;
    def _codegen_dict_val(nd: uni.DictVal) -> (ir.Value | None);
    def _codegen_dict_access(
        target_val: ir.Value, key_val: ir.Value, key_type_name: str, val_type_name: str
    ) -> (ir.Value | None);

    def _codegen_dict_set(
        target_val: ir.Value,
        key_val: ir.Value,
        value: ir.Value,
        key_type_name: str,
        val_type_name: str
    ) -> None;

    def _infer_dict_type(val: ir.Value) -> (tuple | None);
    def _emit_set_helpers(
        elem_type_name: str, elem_type: ir.Type, elem_size: int = 0
    ) -> None;

    def _codegen_set_val(nd: uni.SetVal) -> (ir.Value | None);
    def _get_exception_state_type -> ir.Type;
    def _declare_exception_runtime -> None;
    def _emit_exc_push_helper -> None;
    def _emit_exc_pop_helper -> None;
    def _emit_exc_raise_helper -> None;
    def _emit_runtime_raise(is_error: ir.Value, exc_type_name: str, msg: str) -> None;
    def _get_or_register_exc_type(exc_name: str) -> int;
    def _get_exc_descendants(type_name: str) -> list[str];
    def _codegen_raise(nd: uni.RaiseStmt) -> None;
    def _raise_has_frame_handler(nd: uni.RaiseStmt) -> bool;
    def _codegen_try(nd: uni.TryStmt) -> None;
    def _get_file_struct_type -> ir.Type;
    def _get_binary_file_struct_type -> ir.Type;
    def _register_file_like_struct(name: str) -> ir.Type;
    def _emit_file_helpers -> None;
    def _emit_binary_file_helpers -> None;
    def _emit_file_like_helpers(
        struct_name: str, struct_type: ir.Type, binary: bool
    ) -> None;

    def _emit_open(nd: uni.FuncCall) -> (ir.Value | None);
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
    def _codegen_with(nd: uni.WithStmt) -> None;
    def _codegen_with_recursive(exprs: object, idx: int, body: object) -> None;
    def _process_clib_imports(module: uni.Module) -> None;
    def _resolve_clib_lib_name(components: list[str], level: int) -> str;
    def _declare_clib_ability(nd: uni.Ability) -> None;
    def _resolve_clib_type(type_expr: (uni.UniNode | None)) -> ir.Type;
    def _clib_struct_has_fn_ptr(name: str) -> bool;
    def _clib_detect_vtable_structs -> None;
    def _clib_coerce_callback(val: ir.Value, c_fn_ty: ir.Type) -> ir.Value;
    def _clib_cb_coerce_scalar(val: ir.Value, target_type: ir.Type) -> ir.Value;
    def _emit_clib_c_trampoline(jac_fn: ir.Function, c_fn_ty: ir.Type) -> ir.Function;
    def _clib_alloc_vtable(name: str) -> ir.Value;
    def _clib_struct_layout(name: str) -> tuple;
    def _foreign_model -> dict;
    def _foreign_fns -> dict;
    def _foreign_fields_of(name: str) -> list;
    def _clib_has_nested(name: str) -> bool;
    def _clib_c_type(name: str) -> ir.Type;
    def _clib_materialize_c_ptr(jac_ptr: ir.Value, name: str) -> ir.Value;
    def _clib_box_c_ptr(c_ptr: ir.Value, name: str) -> ir.Value;
    def _clib_copy_jac_to_c(jac_ptr: ir.Value, c_ptr: ir.Value, name: str) -> None;
    def _clib_copy_c_to_jac(c_ptr: ir.Value, jac_ptr: ir.Value, name: str) -> None;
    def _clib_alloc_box(name: str) -> ir.Value;
    def _codegen_clib_call(
        func: ir.Function, func_name: str, args: list[ir.Value]
    ) -> (ir.Value | None);

    def _clib_sext_ret(func_name: str, result: ir.Value) -> ir.Value;
    def _llvm_type_str(ty: ir.Type) -> str;
    def _export_native_layout -> None;
    def _normalize_type_key(key: str) -> str;
    def _record_ret_facts(name: str, sig: uni.FuncSignature) -> None;
    def _ret_tuple_hints(fname: str, ret_tuple: any) -> (list | None);
    def _ensure_emitters -> None;
    def _primitive_method_names(type_name: str) -> set[str];
    def _dispatch_primitive_method(
        type_name: str,
        method_name: str,
        target: ir.Value,
        args: list[ir.Value],
        type_key: str,
        kwargs: (dict | None) = None,
        kw_node: (uni.UniNode | None) = None
    ) -> (ir.Value | None);

    def _dispatch_builtin(
        func_name: str,
        args: list[ir.Value],
        kwargs: (dict | None) = None,
        kw_node: (uni.UniNode | None) = None,
        type_key: str = ""
    ) -> (ir.Value | None);

    def _split_call_kwargs(nd: uni.FuncCall) -> dict;
    def _gc_mode -> str;
    def _emit_rc_helpers -> None;
    def _emit_rc_roots_globals -> None;
    def _emit_trace_fn(arch_name: str) -> None;
    def _register_trace_pair(dtor_fn: object, trace_fn: ir.Function) -> bool;
    def _finalize_trace_lookup -> None;
    def _require_trace_fn(type_name: str, participates: bool, has_trace: bool) -> None;
    def _struct_has_ref_fields(arch_name: str) -> bool;
    def _container_type_name(dtor_fn: object) -> str;
    def _emit_container_trace_fn(
        trace_fn_name: str, container_ptr_type: ir.Type, pointer_data_fields: list
    ) -> ir.Function;

    def _emit_rc_collect_cycles -> None;
    def _emit_rc_color_load(
        b: ir.IRBuilder, obj_i8: ir.Value
    ) -> tuple[ir.Value, ir.Value];

    def _emit_rc_color_store(
        b: ir.IRBuilder, csp: ir.Value, cb: ir.Value, color: int
    ) -> None;

    def _emit_rc_color_reset(b: ir.IRBuilder, csp: ir.Value) -> None;
    def _emit_rc_clear_buffered(b: ir.IRBuilder, csp: ir.Value) -> None;
    def _emit_rc_is_buffered(
        b: ir.IRBuilder, obj_i8: ir.Value, name_prefix: str = "buf"
    ) -> ir.Value;

    def _emit_rc_trace_dispatch(
        fn: ir.Function,
        b: ir.IRBuilder,
        obj_i8: ir.Value,
        visitor_fn: ir.Function,
        done_block: ir.Block
    ) -> None;

    def _emit_rc_simple_visitor(name: str, phase_fn: ir.Function) -> ir.Function;
    def _emit_rc_mark_gray_phase -> ir.Function;
    def _emit_rc_scan_black_phase -> ir.Function;
    def _emit_rc_scan_phase(scan_black_fn: ir.Function) -> ir.Function;
    def _emit_rc_collect_white_phase -> ir.Function;
    def _emit_rc_collect_white_reclaim(
        fn: ir.Function, done_bb: ir.Block, ptr: ir.Value
    ) -> ir.Block;

    def _emit_rc_root_pass(
        prefix: str,
        count: ir.Value,
        next_bb: ir.Block,
        phase_fn: ir.Function,
        clear_purple: bool
    ) -> ir.Block;

    def _emit_rc_collect_loop(
        mark_gray_fn: ir.Function, scan_fn: ir.Function, collect_white_fn: ir.Function
    ) -> None;

    def _rc_alloc(size: ir.Value, name: str = "rc.alloc") -> ir.Value;
    def _emit_rc_retain(ptr: ir.Value, op: str = "", loc: str = "") -> None;
    def _emit_rc_release_simple(ptr: ir.Value, op: str = "", loc: str = "") -> None;
    def _emit_rc_release_typed(val: ir.Value, op: str = "", loc: str = "") -> None;
    def _arch_is_acyclic(arch_name: str) -> bool;
    def _nogc_osp_skip(val: ir.Value) -> bool;
    def _nogc_headerless -> bool;
    def _arch_is_osp_name(arch_name: str) -> bool;
    def _arch_is_walker_name(arch_name: str) -> bool;
    def _emit_struct_drop_fn(type_name: str) -> (ir.Function | None);
    def _emit_struct_drop_fields_fn(type_name: str) -> (ir.Function | None);
    def _emit_container_drop_fn(cont_name: str) -> (ir.Function | None);
    def _emit_arena_helpers -> None;
    def _register_region_handle_var(nd: uni.Assignment, var_name: str) -> None;
    def _region_alloc(size: ir.Value, name: str = "region.alloc") -> ir.Value;
    def _region_log_dtor_if_needed(obj_i8: ir.Value, type_name: str) -> None;
    def _emit_region_handle_drop(alloca: object, var_name: str) -> None;
    def _nogc_emit_drop(val: ir.Value, op: str = "", loc: str = "") -> bool;
    def _nogc_free_scratch(val: ir.Value, op: str) -> None;
    def _emit_last_use_releases(stmt: uni.UniNode) -> None;
    def _stack_alloc_target_ok(nd: uni.UniNode) -> bool;
    def _emit_set_type_tag(b: ir.IRBuilder, ptr_i8: ir.Value, type_name: str) -> None;
    def _emit_magic_check(
        b: ir.IRBuilder, ptr: ir.Value, name_prefix: str = "mc"
    ) -> ir.Value;

    def _mark_owned(val: ir.Value) -> ir.Value;
    def _is_owned(val: ir.Value) -> bool;
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
    def _set_rc_ctx(op: str, loc: str) -> None;
    def _clear_rc_ctx -> None;
    def _rc_strdup(ptr: ir.Value, name: str = "rc.str") -> ir.Value;
    def _emit_struct_release_fn(arch_name: str) -> None;
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

    def _emit_glob_init_func -> None;
    def _attach_di_subprogram(func: ir.Function, name: str, line: int) -> None;
    def _finalize_di_locations(func: ir.Function, fallback_line: int) -> None;
    def post_transform -> None;
}
