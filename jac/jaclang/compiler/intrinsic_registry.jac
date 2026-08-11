enum IntrinsicDispatch {
    RC_RUNTIME = "rc_runtime",
    FLOAT_BITS = "float_bits",
    BITS_FLOAT = "bits_float"
}

obj IntrinsicEntry {
    has name: str,
        param_specs: list[str],
        result_spec: str,
        dispatch: IntrinsicDispatch,
        gc_mode_gate: str | None = None;

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
             )
         }
     );
