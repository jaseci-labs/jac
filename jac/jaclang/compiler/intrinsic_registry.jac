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
    def names -> list[str];
    def entries -> list[IntrinsicEntry];
}

glob INTRINSIC_REGISTRY = IntrinsicRegistry(
         _entries={
             "__rc_debug_enable": IntrinsicEntry(
                 name="__rc_debug_enable",
                 param_specs=[],
                 result_spec="none",
                 dispatch=IntrinsicDispatch.RC_RUNTIME
             ),
             "__rc_debug_disable": IntrinsicEntry(
                 name="__rc_debug_disable",
                 param_specs=[],
                 result_spec="none",
                 dispatch=IntrinsicDispatch.RC_RUNTIME
             ),
             "__rc_gc_disable": IntrinsicEntry(
                 name="__rc_gc_disable",
                 param_specs=[],
                 result_spec="none",
                 dispatch=IntrinsicDispatch.RC_RUNTIME
             ),
             "__rc_gc_enable": IntrinsicEntry(
                 name="__rc_gc_enable",
                 param_specs=[],
                 result_spec="none",
                 dispatch=IntrinsicDispatch.RC_RUNTIME
             ),
             "__rc_collect_cycles": IntrinsicEntry(
                 name="__rc_collect_cycles",
                 param_specs=[],
                 result_spec="none",
                 dispatch=IntrinsicDispatch.RC_RUNTIME,
                 gc_mode_gate="cycles"
             ),
             "__float_bits": IntrinsicEntry(
                 name="__float_bits",
                 param_specs=["f64"],
                 result_spec="i64",
                 dispatch=IntrinsicDispatch.FLOAT_BITS
             ),
             "__bits_float": IntrinsicEntry(
                 name="__bits_float",
                 param_specs=["i64"],
                 result_spec="f64",
                 dispatch=IntrinsicDispatch.BITS_FLOAT
             ),
             "__mem_load_i8": IntrinsicEntry(
                 name="__mem_load_i8",
                 param_specs=["i64"],
                 result_spec="i8",
                 dispatch=IntrinsicDispatch.MEM_LOAD
             ),
             "__mem_store_i8": IntrinsicEntry(
                 name="__mem_store_i8",
                 param_specs=["i64", "i8"],
                 result_spec="none",
                 dispatch=IntrinsicDispatch.MEM_STORE
             ),
             "__mem_load_i16": IntrinsicEntry(
                 name="__mem_load_i16",
                 param_specs=["i64"],
                 result_spec="i16",
                 dispatch=IntrinsicDispatch.MEM_LOAD
             ),
             "__mem_store_i16": IntrinsicEntry(
                 name="__mem_store_i16",
                 param_specs=["i64", "i16"],
                 result_spec="none",
                 dispatch=IntrinsicDispatch.MEM_STORE
             ),
             "__mem_load_i32": IntrinsicEntry(
                 name="__mem_load_i32",
                 param_specs=["i64"],
                 result_spec="i32",
                 dispatch=IntrinsicDispatch.MEM_LOAD
             ),
             "__mem_store_i32": IntrinsicEntry(
                 name="__mem_store_i32",
                 param_specs=["i64", "i32"],
                 result_spec="none",
                 dispatch=IntrinsicDispatch.MEM_STORE
             ),
             "__mem_load_i64": IntrinsicEntry(
                 name="__mem_load_i64",
                 param_specs=["i64"],
                 result_spec="i64",
                 dispatch=IntrinsicDispatch.MEM_LOAD
             ),
             "__mem_store_i64": IntrinsicEntry(
                 name="__mem_store_i64",
                 param_specs=["i64", "i64"],
                 result_spec="none",
                 dispatch=IntrinsicDispatch.MEM_STORE
             ),
             "__bytes_data": IntrinsicEntry(
                 name="__bytes_data",
                 param_specs=["ref"],
                 result_spec="i64",
                 dispatch=IntrinsicDispatch.BUFFER_DATA
             ),
             "__bytearray_data": IntrinsicEntry(
                 name="__bytearray_data",
                 param_specs=["ref"],
                 result_spec="i64",
                 dispatch=IntrinsicDispatch.BUFFER_DATA
             ),
             "__str_data": IntrinsicEntry(
                 name="__str_data",
                 param_specs=["ref"],
                 result_spec="i64",
                 dispatch=IntrinsicDispatch.STR_DATA
             ),
             "__ref_addr": IntrinsicEntry(
                 name="__ref_addr",
                 param_specs=["ref"],
                 result_spec="i64",
                 dispatch=IntrinsicDispatch.REF_ADDR
             ),
             "__list_data_ptr": IntrinsicEntry(
                 name="__list_data_ptr",
                 param_specs=["list"],
                 result_spec="i64",
                 dispatch=IntrinsicDispatch.LIST_DATA
             ),
             "__atomic_xchg_i64": IntrinsicEntry(
                 name="__atomic_xchg_i64",
                 param_specs=["i64", "i64"],
                 result_spec="i64",
                 dispatch=IntrinsicDispatch.ATOMIC_XCHG
             ),
             "__atomic_load_i8": IntrinsicEntry(
                 name="__atomic_load_i8",
                 param_specs=["i64", "i32"],
                 result_spec="i8",
                 dispatch=IntrinsicDispatch.ATOMIC_LOAD
             ),
             "__atomic_store_i8": IntrinsicEntry(
                 name="__atomic_store_i8",
                 param_specs=["i64", "i8", "i32"],
                 result_spec="none",
                 dispatch=IntrinsicDispatch.ATOMIC_STORE
             ),
             "__atomic_cas_i8": IntrinsicEntry(
                 name="__atomic_cas_i8",
                 param_specs=["i64", "i8", "i8", "i32"],
                 result_spec="i8",
                 dispatch=IntrinsicDispatch.ATOMIC_CAS
             ),
             "__atomic_add_i8": IntrinsicEntry(
                 name="__atomic_add_i8",
                 param_specs=["i64", "i8", "i32"],
                 result_spec="i8",
                 dispatch=IntrinsicDispatch.ATOMIC_RMW
             ),
             "__atomic_sub_i8": IntrinsicEntry(
                 name="__atomic_sub_i8",
                 param_specs=["i64", "i8", "i32"],
                 result_spec="i8",
                 dispatch=IntrinsicDispatch.ATOMIC_RMW
             ),
             "__atomic_and_i8": IntrinsicEntry(
                 name="__atomic_and_i8",
                 param_specs=["i64", "i8", "i32"],
                 result_spec="i8",
                 dispatch=IntrinsicDispatch.ATOMIC_RMW
             ),
             "__atomic_or_i8": IntrinsicEntry(
                 name="__atomic_or_i8",
                 param_specs=["i64", "i8", "i32"],
                 result_spec="i8",
                 dispatch=IntrinsicDispatch.ATOMIC_RMW
             ),
             "__atomic_xor_i8": IntrinsicEntry(
                 name="__atomic_xor_i8",
                 param_specs=["i64", "i8", "i32"],
                 result_spec="i8",
                 dispatch=IntrinsicDispatch.ATOMIC_RMW
             ),
             "__atomic_swap_i8": IntrinsicEntry(
                 name="__atomic_swap_i8",
                 param_specs=["i64", "i8", "i32"],
                 result_spec="i8",
                 dispatch=IntrinsicDispatch.ATOMIC_RMW
             ),
             "__atomic_load_i16": IntrinsicEntry(
                 name="__atomic_load_i16",
                 param_specs=["i64", "i32"],
                 result_spec="i16",
                 dispatch=IntrinsicDispatch.ATOMIC_LOAD
             ),
             "__atomic_store_i16": IntrinsicEntry(
                 name="__atomic_store_i16",
                 param_specs=["i64", "i16", "i32"],
                 result_spec="none",
                 dispatch=IntrinsicDispatch.ATOMIC_STORE
             ),
             "__atomic_cas_i16": IntrinsicEntry(
                 name="__atomic_cas_i16",
                 param_specs=["i64", "i16", "i16", "i32"],
                 result_spec="i16",
                 dispatch=IntrinsicDispatch.ATOMIC_CAS
             ),
             "__atomic_add_i16": IntrinsicEntry(
                 name="__atomic_add_i16",
                 param_specs=["i64", "i16", "i32"],
                 result_spec="i16",
                 dispatch=IntrinsicDispatch.ATOMIC_RMW
             ),
             "__atomic_sub_i16": IntrinsicEntry(
                 name="__atomic_sub_i16",
                 param_specs=["i64", "i16", "i32"],
                 result_spec="i16",
                 dispatch=IntrinsicDispatch.ATOMIC_RMW
             ),
             "__atomic_and_i16": IntrinsicEntry(
                 name="__atomic_and_i16",
                 param_specs=["i64", "i16", "i32"],
                 result_spec="i16",
                 dispatch=IntrinsicDispatch.ATOMIC_RMW
             ),
             "__atomic_or_i16": IntrinsicEntry(
                 name="__atomic_or_i16",
                 param_specs=["i64", "i16", "i32"],
                 result_spec="i16",
                 dispatch=IntrinsicDispatch.ATOMIC_RMW
             ),
             "__atomic_xor_i16": IntrinsicEntry(
                 name="__atomic_xor_i16",
                 param_specs=["i64", "i16", "i32"],
                 result_spec="i16",
                 dispatch=IntrinsicDispatch.ATOMIC_RMW
             ),
             "__atomic_swap_i16": IntrinsicEntry(
                 name="__atomic_swap_i16",
                 param_specs=["i64", "i16", "i32"],
                 result_spec="i16",
                 dispatch=IntrinsicDispatch.ATOMIC_RMW
             ),
             "__atomic_load_i32": IntrinsicEntry(
                 name="__atomic_load_i32",
                 param_specs=["i64", "i32"],
                 result_spec="i32",
                 dispatch=IntrinsicDispatch.ATOMIC_LOAD
             ),
             "__atomic_store_i32": IntrinsicEntry(
                 name="__atomic_store_i32",
                 param_specs=["i64", "i32", "i32"],
                 result_spec="none",
                 dispatch=IntrinsicDispatch.ATOMIC_STORE
             ),
             "__atomic_cas_i32": IntrinsicEntry(
                 name="__atomic_cas_i32",
                 param_specs=["i64", "i32", "i32", "i32"],
                 result_spec="i32",
                 dispatch=IntrinsicDispatch.ATOMIC_CAS
             ),
             "__atomic_add_i32": IntrinsicEntry(
                 name="__atomic_add_i32",
                 param_specs=["i64", "i32", "i32"],
                 result_spec="i32",
                 dispatch=IntrinsicDispatch.ATOMIC_RMW
             ),
             "__atomic_sub_i32": IntrinsicEntry(
                 name="__atomic_sub_i32",
                 param_specs=["i64", "i32", "i32"],
                 result_spec="i32",
                 dispatch=IntrinsicDispatch.ATOMIC_RMW
             ),
             "__atomic_and_i32": IntrinsicEntry(
                 name="__atomic_and_i32",
                 param_specs=["i64", "i32", "i32"],
                 result_spec="i32",
                 dispatch=IntrinsicDispatch.ATOMIC_RMW
             ),
             "__atomic_or_i32": IntrinsicEntry(
                 name="__atomic_or_i32",
                 param_specs=["i64", "i32", "i32"],
                 result_spec="i32",
                 dispatch=IntrinsicDispatch.ATOMIC_RMW
             ),
             "__atomic_xor_i32": IntrinsicEntry(
                 name="__atomic_xor_i32",
                 param_specs=["i64", "i32", "i32"],
                 result_spec="i32",
                 dispatch=IntrinsicDispatch.ATOMIC_RMW
             ),
             "__atomic_swap_i32": IntrinsicEntry(
                 name="__atomic_swap_i32",
                 param_specs=["i64", "i32", "i32"],
                 result_spec="i32",
                 dispatch=IntrinsicDispatch.ATOMIC_RMW
             ),
             "__atomic_load_i64": IntrinsicEntry(
                 name="__atomic_load_i64",
                 param_specs=["i64", "i32"],
                 result_spec="i64",
                 dispatch=IntrinsicDispatch.ATOMIC_LOAD
             ),
             "__atomic_store_i64": IntrinsicEntry(
                 name="__atomic_store_i64",
                 param_specs=["i64", "i64", "i32"],
                 result_spec="none",
                 dispatch=IntrinsicDispatch.ATOMIC_STORE
             ),
             "__atomic_cas_i64": IntrinsicEntry(
                 name="__atomic_cas_i64",
                 param_specs=["i64", "i64", "i64", "i32"],
                 result_spec="i64",
                 dispatch=IntrinsicDispatch.ATOMIC_CAS
             ),
             "__atomic_add_i64": IntrinsicEntry(
                 name="__atomic_add_i64",
                 param_specs=["i64", "i64", "i32"],
                 result_spec="i64",
                 dispatch=IntrinsicDispatch.ATOMIC_RMW
             ),
             "__atomic_sub_i64": IntrinsicEntry(
                 name="__atomic_sub_i64",
                 param_specs=["i64", "i64", "i32"],
                 result_spec="i64",
                 dispatch=IntrinsicDispatch.ATOMIC_RMW
             ),
             "__atomic_and_i64": IntrinsicEntry(
                 name="__atomic_and_i64",
                 param_specs=["i64", "i64", "i32"],
                 result_spec="i64",
                 dispatch=IntrinsicDispatch.ATOMIC_RMW
             ),
             "__atomic_or_i64": IntrinsicEntry(
                 name="__atomic_or_i64",
                 param_specs=["i64", "i64", "i32"],
                 result_spec="i64",
                 dispatch=IntrinsicDispatch.ATOMIC_RMW
             ),
             "__atomic_xor_i64": IntrinsicEntry(
                 name="__atomic_xor_i64",
                 param_specs=["i64", "i64", "i32"],
                 result_spec="i64",
                 dispatch=IntrinsicDispatch.ATOMIC_RMW
             ),
             "__atomic_swap_i64": IntrinsicEntry(
                 name="__atomic_swap_i64",
                 param_specs=["i64", "i64", "i32"],
                 result_spec="i64",
                 dispatch=IntrinsicDispatch.ATOMIC_RMW
             ),
             "__atomic_fence": IntrinsicEntry(
                 name="__atomic_fence",
                 param_specs=["i32"],
                 result_spec="none",
                 dispatch=IntrinsicDispatch.ATOMIC_FENCE
             ),
             "__c_thread_local": IntrinsicEntry(
                 name="__c_thread_local",
                 param_specs=["str"],
                 result_spec="i64",
                 dispatch=IntrinsicDispatch.C_THREAD_LOCAL
             ),
             "__mem_call_dtor": IntrinsicEntry(
                 name="__mem_call_dtor",
                 param_specs=["i64", "i64"],
                 result_spec="none",
                 dispatch=IntrinsicDispatch.CALL_DTOR
             ),
             "__jac_region_tls_get": IntrinsicEntry(
                 name="__jac_region_tls_get",
                 param_specs=[],
                 result_spec="i64",
                 dispatch=IntrinsicDispatch.REGION_TLS
             ),
             "__jac_region_tls_set": IntrinsicEntry(
                 name="__jac_region_tls_set",
                 param_specs=["i64"],
                 result_spec="none",
                 dispatch=IntrinsicDispatch.REGION_TLS
             ),
             "__jac_region_gbl_get": IntrinsicEntry(
                 name="__jac_region_gbl_get",
                 param_specs=[],
                 result_spec="i64",
                 dispatch=IntrinsicDispatch.REGION_TLS
             ),
             "__alloca": IntrinsicEntry(
                 name="__alloca",
                 param_specs=["i64"],
                 result_spec="i64",
                 dispatch=IntrinsicDispatch.ALLOCA
             )
         }
     );
