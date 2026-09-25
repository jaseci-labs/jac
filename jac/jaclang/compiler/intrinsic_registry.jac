enum IntrinsicDispatch {
    RC_RUNTIME = "rc_runtime",
    FLOAT_BITS = "float_bits",
    BITS_FLOAT = "bits_float",
    MEM_LOAD = "mem_load",
    MEM_STORE = "mem_store",
    ATOMIC_XCHG = "atomic_xchg",
    CALL_DTOR = "call_dtor",
    REGION_TLS = "region_tls",
    BUFFER_DATA = "buffer_data",
    REF_ADDR = "ref_addr",
    ALLOCA = "alloca"
}

obj IntrinsicEntry {
    has name: str,
        param_specs: list[str],
        result_spec: str,
        dispatch: IntrinsicDispatch,
        gc_mode_gate: str | None = None,
        width: (int | None) = None;

    def arity -> int {
        return len(self.param_specs);
    }
}

obj IntrinsicRegistry {
    has _entries: dict[str, IntrinsicEntry];

    def get(name: str) -> IntrinsicEntry | None {
        return self._entries.get(name, None);
    }

    def is_intrinsic(name: str) -> bool {
        return name in self._entries;
    }

    def names -> list[str] {
        return list(self._entries.keys());
    }

    def entries -> list[IntrinsicEntry] {
        return list(self._entries.values());
    }
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
                 result_spec="i64",
                 dispatch=IntrinsicDispatch.MEM_LOAD,
                 width=32
             ),
             "__mem_store_i32": IntrinsicEntry(
                 name="__mem_store_i32",
                 param_specs=["i64", "i64"],
                 result_spec="none",
                 dispatch=IntrinsicDispatch.MEM_STORE,
                 width=32
             ),
             "__mem_load_i64": IntrinsicEntry(
                 name="__mem_load_i64",
                 param_specs=["i64"],
                 result_spec="i64",
                 dispatch=IntrinsicDispatch.MEM_LOAD,
                 width=64
             ),
             "__mem_store_i64": IntrinsicEntry(
                 name="__mem_store_i64",
                 param_specs=["i64", "i64"],
                 result_spec="none",
                 dispatch=IntrinsicDispatch.MEM_STORE,
                 width=64
             ),
             "__mem_load_i8": IntrinsicEntry(
                 name="__mem_load_i8",
                 param_specs=["i64"],
                 result_spec="i64",
                 dispatch=IntrinsicDispatch.MEM_LOAD,
                 width=8
             ),
             "__mem_store_i8": IntrinsicEntry(
                 name="__mem_store_i8",
                 param_specs=["i64", "i64"],
                 result_spec="none",
                 dispatch=IntrinsicDispatch.MEM_STORE,
                 width=8
             ),
             "__mem_load_i16": IntrinsicEntry(
                 name="__mem_load_i16",
                 param_specs=["i64"],
                 result_spec="i64",
                 dispatch=IntrinsicDispatch.MEM_LOAD,
                 width=16
             ),
             "__mem_store_i16": IntrinsicEntry(
                 name="__mem_store_i16",
                 param_specs=["i64", "i64"],
                 result_spec="none",
                 dispatch=IntrinsicDispatch.MEM_STORE,
                 width=16
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
             "__ref_addr": IntrinsicEntry(
                 name="__ref_addr",
                 param_specs=["ref"],
                 result_spec="i64",
                 dispatch=IntrinsicDispatch.REF_ADDR
             ),
             "__atomic_xchg_i64": IntrinsicEntry(
                 name="__atomic_xchg_i64",
                 param_specs=["i64", "i64"],
                 result_spec="i64",
                 dispatch=IntrinsicDispatch.ATOMIC_XCHG
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
