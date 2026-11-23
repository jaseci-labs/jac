enum IntrinsicDispatch {
    RC_RUNTIME = "rc_runtime",
    FLOAT_BITS = "float_bits",
    BITS_FLOAT = "bits_float",
    MEM_LOAD = "mem_load",
    MEM_STORE = "mem_store",
    ATOMIC_XCHG = "atomic_xchg",
    C_THREAD_LOCAL = "c_thread_local",
    ATOMIC_LOAD = "atomic_load",
    ATOMIC_STORE = "atomic_store",
    ATOMIC_CAS = "atomic_cas",
    ATOMIC_RMW = "atomic_rmw",
    ATOMIC_FENCE = "atomic_fence",
    CALL_DTOR = "call_dtor",
    REGION_TLS = "region_tls",
    ALLOCA = "alloca",
    LIST_DATA = "list_data",
    BUFFER_DATA = "buffer_data",
    REF_ADDR = "ref_addr",
    STR_DATA = "str_data"
}

obj IntrinsicEntry {
    has name: str,
        param_specs: list[str],
        result_spec: str,
        dispatch: IntrinsicDispatch,
        gc_mode_gate: str | None = None;

    def arity -> int;
}

obj IntrinsicRegistry {
    has _entries: dict[str, IntrinsicEntry];

    def get(name: str) -> IntrinsicEntry | None;
    def is_intrinsic(name: str) -> bool;
    def entries -> list[IntrinsicEntry];
}

glob _INTRINSIC_WIDTHS: list[str] = ["i8", "i16", "i32", "i64"],
     _ATOMIC_RMW_OPS: list[str] = ["add", "sub", "and", "or", "xor", "swap"];

glob _INTRINSIC_ROWS: list[tuple[str, list[str], str, str, (str | None)]] = [
         ("__rc_debug_enable", [], "none", "rc_runtime", None),
         ("__rc_debug_disable", [], "none", "rc_runtime", None),
         ("__rc_gc_disable", [], "none", "rc_runtime", None),
         ("__rc_gc_enable", [], "none", "rc_runtime", None),
         ("__rc_collect_cycles", [], "none", "rc_runtime", "cycles"),
         ("__float_bits", ["f64"], "i64", "float_bits", None),
         ("__bits_float", ["i64"], "f64", "bits_float", None),
         *[
             row
             for w in _INTRINSIC_WIDTHS
             for row in [
                 (f"__mem_load_{w}", ["i64"], w, "mem_load", None),
                 (f"__mem_store_{w}", ["i64", w], "none", "mem_store", None)
             ]
         ],
         ("__bytes_data", ["ref"], "i64", "buffer_data", None),
         ("__bytearray_data", ["ref"], "i64", "buffer_data", None),
         ("__str_data", ["ref"], "i64", "str_data", None),
         ("__ref_addr", ["ref"], "i64", "ref_addr", None),
         ("__list_data_ptr", ["list"], "i64", "list_data", None),
         ("__atomic_xchg_i64", ["i64", "i64"], "i64", "atomic_xchg", None),
         *[
             row
             for w in _INTRINSIC_WIDTHS
             for row in [
                 (f"__atomic_load_{w}", ["i64", "i32"], w, "atomic_load", None),
                 (
                     f"__atomic_store_{w}",
                     ["i64", w, "i32"],
                     "none",
                     "atomic_store",
                     None
                 ),
                 (f"__atomic_cas_{w}", ["i64", w, w, "i32"], w, "atomic_cas", None),
                 *[
                     (f"__atomic_{op}_{w}", ["i64", w, "i32"], w, "atomic_rmw", None)
                     for op in _ATOMIC_RMW_OPS
                 ]
             ]
         ],
         ("__atomic_fence", ["i32"], "none", "atomic_fence", None),
         ("__thread_local_block", ["str", "i64"], "i64", "c_thread_local", None),
         ("__thread_local", ["str"], "i64", "c_thread_local", None),
         ("__c_thread_local", ["str"], "i64", "c_thread_local", None),
         ("__mem_call_dtor", ["i64", "i64"], "none", "call_dtor", None),
         ("__jac_region_tls_get", [], "i64", "region_tls", None),
         ("__jac_region_tls_set", ["i64"], "none", "region_tls", None),
         ("__jac_region_gbl_get", [], "i64", "region_tls", None),
         ("__alloca", ["i64"], "i64", "alloca", None)
     ];

glob INTRINSIC_REGISTRY = IntrinsicRegistry(
         _entries={
             name: IntrinsicEntry(
                 name=name,
                 param_specs=params,
                 result_spec=result,
                 dispatch=IntrinsicDispatch(dispatch),
                 gc_mode_gate=gate
             )
             for (name, params, result, dispatch, gate) in _INTRINSIC_ROWS
         }
     );
