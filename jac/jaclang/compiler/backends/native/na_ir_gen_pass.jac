import jaclang.compiler.frontend.unitree as uni;
import os;
import sys;
import from jaclang.compiler.backends.native.llvm { binding as llvm, ir }
import from jaclang.compiler.backends.native.primitives_native {
    NativeEmitCtx,
    NativeSetEmitter,
    NativeDictEmitter,
    NativeIntEmitter,
    NativeFloatEmitter
}
import from jaclang.compiler.backends.native.lowering {
    NativeLoweringIssue,
    NativeLoweringKind
}
import from jaclang.runtime.scalars { ScalarShape }
import from jaclang.compiler.passes.transform { Transform }
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
    TypeBase,
    UnionType,
    FunctionType as SemanticFunctionType
}
import from jaclang.compiler.frontend.const_fold { fold_const }
import from jaclang.runtime.osp_model { stable_osp_tag }
import type from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.backends.native.na_constants {
    LIVE_NODE_NEXT_OFF,
    LIVE_NODE_RC_OFF,
    LIVE_NODE_SIZE,
    LIVE_NODE_TAG_OFF,
    LIVE_NODE_USER_OFF,
    NATIVE_OS_FUNCS,
    NATIVE_OSPATH_FUNCS,
    NATIVE_RANDOM_FUNCS,
    NATIVE_STRUCT_FUNCS,
    NATIVE_TIME_FUNCS,
    RC_BUFFERED_BIT,
    RC_COLOR_BLACK,
    RC_COLOR_GRAY,
    RC_COLOR_PURPLE,
    RC_COLOR_SHIFT,
    RC_COLOR_WHITE,
    RC_CYCLE_THRESHOLD
}

obj NativeFinalizer {
    has body: uni.FinallyStmt | None,
        function: ir.Function,
        loop_depth: int,
        handler_depth: int,
        pop_handler: bool = False;
}

obj NativeErrorHandler {
    has dispatch: ir.Block;
}

obj NativeGeneratorHandler(NativeErrorHandler) {
    has state: ir.Value;
}

obj NativeGeneratorCellInit {
    has name: str,
        cell_name: str,
        slot_off: int,
        val_type: ir.Type,
        param_index: int | None = None;
}

obj NativeGeneratorState {
    has resume_fn: ir.Function,
        frame_i8: ir.Value,
        out_i8: ir.Value,
        elem_type: ir.Type,
        func_name: str,
        cursor: int = 8,
        slots: list[tuple[str, int, ir.Type]] = [],
        resume_blocks: list[ir.Block] = [],
        cell_inits: list[NativeGeneratorCellInit] = [];
}

obj NativeBindingState {
    has local_vars: dict[str, ir.Value],
        param_vars: set[str],
        nogc_no_free_vars: set[str],
        nogc_owned_str_vars: set[str],
        region_handle_vars: set[str],
        var_list_elem_struct: dict[str, ir.Type | None],
        closure_cell_vars: set[str],
        closure_cell_handles: dict[str, ir.Value];
}

obj NativeFunctionState {
    has bindings: NativeBindingState,
        _builder: ir.IRBuilder | None,
        func_symtab: dict[str, ir.Function],
        nested_captures: dict[str, tuple[ir.Function, list[tuple[str, str]]]],
        lambda_captures: dict[str, list[tuple[str, ir.Value]]],
        region_open_stack: list[int],
        loop_stack: list[tuple],
        _self_owned: bool,
        _self_arch: str | None,
        _di_current_sp: object,
        _gen_ctx: NativeGeneratorState | None,
        _gen_try_stack: list[NativeGeneratorHandler],
        _slot_try_stack: list[NativeErrorHandler],
        _finally_stack: list[NativeFinalizer],
        _caught_error_stack:
            list[tuple[ir.Function, tuple[ir.Value, ir.Value, ir.Value]]];
}

