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
import from jaclang.jac0core.diagnostics { E2018, E5026, E5060, E5090, E5091, E9002 }
import from jaclang.jac0core.osp_model { OspAnalysis, OspModel, stable_osp_tag }


# time-module function names lowered by _emit_time_call. Gated explicitly (not
# via a None return) because time.sleep legitimately produces a void result.
glob NATIVE_TIME_FUNCS: set[str] = {
         "time",
         "monotonic",
         "perf_counter",
         "time_ns",
         "monotonic_ns",
         "perf_counter_ns",
         "sleep",

     };

# os-module function names lowered by _emit_os_call. Gated explicitly because
# most are void (chdir/mkdir/rmdir/remove/unlink/rename) — None ≠ unhandled.
glob NATIVE_OS_FUNCS: set[str] = {
         "getpid",
         "getcwd",
         "getenv",
         "chdir",
         "mkdir",
         "rmdir",
         "remove",
         "unlink",
         "rename",
         "system",

     };

# random-module function names lowered by _emit_random_call. Gated explicitly
# because random.seed is void (None ≠ unhandled).
glob NATIVE_RANDOM_FUNCS: set[str] = {
         "seed",
         "random",
         "getrandbits",
         "randint",
         "randrange",
         "uniform",

     };

# struct-module function names lowered by _emit_struct_call (#6404). The format
# string is a compile-time literal, so pack/unpack/calcsize are fully resolved
# in codegen — the canonical, sv-congruent way to reinterpret bytes ↔ scalars.
glob NATIVE_STRUCT_FUNCS: set[str] = {"pack", "unpack", "calcsize", };

# ── Sentinel refcount value for static (immortal) strings.
# INT64_MAX = 0x7FFFFFFFFFFFFFFF — never reaches 0 even if accidentally decremented.
glob RC_SENTINEL: int = 0x7FFFFFFFFFFFFFFF;

# ── 32-byte allocation header layout (offsets from user_ptr) ──────────────
# malloc'd block starts at user_ptr - HDR_TOTAL. Every offset below is
# relative to user_ptr, so the values are negative for header fields.
glob HDR_ALLOC_ID_OFF: int = -32,  # i64 alloc_id (with HDR_MAGIC in upper 32 bits)
     HDR_TAG_OFF: int = -24,  # i8*  type_tag string
     HDR_RC_OFF: int = -16,  # i64  refcount    (UNCHANGED — also valid for static-string 16-byte hdr)
     HDR_DTOR_OFF: int = -8,  # i64  dtor_fn_ptr (UNCHANGED — 0 = plain free)
     HDR_TOTAL: int = 32;

# ── live-objects linked-list node layout (offsets from node start) ────────
glob LIVE_NODE_ID_OFF: int = 0,  # i64  node id (matches header alloc_id)
     LIVE_NODE_USER_OFF: int = 8,  # i8*  user pointer being tracked
     LIVE_NODE_TAG_OFF: int = 16,  # i8*  cached type_tag (mirrors header)
     LIVE_NODE_RC_OFF: int = 24,  # i64  rc_snap — last observed refcount
     LIVE_NODE_NEXT_OFF: int = 32,  # i8*  next node in the list
     LIVE_NODE_SIZE: int = 40;

