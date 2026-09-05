import from jaclang.compiler.backends.native.llvm { ir }
import from jaclang.runtime.scalars { ScalarShape }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.backends.py.module_codegen_pass { ModuleCodegenPass }

obj NaIRGenState(ModuleCodegenPass) {
    has _llvm_module: (ir.Module | None) = None,
        _type_map: (dict[str, ir.Type] | None) = None,
        _complex_struct_type: (ir.Type | None) = None,
        _range_struct_type: (ir.Type | None) = None,
        _slice_struct_type: (ir.Type | None) = None,
        _jacval_type: (ir.Type | None) = None,
        _builder: (ir.IRBuilder | None) = None,
        func_symtab: dict[str, ir.Function] = {},
        local_vars: dict[str, ir.Value] = {},
        param_vars: set[str] = set(),
        _unlowered_locals: dict[str, set[str]] = {},
        flow_future_meta: dict = {},
        drop_fn_registry: dict = {},
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
        clib_fnptr_str_ret: dict[str, set[str]] = {},
        clib_trampoline_funcs: dict[str, ir.Function] = {},
        enum_values: dict[str, ir.Constant] = {},
        enum_types: dict[str, ir.IntType] = {},
        enum_string_values: dict[str, list] = {},
        enum_value_arrays: dict[str, ir.GlobalVariable] = {},
        enum_name_arrays: dict[str, ir.GlobalVariable] = {},
        enum_member_ordinal: dict[str, int] = {},
        enum_int_values: dict[str, list] = {},
        enum_ordinal_fns: dict[str, ir.Function] = {},
        struct_field_enum_type: dict[str, dict] = {},
        struct_field_elem_keys: dict[str, dict] = {},
        loop_stack: list[tuple] = [],
        _loop_coll_seq: int = 0,
        _iter_owned_srcs: (list | None) = None,
        _str_count: int = 0,
        struct_types: dict[str, ir.Type] = {},
        struct_field_indices: dict[str, dict] = {},
        struct_field_order: dict[str, list] = {},
        struct_field_types: dict[str, dict] = {},
        struct_field_defaults: dict[str, object] = {},
        struct_field_foreign: dict[str, set] = {},
        struct_field_opaque: dict[str, dict] = {},
        struct_field_erased_tv: dict[str, dict] = {},
        arch_type_params: dict[str, list] = {},
        struct_field_inline: dict[str, set] = {},
        method_funcs: dict[str, ir.Function] = {},
        static_methods: dict[str, bool] = {},
        static_fields: dict[str, object] = {},
        static_field_types: dict[str, ir.Type] = {},
        func_ret_type_key: dict[str, str] = {},
        func_ret_elem_keys: dict[str, list] = {},
        list_types: dict[str, ir.Type] = {},
        list_helpers: dict[str, dict] = {},
        var_list_elem_struct: dict[str, ir.Type | None] = {},
        _pending_list_elem_struct: (ir.Type | None) = None,
        _self_arch: (str | None) = None,
        parent_field_start: dict[str, dict[str, int]] = {},
        arch_ast_map: dict[str, uni.Archetype] = {},
        vtable_layouts: dict[str, list[str]] = {},
        vtable_method_indices: dict[str, dict] = {},
        vtable_globals: dict[str, ir.GlobalVariable] = {},
        _non_overridden_methods: dict[str, set[str]] = {},
        _struct_source_mod: dict[str, str] = {},
        _struct_source_name: dict[str, str] = {},
        _enum_source_name: dict[str, str] = {},
        _native_skipped_methods: set[str] = set(),
        _capability_demotions: dict[int, list] = {},
        _claimed_capability_demotions: set[int] = set(),
        _sig_decl_kind: (str | None) = None,
        _class_name_consts: dict[str, ir.Value] = {},
        _isa_fn: (ir.Function | None) = None,
        _isa_seq_fn: (ir.Function | None) = None,
        _runtime_class_name_fn: (ir.Function | None) = None,
        _vtable_less_reach: (set[str] | None) = None,
        _short_mro_reach: (dict[str, list[str]] | None) = None,
        osp_type_tag_field: dict[str, int] = {},
        osp_reports_field: dict[str, int] = {},
        osp_thunk_funcs: dict[str, ir.Function] = {},
        _osp_thunk_uid: int = 0,
        imported_osp_archs: dict[str, tuple] = {},
        _osp_kernel_mod: (object | None) = None,
        _osp_graph_mod: (object | None) = None,
        _fmt_kernel_mod: (object | None) = None,
        _osp_rt_global: (ir.GlobalVariable | None) = None,
        _osp_setup_fn: (ir.Function | None) = None,
        _osp_ensure_fn: (ir.Function | None) = None,
        _unit_prefix: str = "",
        _unit_prefixes: dict[str, str] = {},
        _native_dep_paths: list[str] = [],
        _pub_symbols: set[str] = set(),
        _unit_exports: dict[str, tuple] = {},
        _demoted_names: set[str] = set(),
        tuple_types: dict[str, ir.LiteralStructType] = {},
        global_vars: dict[str, ir.GlobalVariable] = {},
        global_var_types: dict[str, ir.Type] = {},
        dict_types: dict[str, ir.Type] = {},
        dict_helpers: dict[str, dict] = {},
        set_types: dict[str, ir.Type] = {},
        set_helpers: dict[str, dict] = {},
        _peer_container_ty: (ir.Type | None) = None,
        _exc_state_type: (ir.Type | None) = None,
        _exc_handler_global: (ir.GlobalVariable | None) = None,
        _exc_push_fn: (ir.Function | None) = None,
        _exc_pop_fn: (ir.Function | None) = None,
        _exc_raise_fn: (ir.Function | None) = None,
        _exc_type_registry: dict[str, int] = {"Exception": 0},
        _exc_type_counter: int = 1,
        _rt_error_msgs: dict[str, ir.GlobalVariable] = {},
        _file_struct_type: (ir.Type | None) = None,
        _file_helpers_emitted: bool = False,
        _binary_file_struct_type: (ir.Type | None) = None,
        _binary_file_helpers_emitted: bool = False,
        _bytes_struct_type: (ir.Type | None) = None,
        _bytes_repr_function: (ir.Function | None) = None,
        _float_repr_function: (ir.Function | None) = None,
        _repr_fns: dict[str, ir.Function] = {},
        _jac_iter_type: (ir.Type | None) = None,
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
        str_len_fn: (ir.Function | None) = None,
        str_truthy_fn: (ir.Function | None) = None,
        str_stamp_fn: (ir.Function | None) = None,
        str_new_fn: (ir.Function | None) = None,
        str_cmp_fn: (ir.Function | None) = None,
        str_cmp3_fn: (ir.Function | None) = None,
        str_fnv_fn: (ir.Function | None) = None,
        str_dup_fn: (ir.Function | None) = None,
        str_len_raw_fn: (ir.Function | None) = None,
        str_wrap_fn: (ir.Function | None) = None,
        str_wrap_raw_fn: (ir.Function | None) = None,
        str_unwrap_fn: (ir.Function | None) = None,
        _str_desc_ty: (ir.Type | None) = None,
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
        rc_stack_promotions: int = 0,
        struct_trace_fns: dict[str, ir.Function] = {},
        struct_release_fns: dict[str, ir.Function] = {},
        tuple_release_fns: dict[str, ir.Function] = {},
        tuple_trace_fns: dict[str, ir.Function] = {},
        struct_drop_fns: dict[str, ir.Function] = {},
        container_drop_fns: dict[str, ir.Function] = {},
        container_layouts: dict[str, dict] = {},
        struct_drop_hooks: dict[str, ir.Function] = {},
        struct_drop_fields_fns: dict[str, ir.Function] = {},
        region_handle_vars: set[str] = set(),
        region_open_stack: list[int] = [],
        rc_region_allocs: int = 0,
        _region_kernel_registered: bool = False,
        _managed_ctor_node: int = 0,
        clib_declared_sigs: dict[str, tuple] = {},
        nogc_no_free_vars: set[str] = set(),
        nogc_owned_str_vars: set[str] = set(),
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
        _func_loc: dict[str, int] = {},
        _func_def_mod: dict[str, str] = {},
        _linked_fn_decls: dict[int, tuple] = {},
        _pyb_base_memo: dict[str, tuple | None] = {},
        _pyb_helper_fns: dict[str, ir.Function] = {},
        lambda_captures: dict[str, list[tuple]] = {},
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
        _ct_bindings: dict = {},
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
        _opt_struct_types: dict[str, ir.Type] = {},
        _loop_rebind_memo: dict[tuple, bool] = {};

    has builder: ir.IRBuilder { getter; }
    has llvm_module: ir.Module { getter; }
    has type_map: dict[str, ir.Type] { getter; }
    has complex_struct_type: ir.Type { getter; }
    has range_struct_type: ir.Type { getter; }
    has slice_struct_type: ir.Type { getter; }
    has jacval_type: ir.Type { getter; }

    def _register_region_kernel -> None abst;
    def _region_kernel_fn(name: str) -> ir.Function abst;
    def _region_i64(val: ir.Value, name: str = "rgn.i64") -> ir.Value abst;
    def _region_ptr(val: ir.Value, name: str = "rgn.p") -> ir.Value abst;
    def _region_new_handle -> ir.Value abst;
    def _region_current -> ir.Value abst;
    def _region_of_value(val: ir.Value) -> ir.Value abst;
    def _region_enter(hdl: ir.Value) -> None abst;
    def _region_leave -> None abst;
    def _emit_region_leaves(count: int) -> None abst;
    def _region_depth -> ir.Value abst;
    def _region_unwind(depth: ir.Value) -> None abst;
    def _region_alloc_object(
        hdl: ir.Value, size: ir.Value, type_name: (str | None)
    ) -> ir.Value abst;

    def _region_partition(hdl: ir.Value) -> ir.Value abst;
    def _region_owns(ptr: ir.Value) -> ir.Value abst;
    def _emit_struct_drop_fields_fn(type_name: str) -> (ir.Function | None) abst;
    def _register_region_handle_var(nd: uni.Assignment, var_name: str) -> None abst;
    def _emit_region_handle_drop(alloca: ir.Value, var_name: str) -> None abst;
    def _lower_partition_unpack(nd: uni.Assignment) -> bool abst;
    def _get_or_declare_extern(
        name: str, ret_type: ir.Type, arg_types: list[ir.Type], var_arg: bool = False
    ) -> ir.Function abst;

    def _get_printf -> ir.Function abst;
    def _emit_print(nd: uni.FuncCall) -> (ir.Value | None) abst;
    def _get_fmt_string(fmt: str) -> ir.GlobalVariable abst;
    def _get_snprintf_fmt(fmt: str) -> ir.GlobalVariable abst;
    def _codegen_multistring(nd: uni.MultiString) -> (ir.Value | None) abst;
    def _codegen_string(nd: uni.String) -> (ir.Value | None) abst;
    def _codegen_fstring(nd: uni.FString) -> (ir.Value | None) abst;
    def _static_str_struct_const(data: bytes) -> tuple abst;
    def _make_global_string(text: str, name_prefix: str = ".str") -> ir.Value abst;
    def _emit_optional_str(
        val: ir.Value, part: (uni.UniNode | None)
    ) -> (ir.Value | None) abst;

    def _codegen_string_index(
        target_val: ir.Value, index_val: ir.Value, len_val: (ir.Value | None) = None
    ) -> (ir.Value | None) abst;

    def _codegen_list_slice(
        target_val: ir.Value, slice_node: uni.Slice, elem_type_name: str
    ) -> (ir.Value | None) abst;

    def _codegen_string_slice(
        target_val: ir.Value, slice_node: uni.Slice, base_node: object = None
    ) -> (ir.Value | None) abst;

    def _emit_sys_argv -> (ir.Value | None) abst;
    def _emit_sys_stream(stream: str) -> (ir.Value | None) abst;
    def _emit_sys_exit(args: list[ir.Value]) -> (ir.Value | None) abst;
    def _float_repr_fn -> ir.Function abst;
    def _ensure_bytearray_type -> ir.Type abst;
    def _bytearray_runtime_fns -> dict abst;
    def _bytearray_src_of(val: ir.Value) -> (tuple | None) abst;
    def _dispatch_bytearray_method(
        method_name: str, recv: ir.Value, nd: uni.FuncCall
    ) -> (ir.Value | None) abst;

    def _emit_struct_pack_into(
        nd: uni.FuncCall,
        params: Sequence[uni.Expr | uni.KWPair],
        fields: list[tuple[str, int, bool]],
        total: int,
        little: bool
    ) -> (ir.Value | None) abst;

    def _get_bytes_struct_type -> ir.Type abst;
    def _bytes_alloc(n: ir.Value) -> ir.Value abst;
    def _bytes_data_ptr(bv: ir.Value) -> ir.Value abst;
    def _bytes_len_val(bv: ir.Value) -> ir.Value abst;
    def _make_global_bytes(data: bytes) -> ir.Value abst;
    def _is_bytes_value(v: ir.Value) -> bool abst;
    def _codegen_bytes_index(bv: ir.Value, idx: ir.Value) -> (ir.Value | None) abst;
    def _codegen_bytes_slice(
        bv: ir.Value, slice_node: uni.Slice
    ) -> (ir.Value | None) abst;

    def _emit_bytes_eq(left: ir.Value, right: ir.Value, negate: bool) -> ir.Value abst;
    def _is_bytes_type(t: ir.Type) -> bool abst;
    def _emit_bytes_truthy(bv: ir.Value) -> ir.Value abst;
    def _emit_bytes_repeat(bv: ir.Value, count: ir.Value) -> ir.Value abst;
    def _emit_bytes_contains(needle: ir.Value, haystack: ir.Value) -> ir.Value abst;
    def _emit_bytes_cmp(left: ir.Value, right: ir.Value, op_sym: str) -> ir.Value abst;
    def _codegen_call(nd: uni.FuncCall) -> (ir.Value | None) abst;
    def _emit_unsupported_builtin_call(nd: uni.FuncCall, func_name: str) -> None abst;
    def _container_type_args(t: any) -> list abst;
    def _spec_from_container_ptr(t: (ir.Type | None)) -> (str | None) abst;
    def _arch_alias_target(nd: (uni.UniNode | None)) -> (str | None) abst;
    def _arch_init_sig_of(type_name: str) -> (uni.FuncSignature | None) abst;
    def _codegen_call_args(nd: uni.FuncCall) -> list abst;
    def _codegen_receiver(nd: (uni.UniNode | None)) -> (ir.Value | None) abst;
    def _emit_take_ref(value: ir.Value, op: str, loc: str = "") -> None abst;
    def _codegen_bound_args(
        nd: uni.FuncCall, func: ir.Function, self_offset: int = 0
    ) -> list abst;

    def _default_arg_fallback(t: ir.Type) -> ir.Value abst;
    def _try_flow_future(nd: uni.ConcurrentExpr) -> (ir.Value | None) abst;
    def _foreign_model -> dict abst;
    def _foreign_fns -> dict abst;
    def _clib_c_type(name: str) -> ir.Type abst;
    def _codegen_clib_call(
        func: ir.Function, func_name: str, args: list[ir.Value]
    ) -> (ir.Value | None) abst;

    def _clib_detect_vtable_structs -> None abst;
    def _clib_coerce_callback(val: ir.Value, c_fn_ty: ir.Type) -> ir.Value abst;
    def _clib_alloc_vtable(name: str) -> ir.Value abst;
    def _lower_clib_function_type(arch_name: str, fname: str, t: any) -> ir.Type abst;
    def _clib_fnptr_arg(val: ir.Value, target: ir.Type) -> ir.Value abst;
    def _clib_fnptr_ret(arch_name: str, fname: str, result: ir.Value) -> ir.Value abst;
    def _scan_closure_escapes(nd: uni.UniNode, body: (list | tuple)) -> None abst;
    def _closure_sig_struct(fnty: ir.FunctionType) -> tuple abst;
    def _closure_struct_of(val_type: ir.Type) -> (str | None) abst;
    def _emit_closure_cell(var_name: str, slot_type: ir.Type) -> ir.Value abst;
    def _emit_closure_pair(
        target_fn: ir.Function, declared_fnty: ir.FunctionType, cap_info: list
    ) -> (ir.Value | None) abst;

    def _emit_closure_value(var_name: str, nd: uni.UniNode) -> (ir.Value | None) abst;
    def _emit_closure_escape_error(var_name: str, nd: uni.UniNode) -> None abst;
    def _codegen_closure_call(
        nd: uni.FuncCall, clos_val: ir.Value, struct_name: str
    ) -> (ir.Value | None) abst;

    def _codegen_list_compr(nd: uni.ListCompr) -> (ir.Value | None) abst;
    def _codegen_dict_compr(nd: uni.DictCompr) -> (ir.Value | None) abst;
    def _codegen_set_compr(nd: uni.SetCompr) -> (ir.Value | None) abst;
    def _emit_key_comparison(
        b: ir.IRBuilder,
        key_type: ir.Type,
        stored_val: ir.Value,
        search_val: ir.Value,
        key_size: int = 0
    ) -> ir.Value abst;

    def _elem_kind(elem_type: ir.Type) -> str abst;
    def _reject_ptr_into_raw_slot(
        nd: (uni.UniNode | None), value: ir.Value, elem_type: ir.Type, what: str
    ) -> bool abst;

    def _spread_operand(nd: (uni.UniNode | None)) -> (uni.Expr | None) abst;
    def _container_src_info(val: (ir.Value | None)) -> (dict | None) abst;
    def _spread_elem_storage(
        src_info: dict, operand: (uni.Expr | None)
    ) -> (ir.Type | None) abst;

    def _reject_spread_slot_mismatch(
        nd: (uni.UniNode | None), src_elem: ir.Type, dest_elem: ir.Type, what: str
    ) -> bool abst;

    def _emit_spread_copy(
        src: ir.Value,
        src_helpers: dict,
        dest: ir.Value,
        dest_helpers: dict,
        dest_kind: str,
        loc: str
    ) -> None abst;

    def _emit_elem_retain(
        b: ir.IRBuilder, elem_type: ir.Type, val: ir.Value
    ) -> None abst;

    def _emit_elem_release(
        b: ir.IRBuilder, elem_type: ir.Type, val: ir.Value
    ) -> None abst;

    def _container_layout_dense(data_types: list) -> dict abst;
    def _container_layout_hash(
        key_type: ir.Type, val_type: (ir.Type | None)
    ) -> dict abst;

    def _container_struct_fields(layout: dict) -> list abst;
    def _emit_live_slot_loop(
        fn: ir.Function,
        b: ir.IRBuilder,
        cont: ir.Value,
        layout: dict,
        tag: str,
        body_cb: Callable[..., ir.IRBuilder],
        fields: (list | None) = None
    ) -> ir.IRBuilder abst;

    def _emit_grow_array(
        b: ir.IRBuilder,
        arr_ptr: ir.Value,
        elem_type: ir.Type,
        cur_len: ir.Value,
        cap_ptr: ir.Value,
        cur_cap: ir.Value
    ) -> ir.Value abst;

    def _emit_rc_destructor_preamble(
        release_fn: ir.Function, ptr_type: ir.Type
    ) -> tuple abst;

    def _emit_container_new_fn(
        fn_name: str,
        container_ptr_type: ir.Type,
        layout: dict,
        dtor_fn: (ir.Function | None) = None
    ) -> ir.Function abst;

    def _emit_container_len_fn(
        fn_name: str, container_ptr_type: ir.Type
    ) -> ir.Function abst;

    def _emit_container_release_fn(
        fn_name: str, container_ptr_type: ir.Type, layout: dict
    ) -> ir.Function abst;

    def _emit_array_get_fn(
        fn_name: str,
        container_ptr_type: ir.Type,
        elem_type: ir.Type,
        data_field_idx: int
    ) -> ir.Function abst;

    def _emit_tuple_box_lifecycle(
        raw: ir.Value, struct_type: ir.LiteralStructType
    ) -> None abst;

    def _codegen_with(nd: uni.WithStmt) -> None abst;
    def _walk_imported_module_types(imported_mod: uni.Module) -> None abst;
    def _walk_imported_module_type_names(imported_mod: uni.Module) -> None abst;
    def _own_prefix -> str abst;
    def _prefix_of_module(mod: (uni.Module | None)) -> str abst;
    def _prefix_of_path(path: str) -> str abst;
    def _symbol_for(
        name: str, owner: (uni.Module | None) = None, is_pub: bool = False
    ) -> str abst;
    def _record_export(
        name: str, symbol: str, kind: str, is_pub: bool = False
    ) -> None abst;
    def _note_native_dep(path: str) -> None abst;
    def _dep_iface(imported_mod: uni.Module) -> any abst;
    def _load_native_unit_module(path: str) -> (uni.Module | None) abst;
    def _is_kernel_unit -> bool abst;
    def _walk_imported_module_abilities(
        imported_mod: uni.Module, with_fn_verdicts: bool = True
    ) -> None abst;

    def _predemote_capability_unit(
        full_name: str, func: ir.Function, viols: list, keep_func: bool = False
    ) -> bool abst;

    def _rename_demoted_symbol(name: str, func: ir.Function) -> None abst;
    def _ensure_emitters -> None abst;
    def _primitive_method_names(type_name: str) -> set[str] abst;
    def _dispatch_primitive_method(
        type_name: str,
        method_name: str,
        target: ir.Value,
        args: list[ir.Value],
        type_key: str,
        kwargs: (dict | None) = None,
        kw_node: (uni.UniNode | None) = None
    ) -> (ir.Value | None) abst;

    def _dispatch_builtin(
        func_name: str,
        args: list[ir.Value],
        kwargs: (dict | None) = None,
        kw_node: (uni.UniNode | None) = None,
        type_key: str = "",
        arg_nodes: (list | None) = None
    ) -> (ir.Value | None) abst;

    def _split_call_kwargs(nd: uni.FuncCall) -> dict abst;
    def _emit_rc_roots_globals -> None abst;
    def _emit_rc_collect_cycles -> None abst;
    def _emit_rc_color_load(
        b: ir.IRBuilder, obj_i8: ir.Value
    ) -> tuple[ir.Value, ir.Value] abst;

    def _emit_rc_is_buffered(
        b: ir.IRBuilder, obj_i8: ir.Value, name_prefix: str = "buf"
    ) -> ir.Value abst;

    def _na_debug_on -> bool abst;
    def _attach_di_subprogram(func: ir.Function, name: str, line: int) -> None abst;
    def _finalize_di_locations(func: ir.Function, fallback_line: int) -> None abst;
    def _dict_key_spec(key_type: ir.Type) -> tuple abst;
    def _dict_val_spec(val_type: ir.Type) -> str abst;
    def _unwrap_opt_container(val: ir.Value) -> ir.Value abst;
    def _emit_dict_helpers(
        key_type_name: str,
        val_type_name: str,
        key_type: ir.Type,
        val_type: ir.Type,
        key_size: int = 0
    ) -> None abst;

    def _emit_dict_order_compact(
        b: ir.IRBuilder,
        fn: ir.Function,
        d_ptr: ir.Value,
        removed_slot: ir.Value,
        new_len: ir.Value,
        i32: ir.Type,
        i64: ir.Type,
        order_idx: int
    ) -> ir.IRBuilder abst;

    def _box_to_jacval(value: ir.Value) -> ir.Value abst;
    def _emit_jacval_release_fn -> ir.Function abst;
    def _unbox_from_jacval(jv: ir.Value, target_type: ir.Type) -> ir.Value abst;
    def _codegen_dict_val(nd: uni.DictVal) -> (ir.Value | None) abst;
    def _codegen_dict_access(
        target_val: ir.Value,
        key_val: ir.Value,
        key_type_name: str,
        val_type_name: str,
        key_node: (uni.UniNode | None) = None
    ) -> (ir.Value | None) abst;

    def _codegen_dict_set(
        target_val: ir.Value,
        key_val: ir.Value,
        value: ir.Value,
        key_type_name: str,
        val_type_name: str,
        key_node: (uni.UniNode | None) = None
    ) -> None abst;

    def _dict_key_reconcile(
        dk: (str | None), val: (ir.Value | None)
    ) -> (str | None) abst;

    def _ensure_enum_lowered(t: any) -> (ir.Type | None) abst;
    def _class_form_enum_self_type(arch_name: str) -> (ir.Type | None) abst;
    def _codegen_class_form_enum_member(nd: uni.AtomTrailer) -> (ir.Value | None) abst;
    def _codegen_enum(nd: (uni.Enum | uni.Archetype)) -> None abst;
    def _codegen_enum_layout(enum_name: str, owner: (uni.Module | None)) -> None abst;
    def _enum_ctor_target(nd: uni.FuncCall) -> (str | None) abst;
    def _codegen_enum_ctor(nd: uni.FuncCall, enum_name: str) -> (ir.Value | None) abst;
    def _wrap_enum_str(raw: (ir.Value | None)) -> (ir.Value | None) abst;
    def _codegen_enum_value_lookup(
        enum_name: str, ordinal_val: ir.Value, use_name: bool = False
    ) -> (ir.Value | None) abst;

    def _codegen_enum_attr_runtime(
        enum_name: str, runtime_val: ir.Value, use_name: bool
    ) -> (ir.Value | None) abst;

    def _get_exception_state_type -> ir.Type abst;
    def _declare_exception_runtime -> None abst;
    def _emit_runtime_raise(
        is_error: ir.Value, exc_type_name: str, msg: str
    ) -> None abst;

    def _get_or_register_exc_type(exc_name: str) -> int abst;
    def _codegen_raise(nd: uni.RaiseStmt) -> None abst;
    def _codegen_try(nd: uni.TryStmt) -> None abst;
    def _codegen_expr(nd: (uni.UniNode | None)) -> (ir.Value | None) abst;
    def _codegen_required(nd: (uni.UniNode | None)) -> (ir.Value | None) abst;
    def _mark_local_unlowered(name: str) -> None abst;
    def _reads_unlowered_local(nd: uni.UniNode) -> bool abst;
    def _codegen_compare_link(
        op: str,
        left: ir.Value,
        right: ir.Value,
        left_node: uni.UniNode,
        right_node: uni.UniNode,
        release_operands: bool = True
    ) -> (ir.Value | None) abst;

    def _codegen_lambda(nd: uni.LambdaExpr) -> (ir.Value | None) abst;
    def _spawn_operand_name(nd: uni.UniNode) -> (str | None) abst;
    def _infer_dict_type(val: ir.Value) -> (tuple | None) abst;
    def _get_file_struct_type -> ir.Type abst;
    def _get_binary_file_struct_type -> ir.Type abst;
    def _emit_file_helpers -> None abst;
    def _emit_open(nd: uni.FuncCall) -> (ir.Value | None) abst;
    def _get_fmt_kernel_fn(name: str) -> (ir.Function | None) abst;
    def _forward_declare_functions(module: uni.Module) -> None abst;
    def _maybe_declare_ability(nd: uni.ElementStmt) -> None abst;
    def _apply_ownership_param_attrs(
        func: ir.Function, params: list[uni.ParamVar], base: int
    ) -> None abst;

    def _codegen_ability(nd: uni.Ability) -> None abst;
    def _codegen_nested_ability(nd: uni.Ability) -> None abst;
    def _codegen_test(nd: uni.Test) -> None abst;
    def _ability_is_generator(nd: uni.Ability) -> bool abst;
    def _define_function(name: str, fnty: ir.FunctionType) -> ir.Function abst;
    def _codegen_entry(nodes: list[uni.ModuleCode]) -> None abst;
    def _declare_clib_ability(nd: uni.Ability) -> None abst;
    def _elem_keys_of_annotation(ann: (uni.UniNode | None)) -> (list | None) abst;
    def _record_ret_facts(name: str, sig: uni.FuncSignature) -> None abst;
    def _emit_glob_init_func -> None abst;
    def _set_rc_ctx(op: str, loc: str) -> None abst;
    def _clear_rc_ctx -> None abst;
    def _emit_live_list_remove(
        b: ir.IRBuilder,
        target_ptr: ir.Value,
        i8_ptr: ir.Type,
        i64_ptr: ir.Type,
        done_bb: ir.Block,
        free_bb: ir.Block
    ) -> None abst;

    def _emit_rc_live_dump -> None abst;
    def _emit_rc_debug_globals -> None abst;
    def _emit_live_node_insert(
        b: ir.IRBuilder, aid: ir.Value, user: ir.Value, tag_raw: ir.Value
    ) -> None abst;

    def _emit_alloc_log_bb(
        func: ir.Function,
        ret_bb: ir.Block,
        aid: ir.Value,
        user: ir.Value,
        size_arg: ir.Value,
        tag_raw: ir.Value
    ) -> ir.Block abst;

    def _emit_retain_log_bb(
        func: ir.Function,
        done_bb: ir.Block,
        ptr: ir.Value,
        old_rc: ir.Value,
        new_rc: ir.Value
    ) -> ir.Block abst;

    def _emit_dbl_free_log_bb(
        func: ir.Function, done_bb: ir.Block, ptr: ir.Value
    ) -> ir.Block abst;

    def _emit_release_log_bb(
        func: ir.Function,
        done_bb: ir.Block,
        ptr: ir.Value,
        old_rc: ir.Value,
        new_rc: ir.Value
    ) -> ir.Block abst;

    def _emit_raw_free_bbs(
        func: ir.Function, done_bb: ir.Block, ptr: ir.Value
    ) -> ir.Block abst;

    def _emit_struct_free_log(
        func: ir.Function,
        log_free_struct_bb: ir.Block,
        actual_free_struct_bb: ir.Block,
        obj_i8: ir.Value,
        obj_raw: ir.Value,
        aid: ir.Value,
        tag: ir.Value
    ) -> None abst;

    def _mangled_of(t: any) -> (str | None) abst;
    def _instantiate_generic(
        nd: uni.FuncCall, func_name: str
    ) -> (ir.Function | None) abst;

    def _instantiate_generic_method(
        nd: uni.FuncCall, owner_arch: str, method_name: str
    ) -> (ir.Function | None) abst;

    def _instantiate_generic_for_target(
        func_name: str, tag_node: uni.UniNode
    ) -> (ir.Function | None) abst;

    def _find_source_ability(
        mod_name: str, func_name: str
    ) -> (uni.Ability | None) abst;

    def _register_enums(module: uni.Module) -> None abst;
    def _register_globals(module: uni.Module) -> None abst;
    def _quiet_glob_type(type_expr: (uni.UniNode | None)) -> (ir.Type | None) abst;
    def _glob_native_use_exists(target: uni.UniNode) -> bool abst;
    def _register_entry_globals(module: uni.Module) -> None abst;
    def _infer_global_init_type(value_node: uni.UniNode) -> (ir.Type | None) abst;
    def _codegen_const_expr(
        nd: uni.UniNode, target_type: ir.Type
    ) -> (ir.Constant | None) abst;

    def _emit_hash_core_helpers(
        family: str,
        type_key: str,
        cont_ptr_type: ir.Type,
        key_type: ir.Type,
        val_type: (ir.Type | None),
        key_type_name: str,
        key_size: int,
        layout: dict
    ) -> dict abst;

    def _tuple_key_fields(key_type: ir.Type) -> (list | None) abst;
    def _tuple_spec_name(struct_type: ir.LiteralStructType) -> str abst;
    def _tuple_key_field_val(
        b: ir.IRBuilder, key_ptr: ir.Value, idx: int, kind: str
    ) -> ir.Value abst;

    def _static_str_hash(key: str) -> int abst;
    def _static_key_op(
        helpers: dict, op: str, key_node: (uni.UniNode | None)
    ) -> tuple abst;

    def _ensure_iter_types -> None abst;
    def _register_iter_struct(
        name: str, field_names: list[str], field_types: list[ir.Type]
    ) -> None abst;

    def _alloc_iter_struct(name: str) -> ir.Value abst;
    def _make_jac_iter(next_fn: ir.Function, state_ptr: ir.Value) -> ir.Value abst;
    def _emit_iter_advance(
        b: ir.IRBuilder, iter_val: ir.Value, out_ptr: ir.Value
    ) -> ir.Value abst;

    def _get_char_cache_gv -> ir.Value abst;
    def _build_iter_from_expr(expr: uni.UniNode) -> (tuple | None) abst;
    def _codegen_next(nd: uni.FuncCall) -> (ir.Value | None) abst;
    def _resolve_method_owner(arch_name: str, method_name: str) -> (str | None) abst;
    def _resolve_method(arch_name: str, method_name: str) -> (ir.Function | None) abst;
    def _try_iter_protocol_for(nd: uni.InForStmt) -> bool abst;
    def _spec_from_list_slot_type(t: (ir.Type | None)) -> (str | None) abst;
    def _reflavor_list(
        val: ir.Value, src_spec: str, dst_spec: str
    ) -> (ir.Value | None) abst;

    def _emit_list_helpers(elem_type_name: str, elem_type: ir.Type) -> None abst;
    def _emit_aos_list_helpers(tname: str) -> ir.Type abst;
    def _codegen_list_val(nd: uni.ListVal) -> (ir.Value | None) abst;
    def _codegen_index(
        target_val: ir.Value, index_val: ir.Value, elem_type_name: str
    ) -> (ir.Value | None) abst;

    def _codegen_any_subscript(
        jacval: ir.Value, key_val: ir.Value
    ) -> (ir.Value | None) abst;

    def _codegen_any_len(jacval: ir.Value) -> ir.Value abst;
    def _codegen_index_set(
        target_val: ir.Value, index_val: ir.Value, value: ir.Value, elem_type_name: str
    ) -> None abst;

    def _codegen_pow(
        base: ir.Value,
        exp: ir.Value,
        exp_node: (uni.Expr | None) = None,
        unsigned: bool = False,
        checked: bool = False
    ) -> ir.Value abst;

    def _emit_math_call(name: str, nd: uni.FuncCall) -> (ir.Value | None) abst;
    def _emit_math_const(name: str) -> (ir.Value | None) abst;
    def _opt_unwrap_attr(obj_val: ir.Value) -> ir.Value abst;
    def _opt_unwrap_iterable(coll_val: (ir.Value | None)) -> (ir.Value | None) abst;
    def _opt_unwrap_subscript(val: (ir.Value | None)) -> (ir.Value | None) abst;
    def _forward_declare_archetype_names(module: uni.Module) -> None abst;
    def _register_archetypes(module: uni.Module) -> None abst;
    def _codegen_archetype(nd: uni.Archetype, imported: bool = False) -> None abst;
    def _build_jc_layout -> dict abst;
    def _forward_declare_method(
        arch_name: str,
        method: uni.Ability,
        field: (uni.HasVar | None) = None,
        imported: bool = False
    ) -> None abst;

    def _codegen_method(
        arch_name: str,
        method: uni.Ability,
        symbol_override: (str | None) = None,
        field: (uni.HasVar | None) = None
    ) -> None abst;

    def _accessor_slot_of(
        type_name: str, field_name: str, kind: str
    ) -> (str | None) abst;

    def _codegen_accessor_call(
        obj_val: ir.Value, type_name: str, slot: str, args: list[ir.Value]
    ) -> (ir.Value | None) abst;

    def _demote_method_if_unlowerable(
        full_name: str,
        func: ir.Function,
        local_mark: int,
        keep_func: bool = False,
        stub_body: bool = True
    ) -> bool abst;

    def _forward_declare_event_method(
        arch_name: str, method: uni.Ability
    ) -> None abst;

    def _codegen_instantiation(
        nd: (uni.FuncCall | uni.Name),
        type_name_override: (str | None) = None,
        ctor_params: (list | None) = None
    ) -> (ir.Value | None) abst;

    def _codegen_method_call(nd: uni.FuncCall) -> (ir.Value | None) abst;
    def _emit_obj_str(val: ir.Value) -> (ir.Value | None) abst;
    def _emit_default_obj_repr(val: ir.Value, type_name: str) -> ir.Value abst;
    def _codegen_field_access(
        obj_val: ir.Value,
        field_name: str,
        type_name: str,
        nd: (uni.UniNode | None) = None
    ) -> (ir.Value | None) abst;

    def _codegen_field_aug_assign(
        target: uni.AtomTrailer,
        rhs: ir.Value,
        aug_op: str,
        rhs_node: (uni.Expr | None) = None
    ) -> (ir.Value | None) abst;

    def _codegen_field_assign(
        target: uni.AtomTrailer, value: ir.Value, skip_narrow_coerce: bool = False
    ) -> None abst;

    def _read_field_or_refuse(
        nd: uni.UniNode, obj_val: ir.Value, field_name: str, arch_name: str
    ) -> (ir.Value | None) abst;

    def _mro_of(arch_name: str) -> list[str] abst;
    def _arch_layout(arch_name: str) -> (ArchetypeLayout | None) abst;
    def _arch_has_vtable(arch_name: str) -> bool abst;
    def _emit_os_call(name: str, nd: uni.FuncCall) -> (ir.Value | None) abst;
    def _emit_os_const(name: str) -> (ir.Value | None) abst;
    def _emit_os_environ_call(name: str, nd: uni.FuncCall) -> (ir.Value | None) abst;
    def _emit_ospath_call(name: str, nd: uni.FuncCall) -> (ir.Value | None) abst;
    def _codegen_chained_filter(nd: uni.AtomTrailer) -> (ir.Value | None) abst;
    def _compute_osp_model(archetypes: list[uni.Archetype]) -> None abst;
    def _xmod_osp_help(names: list) -> (str | None) abst;
    def _register_osp_kernel_module -> None abst;
    def _emit_osp_thunk(arch_name: str, method: uni.Ability) -> None abst;
    def _emit_osp_setup -> None abst;
    def _osp_make_immortal(ptr: ir.Value) -> None abst;
    def _codegen_visit(nd: uni.VisitStmt) -> None abst;
    def _codegen_disengage(nd: uni.DisengageStmt) -> None abst;
    def _codegen_report(nd: uni.ReportStmt) -> None abst;
    def _codegen_connect(nd: uni.BinaryExpr) -> (ir.Value | None) abst;
    def _codegen_disconnect(nd: uni.BinaryExpr) -> (ir.Value | None) abst;
    def _codegen_edge_ref_trailer(nd: uni.EdgeRefTrailer) -> (ir.Value | None) abst;
    def _pyb_base_of(arch_name: str) -> (tuple | None) abst;
    def _pyb_helper(name: str) -> ir.Function abst;
    def _codegen_pyb_field_load(
        nd: uni.AtomTrailer, obj_val: ir.Value, field_name: str
    ) -> (ir.Value | None) abst;

    def _codegen_pyb_field_assign(
        target: uni.AtomTrailer, value: ir.Value, obj_val: ir.Value
    ) -> (ir.Value | None) abst;

    def _codegen_pyb_method_call(
        nd: uni.FuncCall, type_name: str, method_name: str
    ) -> (ir.Value | None) abst;

    def _codegen_pyb_super_call(
        nd: uni.FuncCall, method_name: str
    ) -> (ir.Value | None) abst;

    def _codegen_pyb_shadow_init(
        nd: (uni.FuncCall | uni.Name),
        type_name: str,
        obj_ptr: ir.Value,
        params: Sequence[uni.Expr | uni.KWPair],
        native_fields: dict
    ) -> bool abst;

    def _emit_random_call(name: str, nd: uni.FuncCall) -> (ir.Value | None) abst;
    def _gc_mode -> str abst;
    def _emit_rc_helpers -> None abst;
    def _emit_str_len_helpers -> None abst;
    def _call_str_len(
        b: ir.IRBuilder, ptr: ir.Value, name: str = "s.len"
    ) -> ir.Value abst;

    def _call_str_truthy(
        b: ir.IRBuilder, ptr: ir.Value, name: str = "s.truthy"
    ) -> ir.Value abst;

    def _stamp_str_len(b: ir.IRBuilder, ptr: ir.Value, len_val: ir.Value) -> None abst;
    def _call_str_cmp(
        b: ir.IRBuilder, lhs: ir.Value, rhs: ir.Value, name: str = "s.cmp"
    ) -> ir.Value abst;

    def _call_str_cmp3(
        b: ir.IRBuilder,
        l_data: ir.Value,
        l_len: ir.Value,
        r_data: ir.Value,
        r_len: ir.Value,
        name: str = "s.cmp3"
    ) -> ir.Value abst;

    def _str_cmp_parts_of(val: ir.Value) -> (tuple | None) abst;
    def _call_str_dup(
        b: ir.IRBuilder, ptr: ir.Value, name: str = "s.dup"
    ) -> ir.Value abst;

    def _call_str_len_raw(
        b: ir.IRBuilder, ptr: ir.Value, name: str = "s.rlen"
    ) -> ir.Value abst;

    def _str_desc_type -> ir.Type abst;
    def _str_desc_kind -> str abst;
    def _str_norm(val: ir.Value | None) -> (ir.Value | None) abst;
    def _str_arg(val: ir.Value | None) -> (ir.Value | None) abst;
    def _emit_str_desc_helpers -> None abst;
    def _membrane_str_out(b: ir.IRBuilder, val: ir.Value) -> ir.Value abst;
    def _membrane_str_in(b: ir.IRBuilder, val: ir.Value) -> ir.Value abst;
    def _str_alloc(
        b: ir.IRBuilder, size: ir.Value, name: str = "s.buf"
    ) -> ir.Value abst;

    def _str_finish(b: ir.IRBuilder, buf: ir.Value, len_val: ir.Value) -> None abst;
    def _emit_rc_retain(ptr: ir.Value, op: str = "", loc: str = "") -> None abst;
    def _emit_rc_release_simple(
        ptr: ir.Value, op: str = "", loc: str = ""
    ) -> None abst;

    def _emit_rc_release_typed(
        val: ir.Value, op: str = "", loc: str = ""
    ) -> None abst;

    def _arch_is_acyclic(arch_name: str) -> bool abst;
    def _nogc_headerless -> bool abst;
    def _arch_is_osp_name(arch_name: str) -> bool abst;
    def _arch_is_walker_name(arch_name: str) -> bool abst;
    def _emit_struct_drop_fn(type_name: str) -> (ir.Function | None) abst;
    def _emit_nogc_field_drops(
        b: ir.IRBuilder, type_name: str, _dobj: ir.Value
    ) -> None abst;

    def _emit_container_drop_fn(cont_name: str) -> (ir.Function | None) abst;
    def _nogc_elem_drop_slot_ty -> ir.Type abst;
    def _nogc_stamp_elem_drops(cont: ir.Value | None, elem_mangles: list) -> None abst;
    def _nogc_elem_prep(
        expr: uni.UniNode | None, val: ir.Value | None
    ) -> (ir.Value | None) abst;

    def _nogc_type_arg_mangles(expr: uni.UniNode | None) -> list abst;
    def _nogc_str_free_owned(val: ir.Value) -> None abst;
    def _emit_set_type_tag(
        b: ir.IRBuilder, ptr_i8: ir.Value, type_name: str
    ) -> None abst;

    def _emit_magic_check(
        b: ir.IRBuilder, ptr: ir.Value, name_prefix: str = "mc"
    ) -> ir.Value abst;

    def _mark_owned(val: ir.Value) -> ir.Value abst;
    def _is_owned(val: ir.Value) -> bool abst;
    def _opt_result_owned(val: ir.Value, expr: object) -> bool abst;
    def _can_native_move_lower(nd: object) -> bool abst;
    def _release_owned_operands(
        left_orig: ir.Value, right_orig: ir.Value, op: str = ""
    ) -> None abst;

    def _release_owned_args(call_args: list, op: str = "call_arg") -> None abst;
    def _rc_call_with_ctx(
        fn: ir.Function, args: list, op: str, loc: str = "", name: str = ""
    ) -> ir.Value abst;

    def _emit_scope_cleanup(
        skip_var: (str | None) = None, ret_val: object = None, loc: str = ""
    ) -> None abst;

    def _emit_loop_iter_cleanup(body_locals: list, loc: str = "") -> None abst;
    def _bind_loop_coll_slot(val: ir.Value) -> (str | None) abst;
    def _release_loop_coll_slot(
        var_name: str, op: str = "", loc: str = ""
    ) -> None abst;

    def _rc_strdup(ptr: ir.Value, name: str = "rc.str") -> ir.Value abst;
    def _emit_struct_release_fn(arch_name: str) -> None abst;
    def _emit_container_repr(
        val: ir.Value, type_key: (str | None)
    ) -> (ir.Value | None) abst;

    def _repr_str_fn -> ir.Function abst;
    def _repr_leaf_fn(kind: str) -> (ir.Function | None) abst;
    def _repr_jacval_fn -> (ir.Function | None) abst;
    def _str_jacval_fn -> (ir.Function | None) abst;
    def _emit_set_helpers(
        elem_type_name: str, elem_type: ir.Type, elem_size: int = 0
    ) -> None abst;

    def _codegen_set_val(nd: uni.SetVal) -> (ir.Value | None) abst;
    def _scalar_shape(nd: (uni.UniNode | None)) -> (ScalarShape | None) abst;
    def _is_unsigned_node(nd: (uni.UniNode | None)) -> bool abst;
    def _is_sized_node(nd: (uni.UniNode | None)) -> bool abst;
    def _is_signed_sized_node(nd: (uni.UniNode | None)) -> bool abst;
    def _lower_coercion(nd: uni.Expr, val: ir.Value) -> ir.Value abst;
    def _codegen_sized_cast(nd: uni.FuncCall, name: str) -> (ir.Value | None) abst;
    def _codegen_sized_wrap(nd: uni.FuncCall, name: str) -> (ir.Value | None) abst;
    def _codegen_sized_bound(name: str, attr: str) -> (ir.Value | None) abst;
    def _codegen_wrapping(nd: uni.FuncCall, name: str) -> (ir.Value | None) abst;
    def _codegen_type_name_str(name: str) -> ir.Value abst;
    def _emit_overflow_op(
        op: str, left: ir.Value, right: ir.Value, unsigned: bool
    ) -> ir.Value abst;

    def _emit_checked_neg(val: ir.Value) -> ir.Value abst;
    def _emit_checked_shl(
        left: ir.Value, right: ir.Value, unsigned: bool
    ) -> ir.Value abst;

    def _emit_shr(left: ir.Value, right: ir.Value, unsigned: bool) -> ir.Value abst;
    def _emit_int_divmod(
        left: ir.Value, right: ir.Value, unsigned: bool, trap_min: bool = True
    ) -> tuple[(ir.Value, ir.Value)] abst;

    def _codegen_body(stmts: (list | tuple)) -> None abst;
    def _codegen_if(nd: uni.IfStmt) -> None abst;
    def _apply_scalar_aug_op(
        current: ir.Value,
        rhs: ir.Value,
        aug_op: str,
        rhs_node: (uni.Expr | None) = None,
        unsigned: bool = False,
        checked: bool = False
    ) -> (ir.Value | None) abst;

    def _emit_struct_call(name: str, nd: uni.FuncCall) -> (ir.Value | None) abst;
    def _emit_time_call(name: str, nd: uni.FuncCall) -> (ir.Value | None) abst;
    def _emit_trace_fn(arch_name: str) -> None abst;
    def _register_trace_pair(dtor_fn: object, trace_fn: ir.Function) -> bool abst;
    def _finalize_trace_lookup -> None abst;
    def _require_trace_fn(
        type_name: str, participates: bool, has_trace: bool
    ) -> None abst;

    def _struct_has_ref_fields(arch_name: str) -> bool abst;
    def _codegen_tuple_val(nd: uni.TupleVal) -> (ir.Value | None) abst;
    def _codegen_tuple_unpack(
        targets: list, tuple_val: ir.Value, tuple_node: (object | None)
    ) -> bool abst;

    def _codegen_tuple_index(
        tuple_val: ir.Value, idx_val: ir.Value, struct_type: ir.LiteralStructType
    ) -> (ir.Value | None) abst;

    def _tuple_struct_of_value(
        val: (ir.Value | None)
    ) -> (ir.LiteralStructType | None) abst;

    def _tuple_iter_shape(
        expr: (uni.UniNode | None), val: (ir.Value | None)
    ) -> bool abst;

    def _tuple_iter_seq(
        expr: (uni.UniNode | None), val: (ir.Value | None)
    ) -> (tuple | None) abst;

    def _variadic_tuple_seq_type(type_args: list) -> (ir.Type | None) abst;
    def _tuple_seq_coerce(
        val: ir.Value, target_type: ir.Type
    ) -> (ir.Value | None) abst;

    def _get_struct_size(struct_type: ir.LiteralStructType) -> int abst;
    def _box_value_tuple(val: ir.Value, loc: str = "") -> ir.Value abst;
    def _tuple_managed_fields(struct_type: ir.LiteralStructType) -> list abst;
    def _coerce_tuple_to_struct(
        val: ir.Value, target_struct: ir.Type
    ) -> ir.Value abst;

    def _opt_payload_of(t: ir.Type) -> (ir.Type | None) abst;
    def _opt_ptr_payload_of(t: ir.Type) -> (ir.Type | None) abst;
    def _flow_narrowed_type_of(expr: (uni.UniNode | None)) -> (any | None) abst;
    def _apply_flow_narrowing(nd: uni.UniNode, val: ir.Value) -> ir.Value abst;
    def _stack_entry_alloca(var_type: ir.Type, name: str) -> ir.Value abst;
    def _resolve_jac_type(type_expr: (uni.UniNode | None)) -> ir.Type abst;
    def _resolve_decl_type(
        type_expr: (uni.UniNode | None), value: (uni.UniNode | None)
    ) -> ir.Type abst;

    def _widened_tuple_decl_type(
        type_expr: (uni.UniNode | None), value: (uni.UniNode | None)
    ) -> (ir.Type | None) abst;

    def _resolve_sig_type(type_expr: (uni.UniNode | None)) -> ir.Type abst;
    def _resolve_field_type(var: uni.UniNode) -> ir.Type abst;
    def _foreign_optional_field(tb: any) -> bool abst;
    def _erased_typevar_names(tb: any) -> list[str] abst;
    def _erased_seq_type(tb: any) -> (ir.Type | None) abst;
    def _lower_type(t: any) -> (ir.Type | None) abst;
    def _unify_repr_lowering(reprs: list) -> (ir.Type | None) abst;
    def _type_key_of(expr: (uni.UniNode | None)) -> (str | None) abst;
    def _enum_name_of(expr: (uni.UniNode | None)) -> (str | None) abst;
    def _tuple_key_of(expr: (uni.UniNode | None)) -> (str | None) abst;
    def _set_spec_of(expr: (uni.UniNode | None)) -> (str | None) abst;
    def _dict_key_of(expr: (uni.UniNode | None)) -> (str | None) abst;
    def _list_spec_of(expr: (uni.UniNode | None)) -> (str | None) abst;
    def _struct_name_of(expr: (uni.UniNode | None)) -> (str | None) abst;
    def _struct_name_for_key(tk: (str | None)) -> (str | None) abst;
    def _erased_arch_base(tk: str) -> (str | None) abst;
    def _split_union_key(tk: str) -> list[str] abst;
    def _struct_ptr_pointee_name(val: ir.Value) -> (str | None) abst;
    def _struct_array_elem_ptr(ptr: ir.Value, idx_val: ir.Value) -> ir.Value abst;
    def _list_elem_llvm_of(expr: (uni.UniNode | None)) -> (ir.Type | None) abst;
    def _iter_elem_llvm_of(expr: (uni.UniNode | None)) -> (ir.Type | None) abst;
    def _static_elem_llvm_of(expr: (uni.UniNode | None)) -> (ir.Type | None) abst;
    def _elem_spec_of(expr: (uni.UniNode | None)) -> (str | None) abst;
    def _get_name(nd: (uni.UniNode | None)) -> (str | None) abst;
    def _to_bool(val: ir.Value) -> ir.Value abst;
    def _jacval_is_none(jv: ir.Value, negate: bool) -> ir.Value abst;
    def _entry_alloca(var_type: ir.Type, name: str) -> ir.Value abst;
    def _zero_const(ty: ir.Type) -> ir.Constant abst;
    def _coerce_type(val: ir.Value, target_type: ir.Type) -> ir.Value abst;
    def _promote_to_float(
        left: ir.Value, right: ir.Value, unsigned: bool = False
    ) -> tuple[(ir.Value, ir.Value)] abst;

    def _emit_binary_op(
        op: str,
        left: ir.Value,
        right: ir.Value,
        unsigned: bool = False,
        checked: bool = False
    ) -> (ir.Value | None) abst;

    def _unify_int_widths(
        left: ir.Value, right: ir.Value
    ) -> tuple[(ir.Value, ir.Value)] abst;

    def _emit_comparison(
        op: str, left: ir.Value, right: ir.Value, is_float: bool, unsigned: bool = False
    ) -> (ir.Value | None) abst;

    def _emit_jacval_eq(left: ir.Value, right: ir.Value) -> ir.Value abst;
    def _opt_membership_operand(left: ir.Value, slot_type: ir.Type) -> tuple abst;
    def _codegen_int_floor_divmod(
        left: ir.Value, right: ir.Value
    ) -> tuple[(ir.Value, ir.Value)] abst;

    def _codegen_float_floor_div(left: ir.Value, right: ir.Value) -> ir.Value abst;
    def _codegen_float_floor_mod(left: ir.Value, right: ir.Value) -> ir.Value abst;
    def _elem_storage_llvm(t: any) -> (ir.Type | None) abst;
    def _aos_elem_of(type_expr: uni.UniNode | None) -> (str | None) abst;
    def _infer_type_name(val: ir.Value) -> (str | None) abst;
    def _infer_list_elem_type(val: ir.Value) -> (str | None) abst;
    def _infer_compr_elem_struct(compr: object) -> (str | None) abst;
    def _resolve_clib_type(type_expr: (uni.UniNode | None)) -> ir.Type abst;
    def _build_vtable(arch_name: str) -> None abst;
    def _emit_vtable_global(arch_name: str) -> None abst;
    def _vtable_global_for(arch_name: str) -> (ir.GlobalVariable | None) abst;
    def _vtable_candidates(names: list[str]) -> list[ir.GlobalVariable] abst;
    def _isinstance_needs_class_name(names: list[str]) -> bool abst;
    def _isinstance_unprovable_class(
        names: list[str], operand_arch: (str | None)
    ) -> (str | None) abst;

    def _isinstance_class_name_hit(
        obj_ptr: ir.Value, names: list[str]
    ) -> (ir.Value | None) abst;

    def _codegen_class_name(nd: uni.AtomTrailer) -> (ir.Value | None) abst;
    def _codegen_class_id(receiver: uni.UniNode) -> (ir.Value | None) abst;
    def _codegen_class_ref(nd: uni.Name) -> (ir.Value | None) abst;
    def _isinstance_operand_arch(
        nd: uni.FuncCall, operand: ir.Value
    ) -> (str | None) abst;

    def _emit_isinstance_runtime(
        nd: uni.FuncCall, operand: ir.Value, type_arg: uni.UniNode
    ) -> (ir.Value | None) abst;

    def _codegen_virtual_call(
        obj_val: ir.Value, method_name: str, args: list[ir.Value], obj_type_name: str
    ) -> (ir.Value | None) abst;

    def _generate_inherited_method_wrappers -> None abst;
}
