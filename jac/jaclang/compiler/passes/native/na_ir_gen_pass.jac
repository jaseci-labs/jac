"""Native LLVM IR generation pass for na {} blocks.

Compiles Jac AST nodes in NATIVE context to LLVM IR using llvmlite.
All code in na {} or .na.jac is guaranteed to compile to native LLVM IR.

Derives from ModuleCodegenPass (not UniPass) because LLVM IR generation
uses manual tree-walking rather than the visitor pattern — instructions
must be emitted into specific basic blocks in order for control flow.
"""

import from llvmlite { ir }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes.module_codegen_pass { ModuleCodegenPass }
import from jaclang.jac0core.constant { CodeContext, Tokens as Tok }
import from jaclang.jac0core.diagnostics { E5060 }

"""Compile na-context Jac AST to LLVM IR using llvmlite.

Uses manual tree-walking for function bodies to properly handle
control flow basic blocks (if/else, while loops).
"""
obj NaIRGenPass(ModuleCodegenPass) {
    # LLVM module and builder (initialized in postinit)
    has llvm_module: ir.Module by postinit,
        type_map: dict[str, ir.Type] by postinit,
        complex_struct_type: object by postinit,
        range_struct_type: object by postinit,
        slice_struct_type: object by postinit,
        jacval_type: object by postinit,
        # Simple defaults
        builder: (ir.IRBuilder | None) = None,
        func_symtab: dict[str, ir.Function] = {},
        local_vars: dict[str, ir.AllocaInstr] = {},
        has_native_code: bool = False,
        _fmt_strings: dict[str, ir.GlobalVariable] = {},
        # External function cache (Phase 0)
        extern_funcs: dict[str, ir.Function] = {},
        clib_extern_names: set[str] = set(),
        clib_struct_names: set[str] = set(),
        clib_struct_abi_types: dict[str, ir.Type] = {},
        # Enum support (Phase 1)
        enum_values: dict[str, ir.Constant] = {},
        enum_types: dict[str, ir.IntType] = {},
        enum_string_values: dict[str, list] = {},
        enum_value_arrays: dict[str, object] = {},
        enum_name_arrays: dict[str, object] = {},
        var_enum_type: dict[str, str] = {},
        struct_field_enum_type: dict[str, dict] = {},
        loop_stack: list[tuple] = [],
        _str_count: int = 0,
        # Object/struct support (Phase 3)
        struct_types: dict[str, object] = {},
        struct_field_indices: dict[str, dict] = {},
        struct_field_types: dict[str, dict] = {},
        struct_field_defaults: dict[str, object] = {},
        method_funcs: dict[str, ir.Function] = {},
        method_ast_sigs: dict[str, object] = {},
        type_var_map: dict[str, str] = {},
        # List support (Phase 4)
        list_types: dict[str, object] = {},
        list_helpers: dict[str, dict] = {},
        var_list_elem_type: dict[str, str] = {},
        field_type_node: dict[str, dict] = {},
        var_type_node: dict[str, object] = {},
        _list_type_hint: (str | None) = None,
        _last_type_node_hint: (object | None) = None,
        # Inheritance / vtable support (Phase 5)
        class_hierarchy: dict[str, str] = {},
        class_parents: dict[str, list[str]] = {},
        mro_order: dict[str, list[str]] = {},
        parent_field_start: dict[str, dict[str, int]] = {},
        arch_ast_map: dict[str, object] = {},
        has_vtable: dict[str, bool] = {},
        vtable_layouts: dict[str, list[str]] = {},
        vtable_method_indices: dict[str, dict] = {},
        vtable_globals: dict[str, ir.GlobalVariable] = {},
        _non_overridden_methods: dict[str, set[str]] = {},
        # Tuple support (Phase 9)
        tuple_types: dict[str, object] = {},
        var_tuple_type: dict[str, str] = {},
        # Complex/Range/Slice var tracking
        var_complex: set[str] = set(),
        var_range: set[str] = set(),
        var_slice: set[str] = set(),
        # Global variable support (Phase 11)
        global_vars: dict[str, ir.GlobalVariable] = {},
        global_var_types: dict[str, ir.Type] = {},
        # Dictionary support (Phase 12)
        dict_types: dict[str, object] = {},
        dict_helpers: dict[str, dict] = {},
        var_dict_type: dict[str, str] = {},
        _dict_val_type_hint: (str | None) = None,
        # Set support (Phase 13)
        set_types: dict[str, object] = {},
        set_helpers: dict[str, dict] = {},
        var_set_elem_type: dict[str, str] = {},
        # Exception handling support (Phase 14)
        _exc_state_type: (object | None) = None,
        _exc_handler_global: (object | None) = None,
        _exc_push_fn: (object | None) = None,
        _exc_pop_fn: (object | None) = None,
        _exc_raise_fn: (object | None) = None,
        _exc_type_registry: dict[str, int] = {"Exception": 0},
        _exc_type_counter: int = 1,
        _rt_error_msgs: dict[str, object] = {},
        # File I/O support (Phase 15)
        _file_struct_type: (object | None) = None,
        _file_helpers_emitted: bool = False,
        # Primitive emitter singletons
        _native_emitters: (dict[str, object] | None) = None,
        _native_builtin_emitter: (object | None) = None,
        # Reference counting support (Phase RC)
        rc_alloc_fn: (ir.Function | None) = None,
        rc_retain_fn: (ir.Function | None) = None,
        rc_release_simple_fn: (ir.Function | None) = None,
        malloc_fn: (ir.Function | None) = None,
        free_fn: (ir.Function | None) = None,
        struct_release_fns: dict[str, ir.Function] = {},
        list_release_fns: dict[str, ir.Function] = {},
        dict_release_fns: dict[str, ir.Function] = {},
        set_release_fns: dict[str, ir.Function] = {},
        # Lazily initialized tracking sets
        _imported_na_paths: list[str] = [],
        _struct_bodies_done: set[str] = set(),
        _native_stdlib_modules: set[str] = set(),
        _clib_paths: list[str] = [],
        _native_emit_ctx_class: (type | None) = None;

    def postinit -> None;
    # Main pass logic
    def transform(ir_in: uni.Module) -> uni.Module;
    def _register_enums(module: uni.Module) -> None;
    def _forward_declare_functions(module: uni.Module) -> None;
    def _maybe_declare_ability(nd: uni.ElementStmt) -> None;
    # Ability (function definition) - manual codegen
    def _codegen_ability(nd: uni.Ability) -> None;
    # Body / statement codegen
    def _codegen_body(stmts: (list | tuple)) -> None;
    def _codegen_stmt(nd: uni.UniNode) -> None;
    def _codegen_return(nd: uni.ReturnStmt) -> None;
    def _codegen_if(nd: uni.IfStmt) -> None;
    def _codegen_switch(nd: uni.SwitchStmt) -> None;
    def _codegen_while(nd: uni.WhileStmt) -> None;
    def _codegen_assignment(nd: uni.Assignment) -> None;
    # Expression codegen
    def _codegen_expr(nd: (uni.UniNode | None)) -> (ir.Value | None);
    def _codegen_name(nd: uni.Name) -> (ir.Value | None);
    def _codegen_binary(nd: uni.BinaryExpr) -> (ir.Value | None);
    def _codegen_compare(nd: uni.CompareExpr) -> (ir.Value | None);
    def _codegen_unary(nd: uni.UnaryExpr) -> (ir.Value | None);
    def _codegen_call(nd: uni.FuncCall) -> (ir.Value | None);
    # Lambda expressions (Phase 17)
    # Maps variable name → list of (cap_name, cap_alloca) for closure injection.
    # Populated during assignment of a capturing lambda, consumed during calls.
    has lambda_captures: dict[str, list[tuple]] = {},
        _pending_lambda_captures: (list[tuple] | None) = None;
    # Pending captures from the most recently compiled lambda, to be associated
    # with a variable name during assignment. Set by _codegen_lambda, consumed
    # and cleared by _codegen_assignment.
    def _codegen_lambda(nd: uni.LambdaExpr) -> (ir.Value | None);
    def _find_free_vars(body: object, param_names: list[str]) -> list[str];
    # External function support (Phase 0)
    def _get_or_declare_extern(
        name: str, ret_type: ir.Type, arg_types: list[ir.Type], var_arg: bool = False
    ) -> ir.Function;
    # Print support
    def _get_printf -> ir.Function;
    def _emit_print(nd: uni.FuncCall) -> (ir.Value | None);
    def _get_fmt_string(fmt: str) -> ir.GlobalVariable;
    def _get_snprintf_fmt(fmt: str) -> ir.GlobalVariable;
    # Helper methods
    def _resolve_jac_type(type_expr: (uni.UniNode | None)) -> ir.Type;
    def _llvm_to_spec(t: Any) -> str;
    def _resolve_callable_type(slice: uni.IndexSlice) -> ir.Type;
    def _resolve_func_ptr_type(sig: uni.FuncSignature) -> ir.Type;
    def _resolve_type_str(type_name: str) -> ir.Type;
    def _get_name(nd: (uni.UniNode | None)) -> (str | None);
    def _to_bool(val: ir.Value) -> ir.Value;
    def _entry_alloca(var_type: ir.Type, name: str) -> ir.Value;
    def _coerce_type(val: ir.Value, target_type: ir.Type) -> ir.Value;
    def _promote_to_float(
        left: ir.Value, right: ir.Value
    ) -> tuple[(ir.Value, ir.Value)];

    def _emit_binary_op(op: str, left: ir.Value, right: ir.Value) -> (ir.Value | None);
    def _emit_comparison(
        op: str, left: ir.Value, right: ir.Value, is_float: bool
    ) -> (ir.Value | None);

    def _codegen_int_pow(base: ir.Value, exp: ir.Value) -> ir.Value;
    # Phase 1: Enums, BoolExpr, Break/Continue, For, Ternary
    def _codegen_enum(nd: uni.Enum) -> None;
    def _build_enum_string_table(enum_name: str, entries: list) -> None;
    def _codegen_enum_value_lookup(
        enum_name: str, ordinal_val: ir.Value, use_name: bool = False
    ) -> (ir.Value | None);

    def _codegen_atom_trailer(nd: uni.AtomTrailer) -> (ir.Value | None);
    def _codegen_bool_expr(nd: uni.BoolExpr) -> (ir.Value | None);
    def _codegen_ctrl(nd: uni.CtrlStmt) -> None;
    def _codegen_for(nd: uni.InForStmt) -> None;
    def _codegen_if_else_expr(nd: uni.IfElseExpr) -> (ir.Value | None);
    # Phase 2: Strings and F-Strings
    def _codegen_multistring(nd: uni.MultiString) -> (ir.Value | None);
    def _codegen_string(nd: uni.String) -> (ir.Value | None);
    def _codegen_fstring(nd: uni.FString) -> (ir.Value | None);
    def _make_global_string(text: str, name_prefix: str = ".str") -> ir.Value;
    # Phase 3: Objects, Fields, Methods, None
    def _forward_declare_archetype_names(module: uni.Module) -> None;
    def _register_imported_struct_types -> None;
    def _walk_imported_module(imported_mod: uni.Module) -> None;
    def _walk_imported_module_types(imported_mod: uni.Module) -> None;
    def _walk_imported_module_type_names(imported_mod: uni.Module) -> None;
    def _walk_imported_module_abilities(imported_mod: uni.Module) -> None;
    def _register_imported_archetype(arch: uni.Archetype) -> None;
    def _forward_declare_archetype_methods(arch: uni.Archetype) -> None;
    def _register_imported_globals(nd: uni.GlobalVars) -> None;
    def _forward_declare_imported_ability(nd: uni.Ability) -> None;
    def _register_archetypes(module: uni.Module) -> None;
    def _codegen_archetype(nd: uni.Archetype) -> None;
    def _forward_declare_method(arch_name: str, method: uni.Ability) -> None;
    def _codegen_method(arch_name: str, method: uni.Ability) -> None;
    def _codegen_no_sig_method(arch_name: str, method: uni.Ability) -> None;
    def _codegen_instantiation(nd: uni.FuncCall) -> (ir.Value | None);
    def _codegen_method_call(nd: uni.FuncCall) -> (ir.Value | None);
    def _codegen_field_access(
        obj_val: ir.Value, field_name: str, type_name: str
    ) -> (ir.Value | None);

    def _codegen_field_aug_assign(
        target: uni.AtomTrailer, rhs: ir.Value, aug_op: str
    ) -> (ir.Value | None);

    def _codegen_field_assign(target: uni.AtomTrailer, value: ir.Value) -> None;
    # Shared container helpers (used by lists, dicts, sets)
    def _emit_key_comparison(
        b: ir.IRBuilder,
        key_type: ir.Type,
        stored_val: ir.Value,
        search_val: ir.Value,
        key_size: int = 0
    ) -> ir.Value;

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
        fn_name: str, container_ptr_type: ir.Type, data_types: list
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
    # Phase 4: Lists
    def _emit_list_helpers(elem_type_name: str, elem_type: ir.Type) -> None;
    def _codegen_list_val(nd: uni.ListVal) -> (ir.Value | None);
    def _codegen_index(
        target_val: ir.Value, index_val: ir.Value, elem_type_name: str
    ) -> (ir.Value | None);

    def _codegen_index_set(
        target_val: ir.Value, index_val: ir.Value, value: ir.Value, elem_type_name: str
    ) -> None;
    # Phase 5: Inheritance, Vtables, and C3 MRO
    def _build_vtable(arch_name: str) -> None;
    def _emit_vtable_global(arch_name: str) -> None;
    def _codegen_virtual_call(
        obj_val: ir.Value, method_name: str, args: list[ir.Value], obj_type_name: str
    ) -> (ir.Value | None);

    def _generate_inherited_method_wrappers -> None;
    # Phase 6: Complex Chains and Type Inference
    def _infer_type_name(val: ir.Value) -> (str | None);
    def _infer_list_elem_type(val: ir.Value) -> (str | None);
    def _peel_list_type(type_node: (object | None)) -> tuple;
    def _get_list_elem_from_type_node(type_node: (object | None)) -> (str | None);
    def _infer_compr_elem_struct(compr: object) -> (str | None);
    def _resolve_for_loop_elem_type(
        coll_name: (str | None), coll_node: (object | None)
    ) -> (ir.Type | None);

    def _resolve_ptr_elem_cast_type(type_node: (object | None)) -> (ir.Type | None);
    # Phase 7: String Methods and Builtins
    def _codegen_string_index(
        target_val: ir.Value, index_val: ir.Value
    ) -> (ir.Value | None);

    def _codegen_str_strip(str_val: ir.Value) -> (ir.Value | None);
    def _codegen_str_split(str_val: ir.Value, sep_val: ir.Value) -> (ir.Value | None);
    def _codegen_list_slice(
        target_val: ir.Value, slice_node: object, elem_type_name: str
    ) -> (ir.Value | None);

    def _codegen_string_slice(
        target_val: ir.Value, slice_node: object
    ) -> (ir.Value | None);
    # Native stdlib: sys module
    def _emit_sys_argv -> (ir.Value | None);
    def _emit_sys_exit(args: list[ir.Value]) -> (ir.Value | None);
    # Phase 8: Entry Block
    def _codegen_entry(nd: uni.ModuleCode) -> None;
    # Phase 9: Tuples
    def _codegen_tuple_val(nd: uni.TupleVal) -> (ir.Value | None);
    def _codegen_tuple_unpack(
        targets: list, tuple_val: ir.Value, tuple_node: (object | None)
    ) -> None;

    def _codegen_tuple_index(
        tuple_val: ir.Value, idx_val: ir.Value, struct_type: ir.LiteralStructType
    ) -> (ir.Value | None);

    def _get_struct_size(struct_type: ir.LiteralStructType) -> int;
    def _box_value_tuple(val: ir.Value) -> ir.Value;
    # Phase 10: Comprehensions
    def _codegen_list_compr(nd: uni.ListCompr) -> (ir.Value | None);
    def _codegen_compr_loops(
        comprs: list,
        idx: int,
        list_val: ir.Value,
        out_expr: uni.UniNode,
        elem_type_name: str
    ) -> None;

    def _codegen_compr_range_loop(
        inner: uni.InnerCompr,
        comprs: list,
        idx: int,
        list_val: ir.Value,
        out_expr: uni.UniNode,
        elem_type_name: str,
        conditionals: list
    ) -> None;

    def _codegen_dict_compr(nd: uni.DictCompr) -> (ir.Value | None);
    def _codegen_dict_compr_loops(
        comprs: list,
        idx: int,
        dict_val: ir.Value,
        key_expr: uni.UniNode,
        val_expr: uni.UniNode,
        dict_key: str
    ) -> None;

    def _codegen_dict_compr_range_loop(
        inner: uni.InnerCompr,
        comprs: list,
        idx: int,
        dict_val: ir.Value,
        key_expr: uni.UniNode,
        val_expr: uni.UniNode,
        dict_key: str,
        conditionals: list
    ) -> None;

    def _codegen_set_compr(nd: uni.SetCompr) -> (ir.Value | None);
    def _codegen_set_compr_loops(
        comprs: list,
        idx: int,
        set_val: ir.Value,
        out_expr: uni.UniNode,
        elem_type_name: str
    ) -> None;

    def _codegen_set_compr_range_loop(
        inner: uni.InnerCompr,
        comprs: list,
        idx: int,
        set_val: ir.Value,
        out_expr: uni.UniNode,
        elem_type_name: str,
        conditionals: list
    ) -> None;
    # Phase 11: Global Variables
    def _register_globals(module: uni.Module) -> None;
    def _codegen_global_vars(nd: uni.GlobalVars) -> None;
    def _infer_global_init_type(value_node: uni.UniNode) -> (ir.Type | None);
    def _codegen_const_expr(
        nd: uni.UniNode, target_type: ir.Type
    ) -> (ir.Constant | None);
    # Phase 12: Dictionaries
    def _emit_dict_helpers(
        key_type_name: str,
        val_type_name: str,
        key_type: ir.Type,
        val_type: ir.Type,
        key_size: int = 0
    ) -> None;

    def _box_to_jacval(value: ir.Value) -> ir.Value;
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
    # Phase 13: Sets
    def _emit_set_helpers(
        elem_type_name: str, elem_type: ir.Type, elem_size: int = 0
    ) -> None;

    def _codegen_set_val(nd: uni.SetVal) -> (ir.Value | None);
    def _codegen_set_contains(
        set_val: ir.Value, elem_val: ir.Value, elem_type_name: str
    ) -> (ir.Value | None);

    def _codegen_set_add(
        set_val: ir.Value, elem_val: ir.Value, elem_type_name: str
    ) -> None;
    # Phase 14: Exception Handling
    def _get_exception_state_type -> ir.Type;
    def _declare_exception_runtime -> None;
    def _emit_exc_push_helper -> None;
    def _emit_exc_pop_helper -> None;
    def _emit_exc_raise_helper -> None;
    def _emit_runtime_raise(is_error: ir.Value, exc_type_name: str, msg: str) -> None;
    def _get_or_register_exc_type(exc_name: str) -> int;
    def _get_exc_descendants(type_name: str) -> list[str];
    def _codegen_raise(nd: uni.RaiseStmt) -> None;
    def _codegen_try(nd: uni.TryStmt) -> None;
    # Phase 15: File I/O
    def _get_file_struct_type -> ir.Type;
    def _emit_file_helpers -> None;
    def _emit_open(nd: uni.FuncCall) -> (ir.Value | None);
    # Phase 16: Context Managers
    def _codegen_with(nd: uni.WithStmt) -> None;
    def _codegen_with_recursive(exprs: object, idx: int, body: object) -> None;
    # C library imports: import from "libname" { def ...; }
    def _process_clib_imports(module: uni.Module) -> None;
    def _declare_clib_ability(nd: uni.Ability) -> None;
    def _resolve_clib_type(type_expr: (uni.UniNode | None)) -> ir.Type;
    # Layout metadata export
    def _llvm_type_str(ty: ir.Type) -> str;
    def _export_native_layout -> None;
    def _extract_tuple_struct_hints(type_node: object) -> list;
    def _extract_elem_struct_hint(type_node: object) -> (str | None);
    # Primitive emitter dispatch
    def _ensure_emitters -> None;
    def _dispatch_primitive_method(
        type_name: str,
        method_name: str,
        target: ir.Value,
        args: list[ir.Value],
        type_key: str
    ) -> (ir.Value | None);

    def _dispatch_builtin(func_name: str, args: list[ir.Value]) -> (ir.Value | None);
    # Reference counting (Phase RC)
    def _emit_rc_helpers -> None;
    def _rc_alloc(size: ir.Value, name: str = "rc.alloc") -> ir.Value;
    def _rc_alloc_typed(
        size: ir.Value, target_type: ir.Type, name: str = "rc.ptr"
    ) -> ir.Value;

    def _emit_rc_retain(ptr: ir.Value) -> None;
    def _emit_rc_release_simple(ptr: ir.Value) -> None;
    def _emit_rc_release_typed(val: ir.Value) -> None;
    def _emit_scope_cleanup(skip_var: (str | None) = None) -> None;
    def _rc_strdup(ptr: ir.Value, name: str = "rc.str") -> ir.Value;
    def _emit_struct_release_fn(arch_name: str) -> None;
    def _emit_glob_init_func -> None;
    def post_transform -> None;
}
