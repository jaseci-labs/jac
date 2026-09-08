enum IntrinsicDispatch {
    RC_RUNTIME = "rc_runtime",
    FLOAT_BITS = "float_bits",
    BITS_FLOAT = "bits_float",
    MEM_LOAD = "mem_load",
    MEM_STORE = "mem_store",
    MEM_ALLOC = "mem_alloc",
    MEM_RC_ENABLED = "mem_rc_enabled",
    MEM_COPY = "mem_copy",
    ATOMIC_XCHG = "atomic_xchg",
    MEM_CALL = "mem_call"
}

enum IntrinsicStorage { VALUE = "value", POINTER = "pointer" }

enum IntrinsicAllocation { RAW = "raw", ZEROED = "zeroed", MANAGED = "managed" }

obj IntrinsicEntry {
    has name: str,
        param_specs: list[str],
        result_spec: str,
        dispatch: IntrinsicDispatch,
        gc_mode_gate: str | None = None,
        storage: IntrinsicStorage = IntrinsicStorage.VALUE,
        allocation: IntrinsicAllocation = IntrinsicAllocation.RAW;

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
             "__mem_load_u8": IntrinsicEntry(
                 name="__mem_load_u8",
                 param_specs=["i64"],
                 result_spec="u8",
                 dispatch=IntrinsicDispatch.MEM_LOAD
             ),
             "__mem_store_u8": IntrinsicEntry(
                 name="__mem_store_u8",
                 param_specs=["i64", "u8"],
                 result_spec="none",
                 dispatch=IntrinsicDispatch.MEM_STORE
             ),
             "__mem_alloc_zeroed": IntrinsicEntry(
                 name="__mem_alloc_zeroed",
                 param_specs=["i64"],
                 result_spec="i64",
                 dispatch=IntrinsicDispatch.MEM_ALLOC,
                 allocation=IntrinsicAllocation.ZEROED
             ),
             "__mem_call_i64": IntrinsicEntry(
                 name="__mem_call_i64",
                 param_specs=["i64", "i64"],
                 result_spec="i64",
                 dispatch=IntrinsicDispatch.MEM_CALL
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
             "__mem_load_ptr": IntrinsicEntry(
                 name="__mem_load_ptr",
                 param_specs=["i64"],
                 result_spec="i64",
                 dispatch=IntrinsicDispatch.MEM_LOAD,
                 storage=IntrinsicStorage.POINTER
             ),
             "__mem_alloc": IntrinsicEntry(
                 name="__mem_alloc",
                 param_specs=["i64"],
                 result_spec="i64",
                 dispatch=IntrinsicDispatch.MEM_ALLOC
             ),
             "__mem_copy": IntrinsicEntry(
                 name="__mem_copy",
                 param_specs=["i64", "i64", "i64"],
                 result_spec="none",
                 dispatch=IntrinsicDispatch.MEM_COPY
             ),
             "__mem_alloc_managed": IntrinsicEntry(
                 name="__mem_alloc_managed",
                 param_specs=["i64"],
                 result_spec="i64",
                 dispatch=IntrinsicDispatch.MEM_ALLOC,
                 allocation=IntrinsicAllocation.MANAGED
             ),
             "__mem_rc_enabled": IntrinsicEntry(
                 name="__mem_rc_enabled",
                 param_specs=[],
                 result_spec="i64",
                 dispatch=IntrinsicDispatch.MEM_RC_ENABLED
             ),
             "__mem_store_ptr": IntrinsicEntry(
                 name="__mem_store_ptr",
                 param_specs=["i64", "i64"],
                 result_spec="none",
                 dispatch=IntrinsicDispatch.MEM_STORE,
                 storage=IntrinsicStorage.POINTER
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
                 dispatch=IntrinsicDispatch.MEM_CALL
             )
         }
     );
