impl TypeEvaluator.release_check_caches -> None {
    self._flow_node_type_cache.clear();
    self._flow_key_type_cache.clear();
    self._and_narrowing_overrides.clear();
    self._strict_site_cache.clear();
    self._sv_async_syms_cache.clear();
    self._loop_written_keys_cache.clear();
    self._type_guard_probes.clear();
}

impl TypeEvaluator.release_compile_caches -> None {
    self.release_check_caches();
    self._module_type_cache.clear();
    self._mobui_module_cache.clear();
    self._ts_decl_cache.clear();
    self._ts_decl_path_cache.clear();
    self._ts_synth_class_cache.clear();
    self._untyped_external_cfg_cache.clear();
    self._shared_intern.clear();
    self.symbol_resolution_stack.clear();
}