# Magic value embedded in the upper 32 bits of alloc_id so retain/release
# can detect external (e.g. ctypes-passed) pointers and skip them.
glob HDR_MAGIC: int = 44061,  # 0xAC1D
     HDR_MAGIC_SHIFT_BASE: int = 44061 * 4294967296;  # HDR_MAGIC << 32

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
        _builder: (ir.IRBuilder | None) = None,
        func_symtab: dict[str, ir.Function] = {},
        local_vars: dict[str, ir.AllocaInstr] = {},
        param_vars: set[str] = set(),
        has_native_code: bool = False,
        # Test blocks lowered to native functions: (name, symbol, description,
        # line) tuples, exported as NativeTestLayout entries in the layout.
        native_tests: list = [],
        _fmt_strings: dict[str, ir.GlobalVariable] = {},
        # External function cache (Phase 0)
        extern_funcs: dict[str, ir.Function] = {},
        clib_extern_names: set[str] = set(),
        clib_struct_names: set[str] = set(),
        clib_struct_abi_types: dict[str, ir.Type] = {},
        # Foreign declaration model (Phase 8): module universe for the
        # central collector, and its memoized result. The memo is keyed on
        # the universe size (_foreign_model_nmods) because _foreign_modules
        # is assembled mid-transform, after the entry module's clib imports
        # are already processed.
        _foreign_modules: list = [],
        _foreign_structs: (dict | None) = None,
        _foreign_model_nmods: int = -1,
        _foreign_fn_decls: (dict | None) = None,
        _foreign_fns_nmods: int = -1,
        # Per-clib-function System V ABI plan (Phase 1 ABI lowering).
        # name -> {"params": [plan...], "ret": plan, "sret": bool}. This is the
        # single source of truth for how a foreign call is marshalled — it
        # replaces the old non-injective `result.type == abi_type` matching that
        # corrupted scalar returns sharing an LLVM type with a struct (gap #7).
        clib_fn_abi: dict[str, dict] = {},
        # Clib vtable structs (fn-ptr slots) and their C→Jac callback
        # trampolines, cached per (jac_fn, c_fn_type) pair (issue #6570).
        clib_vtable_structs: set[str] = set(),
        clib_trampoline_funcs: dict[str, ir.Function] = {},
        # Enum support (Phase 1)
        enum_values: dict[str, ir.Constant] = {},
        enum_types: dict[str, ir.IntType] = {},
        enum_string_values: dict[str, list] = {},
        enum_value_arrays: dict[str, object] = {},
        enum_name_arrays: dict[str, object] = {},
        enum_member_ordinal: dict[str, int] = {},
        struct_field_enum_type: dict[str, dict] = {},
        loop_stack: list[tuple] = [],
        _str_count: int = 0,
        # Object/struct support (Phase 3)
        struct_types: dict[str, object] = {},
        struct_field_indices: dict[str, dict] = {},
        struct_field_types: dict[str, dict] = {},
        struct_field_defaults: dict[str, object] = {},
        method_funcs: dict[str, ir.Function] = {},
        # Interop-marshalling return facts for free functions, recorded at
        # declaration time (while the Ability node is in hand) and consumed
        # by build_interop_layout. These replaced the name-keyed
        # AST-signature cache (method_ast_sigs); call sites read resolved
        # signatures off the checker-stamped FuncCall.callee_decl instead.
        func_ret_tuple_hints: dict[str, list] = {},
        func_ret_ann_name: dict[str, str] = {},
        # List support (Phase 4)
        list_types: dict[str, object] = {},
        list_helpers: dict[str, dict] = {},
        # For ptr-element lists holding boxed tuples, the pointer-to-struct
        # LLVM type of an element (e.g. `{i64, i64}*`). Lets `(a, b) = lst.pop()`
        # recover the tuple shape for a bare `list` whose annotation carries no
        # element type. Populated from list literals / appends (see #6435).
        var_list_elem_struct: dict[str, object] = {},
        # Transient: pointer-to-struct LLVM type of the element a list literal
        # just boxed, read by the enclosing assignment to seed
        # var_list_elem_struct. Reset at the start of each list-literal codegen.
        _pending_list_elem_struct: (object | None) = None,
        # Archetype whose method body is being codegen'd. Inherited methods are
        # re-emitted per subclass, so `self` must resolve to the *current*
        # (flattened) layout, not the declaring parent the checker reports.
        _self_arch: (str | None) = None,
        # Inheritance / vtable support (Phase 5). Hierarchy, MRO, and
        # vtable-need are NOT copied here: they are queried from the central
        # LayoutRegistry via _mro_of / _arch_has_vtable.
        parent_field_start: dict[str, dict[str, int]] = {},
        arch_ast_map: dict[str, object] = {},
        vtable_layouts: dict[str, list[str]] = {},
        vtable_method_indices: dict[str, dict] = {},
        vtable_globals: dict[str, ir.GlobalVariable] = {},
        _non_overridden_methods: dict[str, set[str]] = {},
        # Object-Spatial kernel lowering (Phase 4 / issue #6146).
        # The OSP "program facts" (archetype kinds, stable type tags, is_a
        # relation, dispatch slots, construct usage) are NOT stored here: they are
        # derived once by OspAnalysis.compute and held on the single store
        # `self.ir_in.gen.osp_model`. Only target-specific codegen artifacts live
        # on the pass.
        # osp_type_tag_field: archetype name -> struct field index holding the
        #   i64 __type_tag (fixed at 1: vtable slot is field 0).
        # osp_thunk_funcs: f"{Arch}.{ability}" -> the (JacVal,JacVal)->JacVal
        #   dispatch thunk that adapts the raw ability to a kernel Slot.fn.
        osp_type_tag_field: dict[str, int] = {},
        # osp_reports_field: walker archetype name -> struct field index of the
        #   built-in `reports` list (fixed at 2: vtable@0, __type_tag@1). The
        #   kernel's on_complete delivers `scope.reports` here so `w.reports`
        #   reads back the values reported during the walk (#6146).
        osp_reports_field: dict[str, int] = {},
        osp_thunk_funcs: dict[str, ir.Function] = {},
        # Counter for unique link-private names of imported-walker dispatch
        # thunks, so a consumer's thunk never collides with the library's
        # own `__ospthunk` symbol at link time (issue #6642 Blocker 2).
        _osp_thunk_uid: int = 0,
        # OSP archetypes IMPORTED from another native module: name ->
        #   (arch_kind, defining module name). Cross-module OSP lowering is
        #   not supported until #6146 Phases 3-4 (tag numbering and the
        #   __osp_setup tables are per-module), so spawn/connect/edge-ref on
        #   these must E5090 with help naming the import (issue #6636).
        imported_osp_archs: dict[str, tuple] = {},
        # The native-context osp_kernel module AST registered into this program
        # (None until _register_osp_kernel_module runs); NativeCompilePass links
        # its IR + glob-init.
        _osp_kernel_mod: (object | None) = None,
        # __osp_setup() globals: __ospDESC (i8* array of per-tag descriptors),
        # __ospRT (OspRuntime*), and the generated runtime function (built once
        # by _emit_osp_setup, called from the program's glob-init).
        _osp_desc_global: (object | None) = None,
        _osp_rt_global: (object | None) = None,
        _osp_setup_fn: (object | None) = None,
        # __osp_ensure_init(): lazy idempotent init (kernel glob-init + setup)
        # that spawn lowering calls, so descriptors/_walk_stack exist regardless
        # of whether the program ran through a `with entry`.
        _osp_ensure_fn: (object | None) = None,
        # __osp_kernel_inited (i8, weak): SHARED run-once guard for the OSP kernel
        # glob-init. The kernel's adjacency / walk-stack globals (_e_src, ...) are
        # link-merged singletons shared by every module, but __osp_setup +
        # __osp_inited are per-module (internal). Routing the kernel glob-init
        # through this one weak flag keeps it from re-running per module and
        # wiping a graph an earlier module built (the cross-module spawn bug).
        _osp_kernel_inited_gv: (object | None) = None,
        # The kernel glob-init Function (`__jac_glob_init_osp_kernel`), stashed by
        # _emit_osp_setup. _codegen_entry guards the program-entry call to it by
        # IDENTITY against this, not by re-matching the symbol name — so the guard
        # can never silently drift from the symbol the kernel link produces (a
        # name mismatch surfaces as a loud undefined-symbol link error instead).
        _osp_kernel_glob_init_fn: (object | None) = None,
        # __osp_filter_type(list, node_tag) -> list: filters edge-ref neighbor
        # handles by node type via the is_a callback (`[--> [?:Area]]`); built
        # once in _emit_osp_setup alongside the runtime callbacks (issue #6642).
        _osp_filter_fn: (object | None) = None,
        # __osp_h2i(stable_tag) -> i64 and __osp_is_a(t, b) -> i1: the stable-tag
        # -> local-index translation and the subtype query, emitted in
        # _emit_osp_setup and reused by the callbacks and the filter so
        # cross-module dispatch agrees on globally-stable hash tags (#6642).
        _osp_h2i_fn: (object | None) = None,
        _osp_is_a_fn: (object | None) = None,
        # Tuple support (Phase 9)
        tuple_types: dict[str, object] = {},
        # Global variable support (Phase 11)
        global_vars: dict[str, ir.GlobalVariable] = {},
        global_var_types: dict[str, ir.Type] = {},
        # Dictionary support (Phase 12)
        dict_types: dict[str, object] = {},
        dict_helpers: dict[str, dict] = {},
        # Set support (Phase 13)
        set_types: dict[str, object] = {},
        set_helpers: dict[str, dict] = {},
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
        # Binary file objects: open(path, "rb") -> BinaryFile whose read()
        # returns length-aware bytes (#6404). Same struct layout as File.
        _binary_file_struct_type: (object | None) = None,
        _binary_file_helpers_emitted: bool = False,
        # Length-aware bytes type: pointer to { i64 len, [0 x i8] data } — a
        # single rc_alloc'd block so embedded NULs survive and len() is exact
        # (#6404 Track 0). Distinct from str (i8*) so dispatch never confuses
        # the two.
        _bytes_struct_type: (object | None) = None,
        # #6749: memoized __jac_bytes_repr helper (one per module).
        _bytes_repr_function: (object | None) = None,
        # Iterator protocol (#6403): boxed JacIter + per-kind state structs.
        _jac_iter_type: (object | None) = None,
        _iter_structs_registered: bool = False,
        _iter_next_fns: dict[str, ir.Function] = {},
        _iter_uid: int = 0,
        # Primitive emitter singletons
        _native_emitters: (dict[str, object] | None) = None,
        _native_builtin_emitter: (object | None) = None,
        # Cache: primitive type name -> named methods its emitter implements
        _primitive_method_name_cache: (dict[str, set[str]] | None) = None,
        # Reference counting support (Phase RC)
        # Phase R2: compile-time gate on debug-only RC machinery (live-list,
        # ctx attribution, leak dump). Read from JAC_RC_DEBUG_CODEGEN env var
        # in postinit. When False (default), every Jac allocation skips the
        # malloc(LIVE_NODE_SIZE) live-list insert and the corresponding
        # release-time list walk — recovering the per-allocation overhead.
        _rc_debug_codegen: bool = False,
        rc_alloc_fn: (ir.Function | None) = None,
        rc_retain_fn: (ir.Function | None) = None,
        rc_release_simple_fn: (ir.Function | None) = None,
        rc_set_type_fn: (ir.Function | None) = None,
        rc_gc_disable_fn: (ir.Function | None) = None,
        rc_gc_enable_fn: (ir.Function | None) = None,
        rc_gc_disabled_gv: object = None,
        rc_debug_gv: object = None,
        rc_alloc_id_gv: object = None,
        rc_live_head_gv: object = None,
        rc_ctx_op_gv: object = None,
        rc_ctx_loc_gv: object = None,
        malloc_fn: (ir.Function | None) = None,
        free_fn: (ir.Function | None) = None,
        rc_safe_free_fn: (ir.Function | None) = None,
        struct_release_fns: dict[str, ir.Function] = {},
        list_release_fns: dict[str, ir.Function] = {},
        dict_release_fns: dict[str, ir.Function] = {},
        set_release_fns: dict[str, ir.Function] = {},
        # Lazily initialized tracking sets
        _struct_bodies_done: set[str] = set(),
        _native_stdlib_modules: set[str] = set(),
        # names of one-time stdlib runtime-helper groups already emitted (#6404)
        _stdlib_helpers_emitted: set[str] = set(),
        _global_origins: dict[str, str] = {},
        _clib_paths: list[str] = [],
        # Maps each clib function's C name to the library path it was imported
        # from (e.g. "InitWindow" -> "libraylib.dylib"). The Mach-O linker uses
        # this to emit the correct two-level-namespace dylib ordinal per symbol.
        _clib_symbol_lib: dict[str, str] = {},
        _native_emit_ctx_class: (type | None) = None,
        # TypeBase -> ir.Type lowering memo, keyed by the canonical type key
        # (TypeBase.mangle). Per LLVM module; a hit implies any collection
        # helpers for the type were already emitted.
        _lowered_type_cache: dict[str, ir.Type] = {},
        # DWARF debug metadata (populated in postinit when JAC_NATIVE_DEBUG=1)
        di_file: object = None,
        di_cu: object = None,
        _di_current_sp: object = None,
        _func_loc: dict[str, int] = {};

    has builder: ir.IRBuilder { getter; }

    def postinit -> None;
    # Main pass logic
    def transform(ir_in: uni.Module) -> uni.Module;
    def _register_enums(module: uni.Module) -> None;
    def _forward_declare_functions(module: uni.Module) -> None;
    def _maybe_declare_ability(nd: uni.ElementStmt) -> None;
    # Ability (function definition) - manual codegen
    def _codegen_ability(nd: uni.Ability) -> None;
    def _codegen_nested_ability(nd: uni.Ability) -> None;
    # Test block - lowered to a zero-arg native fn returning i8* (null = pass)
    def _codegen_test(nd: uni.Test) -> None;
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
    # Lower a sub-expression a statement requires; emit E5090 (once, deepest)
    # when it lowers to no value instead of silently dropping the statement.
    def _codegen_required(nd: (uni.UniNode | None)) -> (ir.Value | None);
    def _codegen_name(nd: uni.Name) -> (ir.Value | None);
    def _codegen_binary(nd: uni.BinaryExpr) -> (ir.Value | None);
    def _codegen_pipe_fwd(nd: uni.BinaryExpr) -> (ir.Value | None);
    def _codegen_walrus(nd: uni.BinaryExpr) -> (ir.Value | None);
    def _codegen_compare(nd: uni.CompareExpr) -> (ir.Value | None);
    def _codegen_unary(nd: uni.UnaryExpr) -> (ir.Value | None);
    def _codegen_call(nd: uni.FuncCall) -> (ir.Value | None);
    def _emit_unsupported_builtin_call(nd: uni.FuncCall, func_name: str) -> None;
    # Lambda expressions (Phase 17)
    # Maps variable name → list of (cap_name, cap_alloca) for closure injection.
    # Populated during assignment of a capturing lambda, consumed during calls.
    has lambda_captures: dict[str, list[tuple]] = {},
        _pending_lambda_captures: (list[tuple] | None) = None;
    # Pending captures from the most recently compiled lambda, to be associated
    # with a variable name during assignment. Set by _codegen_lambda, consumed
    # and cleared by _codegen_assignment.
    def _codegen_lambda(nd: uni.LambdaExpr) -> (ir.Value | None);
    # External function support (Phase 0)
    def _get_or_declare_extern(
        name: str, ret_type: ir.Type, arg_types: list[ir.Type], var_arg: bool = False
    ) -> ir.Function;
    # Print support
    def _get_printf -> ir.Function;
    def _emit_print(nd: uni.FuncCall) -> (ir.Value | None);
    def _emit_isinstance(nd: uni.FuncCall) -> (ir.Value | None);
    def _jacval_tags_for_type(name: str) -> list[int];
    def _get_fmt_string(fmt: str) -> ir.GlobalVariable;
    def _get_snprintf_fmt(fmt: str) -> ir.GlobalVariable;
    # Helper methods
    def _resolve_jac_type(type_expr: (uni.UniNode | None)) -> ir.Type;
    def _parse_callable_type_string(s: str) -> (ir.Type | None);
    def _resolve_primitive_name(expr: (uni.UniNode | None)) -> (ir.Type | None);
    def _emit_unlowerable_type(type_expr: uni.UniNode, tb: any) -> ir.Type;
    # Unified TypeBase -> LLVM lowering (consumes the central type checker's
    # result; returns None when a type category is not yet handled).
    def _lower_type(t: any) -> (ir.Type | None);
    def _lower_class_type(t: any) -> (ir.Type | None);
    def _lower_function_type(t: any) -> ir.Type;
    # Canonical type key (TypeBase.mangle) of an expression's checked type.
    def _type_key_of(expr: (uni.UniNode | None)) -> (str | None);
    # Enum class name of an expression's checked type (instance or member).
    def _enum_name_of(expr: (uni.UniNode | None)) -> (str | None);
    # Native tuple registry key derived from an expression's checked type.
    def _tuple_key_of(expr: (uni.UniNode | None)) -> (str | None);
    # Native set spec key ("i64"/"f64"/"ptr"/...) from a checked set type.
    def _set_spec_of(expr: (uni.UniNode | None)) -> (str | None);
    # Native dict registry key ("k:v" spec) from a checked dict type.
    def _dict_key_of(expr: (uni.UniNode | None)) -> (str | None);
    # Native list spec key ("i64"/"f64"/"ptr"/...) from a checked list type.
    def _list_spec_of(expr: (uni.UniNode | None)) -> (str | None);
    # Native struct name from a checked instance type (handles T | None).
    def _struct_name_of(expr: (uni.UniNode | None)) -> (str | None);
    # Lowered LLVM type of a checked list type's element.
    def _list_elem_llvm_of(expr: (uni.UniNode | None)) -> (ir.Type | None);
    # Lowered LLVM element type of a checked Iterator[T] expression (#6403).
    def _iter_elem_llvm_of(expr: (uni.UniNode | None)) -> (ir.Type | None);
    # Element spec ("i64"/"f64"/"ptr"/"jacval") of a checked list type.
    def _elem_spec_of(expr: (uni.UniNode | None)) -> (str | None);
    def _resolve_type_str(type_name: str) -> ir.Type;
    # Resolved callee signature for a call site (checker-stamped fact).
    def _callee_sig_of(nd: uni.FuncCall) -> (uni.FuncSignature | None);
    # Evaluate a call's argument expressions (drops failed lowers).
    def _codegen_call_args(nd: uni.FuncCall) -> list;
    # Take a reference for a slot about to own `value` (retain if borrowed).
    def _emit_take_ref(value: ir.Value, op: str, loc: str = "") -> None;
    # Fill omitted trailing params from the resolved callee's defaults.
    def _fill_default_args(
        nd: uni.FuncCall, func: ir.Function, args: list, skip_self: bool = False
    ) -> None;

    def _get_name(nd: (uni.UniNode | None)) -> (str | None);
    def _to_bool(val: ir.Value) -> ir.Value;
    def _entry_alloca(var_type: ir.Type, name: str) -> ir.Value;
    def _coerce_type(val: ir.Value, target_type: ir.Type) -> ir.Value;
    def _coerce_type_inner(val: ir.Value, target_type: ir.Type) -> ir.Value;
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
    def _build_enum_string_table(
        enum_name: str, entries: list, with_values: bool = True
    ) -> None;

    def _codegen_enum_value_lookup(
        enum_name: str, ordinal_val: ir.Value, use_name: bool = False
    ) -> (ir.Value | None);

    def _codegen_atom_trailer(nd: uni.AtomTrailer) -> (ir.Value | None);
    def _codegen_bool_expr(nd: uni.BoolExpr) -> (ir.Value | None);
    def _codegen_ctrl(nd: uni.CtrlStmt) -> None;
    def _codegen_for(nd: uni.InForStmt) -> None;
    # One indexed-loop skeleton for every native `for` form (range / list /
    # dict / dict-items / str); hosts the loop-var RC discipline, body-local
    # snapshot + back-edge cleanup, break/continue targets, and the owned
    # collection release.
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
        elem_cast: (ir.Type | None) = None
    ) -> None;

    def _codegen_iter_for(nd: uni.IterForStmt) -> None;
    def _codegen_match(nd: uni.MatchStmt) -> None;
    def _match_pattern_cond(
        pat: uni.MatchPattern, subj: ir.Value
    ) -> (ir.Value | None);

    def _match_value_eq(subj: ir.Value, value_node: uni.UniNode) -> (ir.Value | None);
    def _bind_match_pattern(pat: uni.MatchPattern, subj: ir.Value) -> None;
    def _codegen_if_else_expr(nd: uni.IfElseExpr) -> (ir.Value | None);
    # Phase 2: Strings and F-Strings
    def _codegen_multistring(nd: uni.MultiString) -> (ir.Value | None);
    def _codegen_string(nd: uni.String) -> (ir.Value | None);
    def _codegen_fstring(nd: uni.FString) -> (ir.Value | None);
    def _make_global_string(text: str, name_prefix: str = ".str") -> ir.Value;
    # Phase 3: Objects, Fields, Methods, None
    def _forward_declare_archetype_names(module: uni.Module) -> None;
    def _native_archetypes(module: uni.Module) -> list[uni.Archetype];
    def _register_imported_struct_types -> None;
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
    # Object-Spatial kernel lowering (Phase 4 / issue #6146)
    # Derive the single OSP-fact store (`self.ir_in.gen.osp_model`) over the
    # local + imported OSP archetypes; the backends read it, never re-deriving.
    def _compute_osp_model(archetypes: list[uni.Archetype]) -> None;
    # True when this module participates in OSP (declares an event ability or
    # uses a construct), the gate for kernel registration + descriptor setup.
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
    def _forward_declare_method(arch_name: str, method: uni.Ability) -> None;
    def _visit_nonprimary_ancestor_methods(arch: uni.Archetype, declare: bool) -> None;
    def _codegen_method(arch_name: str, method: uni.Ability) -> None;
    def _codegen_no_sig_method(arch_name: str, method: uni.Ability) -> None;
    def _forward_declare_event_method(arch_name: str, method: uni.Ability) -> None;
    def _codegen_event_method(arch_name: str, method: uni.Ability) -> None;
    # Resolve the member struct names a trigger tag denotes -- a single `Name`,
    # a `|` union, or a `(A, B)` tuple trigger -- filtered to known structs.
    def _trigger_member_structs(tag: (uni.UniNode | None)) -> list[str];
    # Member struct names an event ability fires on: checker-resolved
    # triggers (Ability.event_trigger_type_names) filtered to known
    # structs, with AST-flattening fallback.
    def _trigger_struct_names(method: uni.Ability) -> list[str];
    # Validate that every field common to all union members lives at the same
    # index and type; returns the first divergent field name, or None if the
    # members share a consistent layout (so any member's layout is usable).
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
    def _osp_visit_targets(target: uni.UniNode) -> (ir.Value | None);
    def _osp_generic_edge -> (ir.Value | None);
    def _spawn_operand_name(nd: uni.UniNode) -> (str | None);
    def _is_walker_arch(name: str) -> bool;
    def _codegen_instantiation(nd: (uni.FuncCall | uni.Name)) -> (ir.Value | None);
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

    def _dict_key_spec(key_type: ir.Type) -> tuple;
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
    # Central class-model queries (LayoutRegistry is the owner; no copies).
    def _mro_of(arch_name: str) -> list[str];
    def _arch_has_vtable(arch_name: str) -> bool;
    def _codegen_virtual_call(
        obj_val: ir.Value, method_name: str, args: list[ir.Value], obj_type_name: str
    ) -> (ir.Value | None);

    def _generate_inherited_method_wrappers -> None;
    # Phase 6: Complex Chains and Type Inference
    def _infer_type_name(val: ir.Value) -> (str | None);
    def _infer_list_elem_type(val: ir.Value) -> (str | None);
    def _infer_compr_elem_struct(compr: object) -> (str | None);
    def _infer_unpack_struct_ptr(nd: object) -> (ir.Type | None);
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
    # Native stdlib: math module (libm intercepts, issue #6404)
    def _emit_math_call(name: str, nd: uni.FuncCall) -> (ir.Value | None);
    def _emit_math_const(name: str) -> (ir.Value | None);
    # Native stdlib: time module (clock_gettime/nanosleep intercepts, #6404)
    def _emit_time_call(name: str, nd: uni.FuncCall) -> (ir.Value | None);
    def _emit_clock_gettime(clock_id: int) -> tuple;
    # Native stdlib: os / os.path modules (libc intercepts, issue #6404)
    def _emit_os_call(name: str, nd: uni.FuncCall) -> (ir.Value | None);
    def _emit_ospath_call(name: str, nd: uni.FuncCall) -> (ir.Value | None);
    # Native stdlib: random module (CPython-faithful MT19937, issue #6404)
    def _mt_ensure -> None;
    def _emit_random_call(name: str, nd: uni.FuncCall) -> (ir.Value | None);
    # Native stdlib: struct module (byte ↔ scalar reinterpret, issue #6404)
    def _emit_struct_call(name: str, nd: uni.FuncCall) -> (ir.Value | None);
    def _emit_struct_pack(
        nd: uni.FuncCall, params: list, fields: list, total: int, little: bool
    ) -> (ir.Value | None);

    def _emit_struct_unpack(
        nd: uni.FuncCall, params: list, fields: list, total: int, little: bool
    ) -> (ir.Value | None);
    # Length-aware bytes type (#6404 Track 0)
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
    # #6749: the rest of the bytes op surface, length-aware on jacbytes*.
    def _is_bytes_type(t: ir.Type) -> bool;
    def _emit_bytes_truthy(bv: ir.Value) -> ir.Value;
    def _emit_bytes_repeat(bv: ir.Value, count: ir.Value) -> ir.Value;
    def _emit_bytes_contains(needle: ir.Value, haystack: ir.Value) -> ir.Value;
    def _emit_bytes_cmp(left: ir.Value, right: ir.Value, op_sym: str) -> ir.Value;
    def _emit_bytes_repr(bv: ir.Value) -> ir.Value;
    def _bytes_repr_fn -> ir.Function;
    def _make_bytes_iter(bytes_val: ir.Value) -> ir.Value;
    def _bytes_iter_next_fn -> ir.Function;
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
    def _sizeof_llvm(ty: ir.Type) -> ir.Value;
    def _box_value_tuple(val: ir.Value, loc: str = "") -> ir.Value;
    def _coerce_tuple_to_struct(val: ir.Value, target_struct: ir.Type) -> ir.Value;
    # Phase 10: Comprehensions. One unified walker serves list/dict/set:
    # `kind` selects the element emission, `spec` is the element spec or
    # dict registry key, `val_expr` is dict-only.
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
    # Phase 13: Sets
    def _emit_set_helpers(
        elem_type_name: str, elem_type: ir.Type, elem_size: int = 0
    ) -> None;

    def _codegen_set_val(
        nd: uni.SetVal
    ) -> (ir.Value | None);  # Phase 14: Exception Handling


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
    def _get_binary_file_struct_type -> ir.Type;
    def _register_file_like_struct(name: str) -> ir.Type;
    def _emit_file_helpers -> None;
    def _emit_binary_file_helpers -> None;
    def _emit_file_like_helpers(
        struct_name: str, struct_type: ir.Type, binary: bool
    ) -> None;

    def _emit_open(nd: uni.FuncCall) -> (ir.Value | None);
    # Iterator protocol (#6403)
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
    # Container iterators for first-class iter() over dict/set/range (#6403 M1).
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
    # First-class next(it): pull one element (StopIteration at exhaustion).
    def _codegen_next(nd: uni.FuncCall) -> (ir.Value | None);
    def _make_map_iter(up: tuple, fn: ir.Function) -> (tuple | None);
    def _make_filter_iter(up: tuple, pred: ir.Function) -> (tuple | None);
    def _make_enumerate_iter(up: tuple) -> (tuple | None);
    def _make_zip_iter(up_a: tuple, up_b: tuple) -> (tuple | None);
    # User-defined __iter__/__next__ bridged into the protocol (#6403 M2).
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
    # Phase 16: Context Managers
    def _codegen_with(nd: uni.WithStmt) -> None;
    def _codegen_with_recursive(exprs: object, idx: int, body: object) -> None;
    # C library imports: import from "libname" { def ...; }
    def _process_clib_imports(module: uni.Module) -> None;
    def _resolve_clib_lib_name(components: list[str], level: int) -> str;
    def _declare_clib_ability(nd: uni.Ability) -> None;
    def _resolve_clib_type(type_expr: (uni.UniNode | None)) -> ir.Type;
    # ─── C→Jac callback trampolines for clib vtable structs (#6570) ───
    # True when a registered clib struct has a function-pointer field.
    def _clib_struct_has_fn_ptr(name: str) -> bool;
    # Record clib structs with fn-ptr slots in clib_vtable_structs.
    def _clib_detect_vtable_structs -> None;
    # Coerce a value stored into a vtable fn-ptr slot to the slot's C type
    # (Jac def → trampoline, int 0 → NULL fn ptr, passthrough otherwise).
    def _clib_coerce_callback(val: ir.Value, c_fn_ty: ir.Type) -> ir.Value;
    # Sign-correct scalar coercion at the C↔Jac trampoline boundary.
    def _clib_cb_coerce_scalar(val: ir.Value, target_type: ir.Type) -> ir.Value;
    # Emit (or fetch from cache) the C-ABI wrapper for a Jac def.
    def _emit_clib_c_trampoline(jac_fn: ir.Function, c_fn_ty: ir.Type) -> ir.Function;
    # Allocate a clib vtable struct as flat, zeroed, C-owned memory —
    # no RC header/destructor/type tag (#6571).
    def _clib_alloc_vtable(name: str) -> ir.Value;
    # ─── System V AMD64 ABI lowering for foreign structs (Phase 1) ───
    # Compute the C in-memory layout of a clib struct: (size, align, scalars)
    # where scalars is a list of (byte_offset, is_sse, bits). Nested clib
    # structs are flattened (inlined) recursively to match the C ABI.
    def _clib_struct_layout(name: str) -> tuple;
    # Memoized foreign declaration model over this pass's module universe.
    def _foreign_model -> dict;
    # Memoized foreign function declarations (name -> {"params", "ret"}).
    def _foreign_fns -> dict;
    # Ordered (field_name, nested_struct_name | None) pairs for a clib struct.
    def _foreign_fields_of(name: str) -> list;
    # Classify a clib struct for the active target's C ABI (dispatches to the
    # System V or AAPCS variant) into either MEMORY (indirect) or register
    # coerce types.
    def _classify_clib_struct(name: str) -> dict;
    # True if the clib struct has a field that is itself a clib struct.
    def _clib_has_nested(name: str) -> bool;
    # C-laid-out LLVM type for a clib struct (nested clib structs inlined).
    def _clib_c_type(name: str) -> ir.Type;
    # Produce a pointer to a C-laid-out copy of a Jac clib-struct value, ready
    # for register slicing or byval. Flat structs reuse the value directly.
    def _clib_materialize_c_ptr(jac_ptr: ir.Value, name: str) -> ir.Value;
    # Box a C-laid-out struct pointer into an RC-managed Jac struct pointer.
    def _clib_box_c_ptr(c_ptr: ir.Value, name: str) -> ir.Value;
    # Recursively copy between the Jac (pointer-nested) and C (inlined) layouts.
    def _clib_copy_jac_to_c(jac_ptr: ir.Value, c_ptr: ir.Value, name: str) -> None;
    def _clib_copy_c_to_jac(c_ptr: ir.Value, jac_ptr: ir.Value, name: str) -> None;
    # Allocate an RC-managed box for a clib struct (size from GEP-of-null).
    def _clib_alloc_box(name: str) -> ir.Value;
    # Marshal a foreign call from its stored ABI plan; returns the call result
    # already reconstructed into Jac representation (or scalar).
    def _codegen_clib_call(
        func: ir.Function, func_name: str, args: list[ir.Value]
    ) -> (ir.Value | None);
    # Layout metadata export
    def _llvm_type_str(ty: ir.Type) -> str;
    def _export_native_layout -> None;
    def _extract_tuple_struct_hints(type_node: object) -> list;
    def _extract_elem_struct_hint(type_node: object) -> (str | None);
    # Primitive emitter dispatch
    def _ensure_emitters -> None;
    def _primitive_method_names(type_name: str) -> set[str];
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
    def _emit_rc_retain(ptr: ir.Value, op: str = "", loc: str = "") -> None;
    def _emit_rc_release_simple(ptr: ir.Value, op: str = "", loc: str = "") -> None;
    def _emit_rc_release_typed(val: ir.Value, op: str = "", loc: str = "") -> None;
    def _emit_set_type_tag(b: ir.IRBuilder, ptr_i8: ir.Value, type_name: str) -> None;
    def _emit_magic_check(
        b: ir.IRBuilder, ptr: ir.Value, name_prefix: str = "mc"
    ) -> ir.Value;
    # Ownership tracking: an owned ir.Value is one whose pointee has rc=1
    # already (fresh allocation, function-call result, constructor) and the
    # caller must therefore release on drop / not retain on store.
    # Stored as `is_owned: bool` attribute on the ir.Value instance itself;
    # propagated through _coerce_type so bitcasts/inttoptr keep the marker.
    def _mark_owned(val: ir.Value) -> ir.Value;
    def _is_owned(val: ir.Value) -> bool;
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
    # GC debug helpers (gc_debug.impl.jac — R3 extracted)
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
    # DWARF debug helpers (JAC_NATIVE_DEBUG=1)
    def _attach_di_subprogram(func: ir.Function, name: str, line: int) -> None;
    def _finalize_di_locations(func: ir.Function, fallback_line: int) -> None;
    def post_transform -> None;
}