walker NaIRGenPass(Transform) {
    has prog: JacProgram;
    static has HOST_PASS: bool = True;
    has ir_in: uni.Module,
        _llvm_module: (ir.Module | None) = None,
        _type_map: (dict[str, ir.Type] | None) = None,
        _complex_struct_type: (ir.IdentifiedStructType | None) = None,
        _range_struct_type: (ir.IdentifiedStructType | None) = None,
        _slice_struct_type: (ir.IdentifiedStructType | None) = None,
        _jacval_type: (ir.IdentifiedStructType | None) = None,
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
        enum_string_values: dict[str, list[tuple[str, str, int]]] = {},
        enum_value_arrays: dict[str, ir.GlobalVariable] = {},
        enum_name_arrays: dict[str, ir.GlobalVariable] = {},
        enum_member_ordinal: dict[str, int] = {},
        enum_int_values: dict[str, list[tuple[int, int]]] = {},
        enum_ordinal_fns: dict[str, ir.Function] = {},
        struct_field_enum_type: dict[str, dict] = {},
        struct_field_elem_keys: dict[str, dict] = {},
        loop_stack: list[tuple] = [],
        _loop_coll_seq: int = 0,
        _str_count: int = 0,
        struct_types: dict[str, ir.IdentifiedStructType] = {},
        struct_field_indices: dict[str, dict] = {},
        struct_field_order: dict[str, list] = {},
        struct_field_types: dict[str, dict] = {},
        struct_field_defaults: dict[str, dict[str, uni.Expr]] = {},
        struct_constructor_order: dict[str, list[str]] = {},
        struct_field_foreign: dict[str, set] = {},
        struct_field_opaque: dict[str, dict] = {},
        struct_field_erased_tv: dict[str, dict] = {},
        arch_type_params: dict[str, list] = {},
        struct_field_inline: dict[str, set] = {},
        struct_field_borrow: dict[str, set] = {},
        _subclassed_arch_names: (set[str] | None) = None,
        _aos_deciding: set[str] = set(),
        _self_owned: bool = False,
        _slot_try_stack: list[NativeErrorHandler] = [],
        _finally_stack: list[NativeFinalizer] = [],
        _caught_error_stack:
            list[tuple[ir.Function, tuple[ir.Value, ir.Value, ir.Value]]] = [],
        _exc_context_fn: (ir.Function | None) = None,
        method_funcs: dict[str, ir.Function] = {},
        static_methods: dict[str, bool] = {},
        static_fields: dict[str, ir.GlobalVariable] = {},
        static_field_types: dict[str, ir.Type] = {},
        func_ret_type_key: dict[str, str] = {},
        func_ret_elem_keys: dict[str, list] = {},
        list_types: dict[str, ir.IdentifiedStructType] = {},
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
        _class_name_consts: dict[str, ir.Constant] = {},
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
        _fmt_kernel_mod: (object | None) = None,
        _osp_rt_global: (ir.GlobalVariable | None) = None,
        _osp_setup_fn: (ir.Function | None) = None,
        _osp_ensure_fn: (ir.Function | None) = None,
        _osp_kernel_inited_gv: (ir.GlobalVariable | None) = None,
        _osp_kernel_glob_init_fn: (ir.Function | None) = None,
        tuple_types: dict[str, ir.LiteralStructType] = {},
        global_vars: dict[str, ir.GlobalVariable] = {},
        global_var_types: dict[str, ir.Type] = {},
        dict_types: dict[str, ir.IdentifiedStructType] = {},
        dict_helpers: dict[str, dict] = {},
        set_types: dict[str, ir.IdentifiedStructType] = {},
        set_helpers: dict[str, dict] = {},
        _peer_container_ty: (ir.Type | None) = None,
        _exc_state_type: (ir.Type | None) = None,
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
        str_import_fn: (ir.Function | None) = None,
        str_unwrap_fn: (ir.Function | None) = None,
        str_materialize_fn: (ir.Function | None) = None,
        _str_desc_ty: (ir.IdentifiedStructType | None) = None,
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
        _lowered_type_cache: dict[tuple[TypeBase, str], ir.Type] = {},
        di_file: object = None,
        di_cu: object = None,
        _di_current_sp: object = None,
        _func_loc: dict[str, int] = {},
        _module_functions: dict[tuple[str, str], ir.Function] = {},
        _linked_fn_decls: dict[int, tuple] = {},
        _pyb_base_memo: dict[str, tuple | None] = {},
        _pyb_helper_fns: dict[str, ir.Function] = {},
        lambda_captures: dict[str, list[tuple[str, ir.Value]]] = {},
        _pending_lambda_captures: (list[tuple] | None) = None,
        nested_captures: dict[str, tuple[ir.Function, list[tuple[str, str]]]] = {},
        _nested_predecl: dict = {},
        _bytearray_fns: dict = {},
        generator_fns: dict[str, uni.Ability] = {},
        generic_fns: dict[str, uni.Ability] = {},
        _generic_methods: dict[str, uni.Ability] = {},
        _mono_fns: dict[str, ir.Function] = {},
        _mono_solution: (dict | None) = None,
        _mono_mangle_map: (dict | None) = None,
        _ct_bindings: dict = {},
        _gen_ctx: NativeGeneratorState | None = None,
        _gen_try_stack: list[NativeGeneratorHandler] = [],
        decorated_fns: dict[str, tuple] = {},
        closure_cell_vars: set[str] = set(),
        closure_cell_handles: dict[str, ir.Value] = {},
        closure_sig_registry:
            dict[str, tuple[ir.IdentifiedStructType, ir.FunctionType]] = {},
        _closure_sig_keys: dict[str, str] = {},
        _closure_cell_structs: dict[str, str] = {},
        closure_thunks: dict[str, ir.Function] = {},
        _closure_uid: int = 0,
        _opt_struct_types: dict[str, ir.IdentifiedStructType] = {},
        _loop_rebind_memo: dict[tuple, bool] = {};

    has builder: ir.IRBuilder { getter; }
    has llvm_module: ir.Module { getter; }
    has type_map: dict[str, ir.Type] { getter; }
    has complex_struct_type: ir.IdentifiedStructType { getter; }
    has range_struct_type: ir.IdentifiedStructType { getter; }
    has slice_struct_type: ir.IdentifiedStructType { getter; }
    has jacval_type: ir.IdentifiedStructType { getter; }

    def _register_region_kernel -> None;
    def _region_kernel_fn(name: str) -> ir.Function;
    def _emit_region_tls_slot -> None;
    def _emit_tls_slot(
        slot_name: str,
        get_name: str,
        set_name: str,
        destructor: ir.Function | None = None
    ) -> tuple[ir.Function, ir.Function];

    def _get_exception_context_fn -> ir.Function;
    def _exception_handler_slot(b: ir.IRBuilder) -> ir.Value;
    def _region_i64(val: ir.Value, name: str = "rgn.i64") -> ir.Value;
    def _region_ptr(val: ir.Value, name: str = "rgn.p") -> ir.Value;
    def _region_new_handle -> ir.Value;
    def _region_current -> ir.Value;
    def _region_of_value(val: ir.Value) -> ir.Value;
    def _region_enter(hdl: ir.Value) -> None;
    def _region_leave -> None;
    def _emit_region_leaves(count: int) -> None;
    def _region_depth -> ir.Value;
    def _region_unwind(depth: ir.Value) -> None;
    def _region_alloc_object(
        hdl: ir.Value, size: ir.Value, type_name: (str | None)
    ) -> ir.Value;

    def _region_partition(hdl: ir.Value) -> ir.Value;
    def _region_owns(ptr: ir.Value) -> ir.Value;
    def _emit_region_handle_drop(alloca: ir.Value, var_name: str) -> None;
    def _register_region_handle_var(nd: uni.Assignment, var_name: str) -> None;
    def _lower_partition_unpack(nd: uni.Assignment) -> bool;
    def _emit_struct_drop_fields_fn(type_name: str) -> (ir.Function | None);
    def _get_or_declare_extern(
        name: str, ret_type: ir.Type, arg_types: list[ir.Type], var_arg: bool = False
    ) -> ir.Function;

    def _get_printf -> ir.Function;
    def _emit_print(nd: uni.FuncCall) -> (ir.Value | None);
    def _get_fmt_string(fmt: str) -> ir.GlobalVariable;
    def _get_snprintf_fmt(fmt: str) -> ir.GlobalVariable;
    def _codegen_multistring(nd: uni.MultiString) -> (ir.Value | None);
    def _codegen_string(nd: uni.String) -> (ir.Value | None);
    def _codegen_fstring(nd: uni.FString) -> (ir.Value | None);
    def _fstring_spec_text(spec: uni.Expr) -> (str | None);
    def _fstring_spec_to_printf(spec: str, kind: str) -> (tuple | None);
    def _emit_fstr_repr(val: ir.Value, part: uni.FormattedValue) -> (ir.Value | None);
    def _emit_dyn_spec_format(
        val: ir.Value, spec_val: ir.Value, part: uni.FormattedValue
    ) -> (ir.Value | None);

    def _static_str_struct_const(data: bytes) -> tuple;
    def _make_global_string(text: str, name_prefix: str = ".str") -> ir.Value;
    def _emit_optional_str(
        val: ir.Value, part: (uni.UniNode | None)
    ) -> (ir.Value | None);

    def _codegen_string_index(
        target_val: ir.Value, index_val: ir.Value, len_val: (ir.Value | None) = None
    ) -> (ir.Value | None);

    def _emit_is_strip_char(ch: ir.Value, charset: (ir.Value | None)) -> ir.Value;
    def _codegen_str_strip_chars(
        str_val: ir.Value, charset: (ir.Value | None), do_left: bool, do_right: bool
    ) -> (ir.Value | None);

    def _codegen_str_split(str_val: ir.Value, sep_val: ir.Value) -> (ir.Value | None);
    def _emit_norm_slice_bounds(
        slice_node: uni.Slice, src_len: ir.Value
    ) -> (tuple | None);

    def _codegen_list_slice(
        target_val: ir.Value, slice_node: uni.Slice, elem_type_name: str
    ) -> (ir.Value | None);

    def _codegen_string_slice(
        target_val: ir.Value, slice_node: uni.Slice, base_node: object = None
    ) -> (ir.Value | None);

    def _hl_view_base_licensed(base_node: object) -> bool;
    def _emit_sys_argv -> (ir.Value | None);
    def _emit_sys_stream(stream: str) -> (ir.Value | None);
    def _emit_sys_exit(args: list[ir.Value]) -> (ir.Value | None);
    def _emit_float_repr(fv: ir.Value) -> ir.Value;
    def _emit_opt_repr(opt_val: ir.Value) -> (ir.Value | None);
    def _float_repr_fn -> ir.Function;
    def _ensure_bytearray_type -> ir.Type;
    def _bytearray_runtime_fns -> dict;
    def _bytearray_src_of(val: ir.Value) -> (tuple | None);
    def _dispatch_bytearray_method(
        method_name: str, recv: ir.Value, nd: uni.FuncCall
    ) -> (ir.Value | None);

    def _emit_struct_pack_into(
        nd: uni.FuncCall,
        params: Sequence[uni.Expr | uni.KWPair],
        fields: list[tuple[str, int, bool]],
        total: int,
        little: bool
    ) -> (ir.Value | None);

    def _get_bytes_struct_type -> ir.Type;
    def _bytes_alloc(n: ir.Value) -> ir.Value;
    def _bytes_data_ptr(bv: ir.Value) -> ir.Value;
    def _bytes_len_val(bv: ir.Value) -> ir.Value;
    def _bytes_from_raw(src: ir.Value, n: ir.Value) -> ir.Value;
    def _make_global_bytes(data: bytes) -> ir.Value;
    def _is_bytes_value(v: ir.Value) -> bool;
    def _codegen_bytes_index(bv: ir.Value, idx: ir.Value) -> (ir.Value | None);
    def _codegen_bytes_slice(bv: ir.Value, slice_node: uni.Slice) -> (ir.Value | None);
    def _emit_bytes_eq(left: ir.Value, right: ir.Value, negate: bool) -> ir.Value;
    def _is_bytes_type(t: ir.Type) -> bool;
    def _emit_bytes_truthy(bv: ir.Value) -> ir.Value;
    def _emit_bytes_repeat(bv: ir.Value, count: ir.Value) -> ir.Value;
    def _enter_bindings(inherit: bool = False) -> NativeBindingState;
    def _leave_bindings(state: NativeBindingState, release: bool = False) -> None;
    def _shadow_bindings(names: list[str]) -> None;
    def _enter_function(func: ir.Function) -> NativeFunctionState;
    def _bind_function_parameter(
        name: str, value: ir.Value, borrowed: bool = True, rebound: bool = False
    ) -> None;

    def _leave_function(state: NativeFunctionState) -> None;
    def _emit_bytes_contains(needle: ir.Value, haystack: ir.Value) -> ir.Value;
    def _emit_bytes_cmp(left: ir.Value, right: ir.Value, op_sym: str) -> ir.Value;
    def _emit_bytes_repr(bv: ir.Value) -> ir.Value;
    def _bytes_repr_fn -> ir.Function;
    def _codegen_call(nd: uni.FuncCall) -> (ir.Value | None);
    def _codegen_callable_value(
        nd: uni.FuncCall, value: ir.Value, captures: list[tuple[str, ir.Value]]
    ) -> (ir.Value | None);

    def _codegen_synthetic_call(
        target: uni.Expr,
        params: list[uni.Expr | uni.KWPair],
        origin: uni.Expr,
        result_type: TypeBase | None
    ) -> (ir.Value | None);

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

    def _native_module_call_target(nd: uni.FuncCall) -> tuple[str, str] | None;
    def _emit_unsupported_builtin_call(nd: uni.FuncCall, func_name: str) -> None;
    def _empty_ctor_args_of(nd: uni.FuncCall) -> list;
    def _container_type_args(t: any) -> list;
    def _unwrap_cfg_expr(e: any) -> any;
    def _spec_from_container_ptr(t: (ir.Type | None)) -> (str | None);
    def _call_args_lowered(
        nd: uni.UniNode, func: ir.Function, func_name: str, coerced: list
    ) -> bool;

    def _emit_new(nd: uni.FuncCall) -> (ir.Value | None);
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

    def _clib_reinterpret(val: ir.Value, want: ir.Type, name: str) -> ir.Value;
    def _clib_struct_has_fn_ptr(name: str) -> bool;
    def _clib_detect_vtable_structs -> None;
    def _clib_coerce_callback(val: ir.Value, c_fn_ty: ir.PointerType) -> ir.Value;
    def _clib_cb_coerce_scalar(val: ir.Value, target_type: ir.Type) -> ir.Value;
    def _emit_clib_c_trampoline(
        jac_fn: ir.Function, c_fn_ty: ir.PointerType
    ) -> ir.Function;

    def _clib_alloc_vtable(name: str) -> ir.Value;
    def _lower_clib_function_type(arch_name: str, fname: str, t: any) -> ir.Type;
    def _clib_fnptr_arg(val: ir.Value, target: ir.Type) -> ir.Value;
    def _clib_fnptr_ret(arch_name: str, fname: str, result: ir.Value) -> ir.Value;
    def _scan_closure_escapes(nd: uni.UniNode, body: Sequence[uni.UniNode]) -> None;
    def _closure_sig_struct(
        fnty: ir.FunctionType
    ) -> tuple[str, ir.IdentifiedStructType, ir.FunctionType];

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

    def _codegen_compr_walk_body(
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
    def _emit_elem_trace(
        b: ir.IRBuilder, val: ir.Value, visitor: ir.Value
    ) -> ir.IRBuilder;

    def _container_layout_dense(data_types: list) -> dict;
    def _container_layout_hash(key_type: ir.Type, val_type: (ir.Type | None)) -> dict;
    def _container_struct_fields(layout: dict) -> list;
    def _emit_live_slot_loop(
        fn: ir.Function,
        b: ir.IRBuilder,
        cont: ir.Value,
        layout: dict,
        tag: str,
        body_cb: Callable[..., ir.IRBuilder],
        fields: (list | None) = None,
        reverse: bool = False
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

    def _codegen_with(nd: uni.WithStmt) -> None;
    def _codegen_with_recursive(
        exprs: Sequence[uni.ExprAsItem], idx: int, body: Sequence[uni.CodeBlockStmt]
    ) -> None;

    def postinit -> None;
    def transform(ir_in: uni.Module) -> uni.Module;
    def _run_impl(ir_in: uni.Module) -> uni.Module;
    can run_walk with uni.Module entry;
    def _register_imported_struct_types -> None;
    def _permuted_walk_order(mods: list) -> list;
    def _extract_import_module_name(imp: uni.Import) -> (str | None);
    def _walk_imported_module_types(imported_mod: uni.Module) -> None;
    def _walk_imported_module_type_names(imported_mod: uni.Module) -> None;
    def _walk_imported_module_abilities(
        imported_mod: uni.Module, with_fn_verdicts: bool = True
    ) -> None;

    def _register_imported_hierarchy(imported_mod: uni.Module) -> None;
    def _register_imported_archetype(arch: uni.Archetype) -> None;
    def _forward_declare_archetype_methods(arch: uni.Archetype) -> None;
    def _register_imported_globals(nd: uni.GlobalVars, source_path: str = "") -> None;
    def _forward_declare_imported_ability(
        nd: uni.Ability, unavailable: (set | None) = None, imp_layout: any = None
    ) -> None;

    def _record_linked_decl(func: (ir.Function | None), decl: uni.Ability) -> None;
    def _ensure_dep_inference(dep_mod: uni.Module) -> None;
    def _imported_function_demotions(imported_mod: uni.Module) -> (set | None);
    def _predemote_capability_unit(
        full_name: str, func: ir.Function, viols: list, keep_func: bool = False
    ) -> bool;

    def _rename_demoted_symbol(name: str, func: ir.Function) -> None;
    def _process_clib_imports(module: uni.Module) -> None;
    def _resolve_clib_lib_name(components: list[str], level: int) -> str;
    def _llvm_type_str(ty: ir.Type) -> str;
    def _export_native_layout -> None;
    def _exported_accessors(arch_name: str) -> dict[(str, dict[(str, str)])];
    def _ret_tuple_hints(fname: str, ret_tuple: any) -> (list | None);
    def _ensure_emitters -> dict[str, object];
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
        type_key: str = "",
        arg_nodes: (list | None) = None
    ) -> (ir.Value | None);

    def _split_call_kwargs(nd: uni.FuncCall) -> dict;
    def _ct_ctor_slots(target: uni.UniNode) -> list[tuple[str, uni.UniNode]];
    def _emit_rc_roots_globals -> None;
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

    def _na_debug_on -> bool;
    def _attach_di_subprogram(func: ir.Function, name: str, line: int) -> None;
    def _finalize_di_locations(func: ir.Function, fallback_line: int) -> None;
    def post_transform -> None;
    def _peer_dict_key -> (str | None);
    def _hash_key_spec(key_type: ir.Type) -> tuple[str, int];
    def _dict_val_spec(val_type: ir.Type) -> str;
    def _unwrap_opt_container(val: ir.Value) -> ir.Value;
    def _emit_dict_helpers(
        key_type_name: str,
        val_type_name: str,
        key_type: ir.Type,
        val_type: ir.Type,
        key_size: int = 0
    ) -> None;

    def _emit_dict_order_compact(
        b: ir.IRBuilder,
        fn: ir.Function,
        d_ptr: ir.Value,
        removed_slot: ir.Value,
        new_len: ir.Value,
        i32: ir.Type,
        i64: ir.Type,
        order_idx: int
    ) -> ir.IRBuilder;

    def _emit_order_scan_incr_block(
        b: ir.IRBuilder,
        idx_slot: ir.Value,
        i_cur: ir.Value,
        i64: ir.Type,
        fn: ir.Function,
        scan_bb: ir.Block
    ) -> ir.Block;

    def _box_to_jacval(value: ir.Value) -> ir.Value;
    def _unbox_from_jacval(jv: ir.Value, target_type: ir.Type) -> ir.Value;
    def _codegen_dict_val(nd: uni.DictVal) -> (ir.Value | None);
    def _codegen_dict_access(
        target_val: ir.Value,
        key_val: ir.Value,
        key_type_name: str,
        val_type_name: str,
        key_node: (uni.UniNode | None) = None
    ) -> (ir.Value | None);

    def _codegen_dict_set(
        target_val: ir.Value,
        key_val: ir.Value,
        value: ir.Value,
        key_type_name: str,
        val_type_name: str,
        key_node: (uni.UniNode | None) = None
    ) -> None;

    def _dict_key_reconcile(dk: (str | None), val: (ir.Value | None)) -> (str | None);
    def _ensure_enum_lowered(t: any) -> (ir.Type | None);
    def _method_receiver_type(arch_name: str) -> ir.Type | None;
    def _enum_methods(nd: uni.Enum) -> list[uni.Ability];
    def _register_enum_methods(module: uni.Module, declare: bool) -> None;
    def _codegen_class_form_enum_member(nd: uni.Expr) -> (ir.Value | None);
    def _codegen_enum(nd: (uni.Enum | uni.Archetype)) -> None;
    def _codegen_enum_layout(enum_name: str, owner: (uni.Module | None)) -> None;
    def _enum_ctor_layout(enum_name: str) -> (EnumLayout | None);
    def _enum_ctor_target(nd: uni.FuncCall) -> (str | None);
    def _emit_enum_ctor_refusal(nd: uni.FuncCall, enum_name: str, why: str) -> None;
    def _codegen_enum_ctor(nd: uni.FuncCall, enum_name: str) -> (ir.Value | None);
    def _build_enum_string_table(
        enum_name: str, entries: list, with_values: bool = True
    ) -> None;

    def _wrap_enum_str(raw: (ir.Value | None)) -> (ir.Value | None);
    def _codegen_enum_value_lookup(
        enum_name: str, ordinal_val: ir.Value, use_name: bool = False
    ) -> (ir.Value | None);

    def _enum_is_string_valued(enum_name: str) -> bool;
    def _enum_ordinal_fn(enum_name: str) -> (ir.Function | None);
    def _codegen_enum_ordinal_of(
        enum_name: str, runtime_val: ir.Value
    ) -> (ir.Value | None);

    def _codegen_enum_attr_runtime(
        enum_name: str, runtime_val: ir.Value, use_name: bool
    ) -> (ir.Value | None);

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
    def _codegen_expr(nd: (uni.UniNode | None)) -> (ir.Value | None);
    def _codegen_required(nd: (uni.UniNode | None)) -> (ir.Value | None);
    def _current_fn_key -> (str | None);
    def _mark_local_unlowered(name: str) -> None;
    def _reads_unlowered_local(nd: uni.UniNode) -> bool;
    def _codegen_name(nd: uni.Name) -> (ir.Value | None);
    def _ct_type_param_owner(nd: uni.Name) -> (str | None);
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

    def _identity_over_optional(
        left: ir.Value, right: ir.Value, negate: bool
    ) -> (ir.Value | None);

    def _codegen_unary(nd: uni.UnaryExpr) -> (ir.Value | None);
    def _codegen_yield(nd: uni.YieldExpr) -> (ir.Value | None);
    def _codegen_yield_from(nd: uni.YieldExpr) -> (ir.Value | None);
    def _emit_yield_suspend(v: ir.Value) -> None;
    def _codegen_lambda(nd: uni.LambdaExpr) -> (ir.Value | None);
    def _codegen_atom_trailer(nd: uni.AtomTrailer) -> (ir.Value | None);
    def _codegen_bool_expr(nd: uni.BoolExpr) -> (ir.Value | None);
    def _bool_expr_unify_type(a: ir.Type, b: ir.Type) -> (ir.Type | None);
    def _codegen_if_else_expr(nd: uni.IfElseExpr) -> (ir.Value | None);
    def _codegen_spawn(nd: uni.BinaryExpr) -> (ir.Value | None);
    def _codegen_kernel_spawn(
        walker_name: str, walker_val: ir.Value, loc_val: ir.Value
    ) -> (ir.Value | None);

    def _spawn_operand_name(nd: uni.UniNode) -> (str | None);
    def _is_walker_arch(name: str) -> bool;
    def _infer_dict_type(val: ir.Value) -> (tuple | None);
    def _get_file_struct_type -> ir.Type;
    def _get_binary_file_struct_type -> ir.Type;
    def _register_file_like_struct(name: str) -> ir.Type;
    def _emit_file_helpers -> None;
    def _emit_binary_file_helpers -> None;
    def _emit_file_like_helpers(
        struct_name: str, struct_type: ir.Type, binary: bool
    ) -> None;

    def _emit_open(nd: uni.FuncCall) -> (ir.Value | None);
    def _ensure_fmt_kernel -> bool;
    def _get_fmt_kernel_fn(name: str) -> (ir.Function | None);
    def _forward_declare_functions(module: uni.Module) -> None;
    def _maybe_declare_ability(nd: uni.ElementStmt) -> None;
    def _apply_ownership_param_attrs(
        func: ir.Function, params: list[uni.ParamVar], base: int
    ) -> None;

    def _codegen_ability(nd: uni.Ability) -> None;
    def _codegen_nested_ability(nd: uni.Ability) -> None;
    def _predeclare_nested_siblings(nd: uni.Ability) -> None;
    def _codegen_test(nd: uni.Test) -> None;
    def _apply_static_decorators -> None;
    def _ability_is_generator(nd: uni.Ability) -> bool;
    def _generator_elem_type(nd: uni.Ability) -> (ir.Type | None);
    def _codegen_generator(nd: uni.Ability, func: ir.Function) -> None;
    def _emit_generator_drop_fn(name: str, slots: list[tuple]) -> ir.Function;
    def _define_function(name: str, fnty: ir.FunctionType) -> ir.Function;
    def _codegen_entry(nodes: list[uni.ModuleCode]) -> None;
    def _declare_clib_ability(nd: uni.Ability) -> None;
    def _normalize_type_key(key: str) -> str;
    def _elem_keys_of_annotation(ann: (uni.UniNode | None)) -> (list | None);
    def _record_ret_facts(name: str, sig: uni.FuncSignature) -> None;
    def _emit_glob_init_func -> None;
    def _set_rc_ctx(op: str, loc: str) -> None;
    def _clear_rc_ctx -> None;
    def _emit_live_list_remove(
        b: ir.IRBuilder,
        target_ptr: ir.Value,
        i8_ptr: ir.Type,
        i64_ptr: ir.Type,
        done_bb: ir.Block,
        free_bb: ir.Block
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

    def _ct_eval -> any;
    def _ct_value_with_bindings(nd: uni.Expr) -> tuple;
    def _ct_native_const(v: any, nd: uni.Expr) -> (ir.Value | None);
    def _ct_fold(nd: (uni.UniNode | None)) -> (ir.Value | None);
    def _ct_origin(nd: uni.Expr) -> bool;
    def _ct_only_name(nd: uni.Name) -> bool;
    def _ability_has_ct_params(ability: uni.Ability) -> bool;
    def _solve_ct_args(ability: uni.Ability, nd: uni.FuncCall) -> (dict | None);
    def _bind_ct_target(tgt: uni.UniNode, v: any) -> None;
    def _mangled_of(t: any) -> (str | None);
    def _syntactic_bind_type_params(
        tag_node: (uni.UniNode | None), actual: any, tp_names: list[str], solution: dict
    ) -> None;

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
    def _register_enums(module: uni.Module) -> None;
    def _register_globals(module: uni.Module) -> None;
    def _quiet_glob_type(type_expr: (uni.UniNode | None)) -> (ir.Type | None);
    def _glob_native_use_exists(target: uni.UniNode) -> bool;
    def _register_entry_globals(module: uni.Module) -> None;
    def _codegen_global_vars(nd: uni.GlobalVars) -> None;
    def _infer_global_init_type(value_node: uni.UniNode) -> (ir.Type | None);
    def _codegen_const_expr(
        nd: uni.UniNode, target_type: ir.Type
    ) -> (ir.Constant | None);

    def _emit_hash_core_helpers(
        family: str,
        type_key: str,
        cont_ptr_type: ir.Type,
        key_type: ir.Type,
        val_type: (ir.Type | None),
        key_type_name: str,
        key_size: int,
        layout: dict
    ) -> dict;

    def _str_fnv_fn -> ir.Function;
    def _tuple_key_fields(key_type: ir.Type) -> list[tuple[int, str]] | None;
    def _emit_tuple_key_hash(b: ir.IRBuilder, value: ir.Value) -> ir.Value;
    def _tuple_spec_name(struct_type: ir.LiteralStructType) -> str;
    def _tuple_key_field_val(
        b: ir.IRBuilder, key_ptr: ir.Value, idx: int, kind: str
    ) -> ir.Value;

    def _static_str_hash(key: str) -> int;
    def _static_key_hash_of(key_node: (uni.UniNode | None)) -> (int | None);
    def _static_key_op(
        helpers: dict, op: str, key_node: (uni.UniNode | None)
    ) -> tuple;

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
    def _make_collection_iter(
        next_fn: ir.Function, state_name: str, collection: ir.Value
    ) -> ir.Value;

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
    def _spec_from_list_slot_type(t: (ir.Type | None)) -> (str | None);
    def _reflavor_list(
        val: ir.Value, src_spec: str, dst_spec: str
    ) -> (ir.Value | None);

    def _cast_to_list_elem(
        b: any, val: ir.Value, elem_type: ir.Type, name: str
    ) -> ir.Value;

    def _empty_list_dest_spec(nd: uni.ListVal) -> (str | None);
    def _emit_list_helpers(elem_type_name: str, elem_type: ir.Type) -> None;
    def _emit_aos_list_helpers(tname: str) -> ir.Type;
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

    def _codegen_int_pow(
        base: ir.Value, exp: ir.Value, unsigned: bool = False, checked: bool = False
    ) -> ir.Value;

    def _emit_float_pow(
        base: ir.Value, exp: ir.Value, unsigned: bool = False
    ) -> ir.Value;

    def _emit_pow_zero_guard(base: ir.Value) -> None;
    def _codegen_pow(
        base: ir.Value,
        exp: ir.Value,
        exp_node: (uni.Expr | None) = None,
        unsigned: bool = False,
        checked: bool = False
    ) -> ir.Value;

    def _emit_math_call(name: str, nd: uni.FuncCall) -> (ir.Value | None);
    def _emit_math_const(name: str) -> (ir.Value | None);
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
    def _codegen_archetype(nd: uni.Archetype) -> None;
    def _register_static_fields(arch_name: str, archhas: uni.ArchHas) -> None;
    def _register_class_consts(
        nd: uni.Archetype, arch_name: str, block: uni.ModuleCode
    ) -> None;

    def _build_jc_layout -> str;
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
    def _mark_reference_owned(result: ir.Value) -> ir.Value;
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
    def _jc_reference_schema(
        ft: ir.Type, layouts: dict, semantic: TypeBase | None = None
    ) -> (dict | None);

    def _codegen_union_member(
        obj_val: ir.Value, field_name: str, nd: uni.AtomTrailer, parts: list[str]
    ) -> (ir.Value | None);

    def _narrow_receiver_ptr(obj_val: ir.Value, type_name: str) -> (ir.Value | None);
    def _class_const_global(
        arch_name: str, field_name: str
    ) -> (ir.GlobalVariable | None);

    def _class_const_variants(
        arch_name: str, field_name: str
    ) -> tuple[list[tuple[str, ir.GlobalVariable, ir.GlobalVariable]], bool];

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
        target: uni.AtomTrailer,
        value: ir.Value,
        skip_narrow_coerce: bool = False,
        value_node: (uni.Expr | None) = None
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
    def _emit_os_call(name: str, nd: uni.FuncCall) -> (ir.Value | None);
    def _emit_os_const(name: str) -> (ir.Value | None);
    def _emit_os_environ_call(name: str, nd: uni.FuncCall) -> (ir.Value | None);
    def _emit_ospath_call(name: str, nd: uni.FuncCall) -> (ir.Value | None);
    def _codegen_chained_filter(nd: uni.AtomTrailer) -> (ir.Value | None);
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
    def _osp_emit_callbacks -> dict;
    def _osp_pred_pair(
        arch_name: str, compares: list[uni.CompareExpr], nd: uni.UniNode
    ) -> (ir.Value | None);

    def _osp_type_pair(ntag: int) -> (ir.Value | None);
    def _codegen_visit(nd: uni.VisitStmt) -> None;
    def _codegen_disengage(nd: uni.DisengageStmt) -> None;
    def _codegen_report(nd: uni.ReportStmt) -> None;
    def _codegen_connect(nd: uni.BinaryExpr) -> (ir.Value | None);
    def _codegen_disconnect(nd: uni.BinaryExpr) -> (ir.Value | None);
    def _osp_disc_list_operand(expr: (uni.UniNode | None)) -> bool;
    def _codegen_edge_ref_trailer(nd: uni.EdgeRefTrailer) -> (ir.Value | None);
    def _elem_arch_name_of(expr: (uni.UniNode | None)) -> (str | None);
    def _osp_visit_targets(target: uni.UniNode) -> (ir.Value | None);
    def _osp_generic_edge -> (ir.Value | None);
    def _pyb_base_of(arch_name: str) -> (tuple | None);
    def _pyb_shadow_postinit_owner(arch_name: str) -> (str | None);
    def _pyb_native_override_owner(arch_name: str, meth: str) -> (str | None);
    def _pyb_shadowed_dispatch(arch_name: str, method_name: str) -> (tuple | None);
    def _pyb_helper(name: str) -> ir.Function;
    def _pyb_emit_conv1(
        name: str,
        cfn: ir.Function,
        arg_ty: ir.Type,
        ret_ty: ir.Type,
        gil_on: ir.Function,
        gil_off: ir.Function
    ) -> ir.Function;

    def _pyb_cstr(text: str) -> ir.Value;
    def _pyb_owner_addr(obj_val: ir.Value) -> ir.Value;
    def _pyb_shadow_of_val(obj_val: ir.Value) -> ir.Value;
    def _pyb_to_py(nd: (uni.UniNode | None), val: ir.Value) -> (ir.Value | None);
    def _pyb_ret_key(nd: uni.FuncCall) -> (str | None);
    def _pyb_from_py(handle: ir.Value, type_key: (str | None)) -> (ir.Value | None);
    def _pyb_build_args(
        params: Sequence[uni.Expr | uni.KWPair], skip_kwargs: bool = False
    ) -> (tuple | None);

    def _pyb_bridge_call(fn_name: str, args: list[ir.Value]) -> ir.Value;
    def _codegen_pyb_field_load(
        nd: uni.AtomTrailer, obj_val: ir.Value, field_name: str
    ) -> (ir.Value | None);

    def _codegen_pyb_field_assign(
        target: uni.AtomTrailer, value: ir.Value, obj_val: ir.Value
    ) -> (ir.Value | None);

    def _codegen_pyb_method_call(
        nd: uni.FuncCall, type_name: str, method_name: str
    ) -> (ir.Value | None);

    def _codegen_pyb_super_call(
        nd: uni.FuncCall, method_name: str
    ) -> (ir.Value | None);

    def _codegen_pyb_shadow_init(
        nd: (uni.FuncCall | uni.Name),
        type_name: str,
        obj_ptr: ir.Value,
        params: Sequence[uni.Expr | uni.KWPair],
        native_fields: dict
    ) -> bool;

    def _mt_ensure -> None;
    def _emit_random_call(name: str, nd: uni.FuncCall) -> (ir.Value | None);
    def _emit_jacval_slot_drop_fn(elem_mangle: str) -> (ir.Function | None);
    def _drop_fn_for(mangle: str) -> (ir.Function | None);
    def _drop_spec_for_mangle(mangle: str) -> (tuple | None);
    def _nogc_type_arg_mangles_of_str(m: str) -> list[str];
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

    def _str_cmp_parts_of(val: ir.Value) -> (tuple[ir.Value, ir.Value] | None);
    def _emit_str_dup_helper -> None;
    def _call_str_dup(b: ir.IRBuilder, ptr: ir.Value, name: str = "s.dup") -> ir.Value;
    def _emit_str_len_raw_helper -> None;
    def _call_str_len_raw(
        b: ir.IRBuilder, ptr: ir.Value, name: str = "s.rlen"
    ) -> ir.Value;

    def _str_desc_type -> ir.IdentifiedStructType;
    def _str_desc_kind -> str;
    def _str_norm(val: ir.Value) -> ir.Value;
    def _str_materialize(val: ir.Value) -> ir.Value;
    def _str_norm_optional(val: ir.Value | None) -> (ir.Value | None);
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
    def _arch_is_osp_name(arch_name: str) -> bool;
    def _arch_is_walker_name(arch_name: str) -> bool;
    def _emit_struct_drop_fn(type_name: str) -> (ir.Function | None);
    def _emit_nogc_field_drops(
        b: ir.IRBuilder, type_name: str, _dobj: ir.Value
    ) -> None;

    def _emit_container_drop_fn(cont_name: str) -> (ir.Function | None);
    def _nogc_elem_drop_slot_ty -> ir.Type;
    def _nogc_stamp_elem_drops(cont: ir.Value | None, elem_mangles: list) -> None;
    def _nogc_elem_prep(
        expr: uni.UniNode | None, val: ir.Value | None
    ) -> (ir.Value | None);

    def _nogc_type_arg_mangles(expr: uni.UniNode | None) -> list[str];
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

    def _release_owned_args(call_args: list[ir.Value], op: str = "call_arg") -> None;
    def _rc_call_with_ctx(
        fn: ir.Function, args: list, op: str, loc: str = "", name: str = ""
    ) -> ir.Value;

    def _emit_scope_cleanup(
        skip_var: (str | None) = None, ret_val: object = None, loc: str = ""
    ) -> None;

    def _emit_loop_iter_cleanup(body_locals: list, loc: str = "") -> None;
    def _bind_loop_coll_slot(val: ir.Value) -> (str | None);
    def _release_loop_coll_slot(var_name: str, op: str = "", loc: str = "") -> None;
    def _rc_strdup(ptr: ir.Value, name: str = "rc.str", raw: bool = False) -> ir.Value;
    def _emit_struct_release_fn(arch_name: str) -> None;
    def _emit_container_repr(
        val: ir.Value, type_key: (str | None)
    ) -> (ir.Value | None);

    def _repr_fn_for_type_key(type_key: str) -> (ir.Function | None);
    def _repr_str_fn -> ir.Function;
    def _repr_leaf_fn(kind: str) -> (ir.Function | None);
    def _repr_jacval_fn -> (ir.Function | None);
    def _str_jacval_fn -> (ir.Function | None);
    def _runtime_repr_key(val: ir.Value) -> (str | None);
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
        empty_text: (str | None),
        get_fn: (ir.Function | None) = None
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
    def _emit_set_helpers(
        elem_type_name: str, elem_type: ir.Type, elem_size: int = 0
    ) -> None;

    def _codegen_set_val(nd: uni.SetVal) -> (ir.Value | None);
    def _int_width_of(val: ir.Value) -> int;
    def _scalar_shape(nd: (uni.UniNode | None)) -> (ScalarShape | None);
    def _scalar_shape_named(name: (str | None)) -> (ScalarShape | None);
    def _is_unsigned_node(nd: (uni.UniNode | None)) -> bool;
    def _is_sized_node(nd: (uni.UniNode | None)) -> bool;
    def _is_signed_sized_node(nd: (uni.UniNode | None)) -> bool;
    def _scalar_llvm(shape: ScalarShape) -> ir.Type;
    def _lower_coercion(nd: uni.Expr, val: ir.Value) -> ir.Value;
    def _convert_scalar(val: ir.Value, src: ScalarShape, dst: ScalarShape) -> ir.Value;
    def _codegen_sized_cast(nd: uni.FuncCall, name: str) -> (ir.Value | None);
    def _codegen_sized_wrap(nd: uni.FuncCall, name: str) -> (ir.Value | None);
    def _codegen_sized_bound(name: str, attr: str) -> (ir.Value | None);
    def _codegen_wrapping(nd: uni.FuncCall, name: str) -> (ir.Value | None);
    def _codegen_type_name_str(name: str) -> ir.Value;
    def _emit_checked_int_cast(
        val: ir.Value, src: ScalarShape, dst: ScalarShape
    ) -> ir.Value;

    def _emit_float_to_int_cast(
        val: ir.Value, src: ScalarShape, dst: ScalarShape
    ) -> ir.Value;

    def _emit_wrap_to(val: ir.Value, src: ScalarShape, dst: ScalarShape) -> ir.Value;
    def _emit_overflow_op(
        op: str, left: ir.Value, right: ir.Value, unsigned: bool
    ) -> ir.Value;

    def _emit_checked_neg(val: ir.Value) -> ir.Value;
    def _emit_checked_abs(val: ir.Value) -> ir.Value;
    def _emit_shift_count_check(count: ir.Value, width: int) -> None;
    def _shift_count_as(count: ir.Value, target: ir.IntType) -> ir.Value;
    def _emit_checked_shl(left: ir.Value, right: ir.Value, unsigned: bool) -> ir.Value;
    def _emit_shr(left: ir.Value, right: ir.Value, unsigned: bool) -> ir.Value;
    def _emit_int_divmod(
        left: ir.Value, right: ir.Value, unsigned: bool, trap_min: bool = True
    ) -> tuple[(ir.Value, ir.Value)];

    def _codegen_body(stmts: Sequence[uni.UniNode]) -> None;
    def _codegen_stmt(nd: uni.UniNode) -> None;
    def _codegen_return(nd: uni.ReturnStmt) -> None;
    def _codegen_delete(nd: uni.DeleteStmt) -> None;
    def _codegen_destroy_target(target: uni.Expr, nd: uni.DeleteStmt) -> None;
    def _del_target_holds_graph(target: uni.Expr) -> bool;
    def _codegen_delete_location(target: uni.AtomTrailer, nd: uni.DeleteStmt) -> None;
    def _codegen_if(nd: uni.IfStmt) -> None;
    def _codegen_switch(nd: uni.SwitchStmt) -> None;
    def _codegen_while(nd: uni.WhileStmt) -> None;
    def _codegen_open_stmt(nd: uni.OpenStmt) -> None;
    def _codegen_forever(nd: uni.ForeverStmt) -> None;
    def _codegen_assignment(nd: uni.Assignment) -> None;
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
        pat: uni.MatchPattern, subj: ir.Value, subj_ty: (TypeBase | None) = None
    ) -> (ir.Value | None);

    def _match_seq_cond(
        pat: uni.MatchSequence, subj: ir.Value, subj_ty: (TypeBase | None) = None
    ) -> (ir.Value | None);

    def _match_tuple_seq_cond(
        pat: uni.MatchSequence, subj: ir.Value, subj_ty: (TypeBase | None) = None
    ) -> (ir.Value | None);

    def _match_map_cond(
        pat: uni.MatchMapping, subj: ir.Value, subj_ty: (TypeBase | None) = None
    ) -> (ir.Value | None);

    def _match_arch_cond(
        pat: uni.MatchArch, subj: ir.Value, subj_ty: (TypeBase | None) = None
    ) -> (ir.Value | None);

    def _match_seq_parts(pat: uni.MatchSequence) -> tuple;
    def _match_subj_ty(expr: (uni.UniNode | None)) -> (TypeBase | None);
    def _match_elem_ty_of(
        subj_ty: (TypeBase | None), prefix: str, idx: int
    ) -> (TypeBase | None);

    def _match_cast_elem(elem: ir.Value, elem_ty: (TypeBase | None)) -> ir.Value;
    def _match_map_key(kv: uni.MatchKVPair, helpers: dict) -> (ir.Value | None);
    def _match_arch_fields(pat: uni.MatchArch, arch_name: str) -> (list | None);
    def _match_value_eq(subj: ir.Value, value_node: uni.UniNode) -> (ir.Value | None);
    def _bind_match_pattern(
        pat: uni.MatchPattern, subj: ir.Value, subj_ty: (TypeBase | None) = None
    ) -> None;

    def _bind_match_capture(cap_name: str, val: ir.Value, owned: bool = False) -> None;
    def _bind_match_seq(
        pat: uni.MatchSequence, subj: ir.Value, subj_ty: (TypeBase | None) = None
    ) -> None;

    def _bind_match_map(
        pat: uni.MatchMapping, subj: ir.Value, subj_ty: (TypeBase | None) = None
    ) -> None;

    def _bind_match_arch(
        pat: uni.MatchArch, subj: ir.Value, subj_ty: (TypeBase | None) = None
    ) -> None;

    def _apply_scalar_aug_op(
        current: ir.Value,
        rhs: ir.Value,
        aug_op: str,
        rhs_node: (uni.Expr | None) = None,
        unsigned: bool = False,
        checked: bool = False
    ) -> (ir.Value | None);

    def _try_flow_for_parallel(nd: uni.InForStmt) -> bool;
    def _na_chunks_shape(expr: object) -> (tuple | None);
    def _try_chunked_for(nd: uni.InForStmt) -> bool;
    def _emit_chunk_header(
        coll: ir.Value,
        n_val: ir.Value,
        ci: ir.Value,
        hdr: ir.Value,
        len_fn: ir.Function
    ) -> None;

    def _emit_last_use_releases(stmt: uni.UniNode) -> None;
    def _emit_struct_call(name: str, nd: uni.FuncCall) -> (ir.Value | None);
    def _emit_struct_pack(
        nd: uni.FuncCall,
        params: Sequence[uni.Expr | uni.KWPair],
        fields: list,
        total: int,
        little: bool
    ) -> (ir.Value | None);

    def _emit_struct_unpack(
        nd: uni.FuncCall,
        params: Sequence[uni.Expr | uni.KWPair],
        fields: list,
        total: int,
        little: bool
    ) -> (ir.Value | None);

    def _emit_time_call(name: str, nd: uni.FuncCall) -> (ir.Value | None);
    def _emit_clock_gettime(clock_id: int) -> tuple;
    def _emit_trace_fn(arch_name: str) -> None;
    def _register_trace_pair(dtor_fn: object, trace_fn: ir.Function) -> bool;
    def _finalize_trace_lookup -> None;
    def _require_trace_fn(type_name: str, participates: bool, has_trace: bool) -> None;
    def _struct_has_ref_fields(arch_name: str) -> bool;
    def _codegen_tuple_val(nd: uni.TupleVal) -> (ir.Value | None);
    def _codegen_tuple_unpack(
        targets: Sequence[uni.UniNode],
        tuple_val: ir.Value,
        tuple_node: (uni.UniNode | None)
    ) -> bool;

    def _codegen_tuple_index(
        tuple_val: ir.Value, idx_val: ir.Value, struct_type: ir.LiteralStructType
    ) -> (ir.Value | None);

    def _tuple_struct_of_value(
        val: (ir.Value | None)
    ) -> (ir.LiteralStructType | None);

    def _tuple_iter_shape(expr: (uni.UniNode | None), val: (ir.Value | None)) -> bool;
    def _tuple_seq_flavor(elem_types: list[ir.Type]) -> tuple[str, ir.Type] | None;
    def _tuple_iter_seq(
        expr: uni.UniNode | None,
        val: ir.Value | None,
        consume_source: bool = True,
        element_type: ir.Type | None = None,
        own_elements: bool = False
    ) -> tuple[ir.Value, str, ir.Type, ir.Type | None] | None;

    def _variadic_tuple_seq_type(type_args: list) -> (ir.Type | None);
    def _tuple_seq_coerce(val: ir.Value, target_type: ir.Type) -> (ir.Value | None);
    def _get_struct_size(struct_type: ir.LiteralStructType) -> int;
    def _sizeof_llvm(ty: ir.Type) -> ir.Value;
    def _box_value_tuple(val: ir.Value, loc: str = "") -> ir.Value;
    def _rc_slot_ref(val: ir.Value) -> (ir.Value | None);
    def _tuple_managed_fields(struct_type: ir.LiteralStructType) -> list;
    def _coerce_tuple_to_struct(val: ir.Value, target_struct: ir.Type) -> ir.Value;
    def _jac_optional_type(payload: ir.Type) -> ir.Type;
    def _opt_payload_of(t: ir.Type) -> (ir.Type | None);
    def _opt_ptr_payload_of(t: ir.Type) -> (ir.Type | None);
    def _flow_narrowed_type_of(expr: (uni.UniNode | None)) -> (TypeBase | None);
    def _narrowed_flow_type(nd: uni.UniNode) -> (TypeBase | None);
    def _narrowing_blocked_by_none_test(nd: uni.UniNode) -> bool;
    def _narrowing_stable_in_loops(nd: uni.UniNode, name: str) -> bool;
    def _loop_rebinds_name(loop: uni.UniNode, name: str) -> bool;
    def _body_assigns_before(
        loop: uni.WhileStmt | uni.ForeverStmt | uni.InForStmt | uni.IterForStmt,
        child: (uni.UniNode | None),
        name: str
    ) -> bool;

    def _apply_flow_narrowing(nd: uni.UniNode, val: ir.Value) -> ir.Value;
    def _unbox_narrowed_member(nd: uni.AtomTrailer, val: ir.Value) -> ir.Value;
    def _lower_function_signature(t: SemanticFunctionType) -> ir.FunctionType;
    def _lower_function_type_raw(t: SemanticFunctionType) -> ir.PointerType;
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

    def _tuple_struct_of(elem_types: list[ir.Type]) -> ir.LiteralStructType;
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
    def _lower_class_type(t: ClassType) -> (ir.Type | None);
    def _lower_function_type(t: SemanticFunctionType) -> ir.PointerType;
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
    def _consume_bool(val: ir.Value) -> ir.Value;
    def _finish_borrowed_read(
        owner: ir.Value, value: (ir.Value | None)
    ) -> (ir.Value | None);

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
    def _opt_sole_member(t: any) -> (TypeBase | None);
    def _spec_union_agreement(t: any, names: tuple) -> (any | None);
    def _elem_storage_llvm(t: any) -> (ir.Type | None);
    def _aos_elem_of(type_expr: uni.UniNode | None) -> (str | None);
    def _infer_type_name(val: ir.Value) -> (str | None);
    def _infer_list_elem_type(val: ir.Value) -> (str | None);
    def _infer_compr_elem_struct(compr: uni.InnerCompr) -> (str | None);
    def _resolve_clib_type(type_expr: (uni.UniNode | None)) -> ir.Type;
    def _build_vtable(arch_name: str) -> None;
    def _emit_vtable_global(arch_name: str) -> None;
    def _vtable_global_for(arch_name: str) -> (ir.GlobalVariable | None);
    def _vtable_candidates(names: list[str]) -> list[ir.GlobalVariable];
    def _isinstance_needs_class_name(names: list[str]) -> bool;
    def _isinstance_unprovable_class(
        names: list[str], operand_arch: (str | None)
    ) -> (str | None);

    def _isinstance_class_name_hit(
        obj_ptr: ir.Value, names: list[str]
    ) -> (ir.Value | None);

    def _emit_class_name_const(arch_name: str) -> ir.Constant;
    def _emit_runtime_class_name_fn -> (ir.Function | None);
    def _codegen_runtime_class_name(obj_val: ir.Value) -> (ir.Value | None);
    def _codegen_class_name(nd: uni.AtomTrailer) -> (ir.Value | None);
    def _codegen_class_id(receiver: uni.UniNode) -> (ir.Value | None);
    def _class_id_of_value(arch_name: str, obj_val: ir.Value) -> ir.Value;
    def _codegen_class_ref(nd: uni.Name) -> (ir.Value | None);
    def _is_enum_arch(name: str) -> bool;
    def _emit_isa_fn -> ir.Function;
    def _emit_isa_seq_fn -> ir.Function;
    def _is_runtime_class_tuple(t: any) -> bool;
    def _runtime_class_value(expr: (uni.UniNode | None)) -> (ir.Value | None);
    def _runtime_class_arms(expr: (uni.UniNode | None)) -> tuple;
    def _isinstance_operand_arch(nd: uni.FuncCall, operand: ir.Value) -> (str | None);
    def _emit_isinstance_runtime(
        nd: uni.FuncCall, operand: ir.Value, type_arg: uni.UniNode
    ) -> (ir.Value | None);

    def _codegen_virtual_call(
        obj_val: ir.Value, method_name: str, args: list[ir.Value], obj_type_name: str
    ) -> (ir.Value | None);

    def _generate_inherited_method_wrappers -> None;
    def _emit_take(nd: uni.FuncCall) -> (ir.Value | None);
    def _emit_swap(nd: uni.FuncCall) -> (ir.Value | None);
    def _callee_ability_of(nd: uni.FuncCall) -> (uni.Ability | None);
    def _transfer_own_args(
        nd: uni.FuncCall,
        func: (ir.Function | None),
        args: list,
        release_args: list,
        offset: int = 0
    ) -> list;

    def _emit_elem_slot_drop(
        b: ir.IRBuilder,
        fn: ir.Function,
        cont: ir.Value,
        layout: dict,
        data_index: int,
        val: ir.Value
    ) -> ir.IRBuilder;

    def _slot_lowering_active -> bool;
    def _nogc_err_slot -> tuple[ir.Value, ir.Value, ir.Value];
    def _emit_finalizers(loop_depth: int = 0) -> bool;
    def _emit_err_check(callee: (uni.Ability | None)) -> None;
    def _emit_err_propagate(loc: str = "") -> None;
    def _codegen_raise_slot(payload: ir.Value, type_id: int, msg: ir.Value) -> None;
    def _codegen_try_slot(nd: uni.TryStmt) -> None;
    def _codegen_try_unwind(nd: uni.TryStmt, emit_finally: bool = True) -> None;
    def _codegen_finally_guard(nd: uni.TryStmt) -> None;
    def _push_exception_handler(
        dispatch: ir.Block, body: ir.Block
    ) -> tuple[ir.Value, ir.Value];

    def _exception_values(state: ir.Value) -> tuple[ir.Value, ir.Value, ir.Value];
    def _nogc_owned_param(p: uni.ParamVar) -> bool;
    def _emit_rc_gc_env_off_fn -> ir.Function;
    def _aos_elem_struct(type_key: str) -> (ir.Type | None);
    def _container_is_view(nd: uni.UniNode) -> bool;
    def _codegen_method_call_inner(nd: uni.FuncCall) -> (ir.Value | None);
    def _field_slot_ptr(
        obj_val: ir.Value, field_name: str, type_name: str
    ) -> ir.Value;

    def _codegen_place_ptr(
        expr: uni.Expr, allow_inline: bool = False
    ) -> (ir.Value | None);

    def _nogc_owned_world -> bool;
    def _nogc_opt_slots_owned -> bool;
    def _nogc_drop_op_active(op: str) -> bool;
    def _rc_unwrap_optional(val: ir.Value) -> ir.Value;
    def _is_move_site(expr: uni.UniNode | None) -> bool;
    def _nogc_consume_local(expr: uni.UniNode | None) -> bool;
    def _drop_hook_for(type_name: str) -> (ir.Function | None);
    def _nogc_drop_fn_for(
        ptr_ty: ir.PointerType, self_type: str = ""
    ) -> (ir.Function | None);

    def _nogc_borrow_local_assign(nd: object) -> bool;
    def _aos_elem_name(t: any) -> (str | None);
    def _decl_field_llvm_types(arch_name: str) -> (dict[str, ir.Type] | None);
    def _lower_view_container(t: any) -> (ir.Type | None);
    def _program_has_subclasses(arch_name: str) -> bool;
}
