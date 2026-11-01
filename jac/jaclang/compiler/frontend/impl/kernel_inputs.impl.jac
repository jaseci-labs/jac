impl RequestOptions.to_options -> CompileOptions {
    return CompileOptions(
        symtab_ir_only=self.symtab_ir_only,
        no_cgen=self.no_cgen,
        native_parity=self.native_parity,
        native_required=self.native_required,
        native_require=list(self.native_require),
        iface_ok=self.iface_ok,
        need_full_ast=self.need_full_ast,
        native_tree_demand=self.native_tree_demand,
        no_ir_cache=self.no_ir_cache,
        resolve_annex_parent=self.resolve_annex_parent,
        aot_mode=self.aot_mode,
        native_unit=self.native_unit,
        kernel_build=self.kernel_build,
        force_codespace=self.force_codespace,
        memory_profile=self.memory_profile,
        nogc_enforce_all=self.nogc_enforce_all,
        memory_enforce=list(self.memory_enforce),
        memory_exempt=list(self.memory_exempt),
        native_target=self.native_target,
        suppress_codes=list(self.suppress_codes),
        default_codespace=self.default_codespace,
        app_kind=self.app_kind,
        target_app=self.target_app,
        entry_point=self.entry_point,
        ui=self.ui,
        project_root=self.project_root,
        client_source_root=self.client_source_root,
        strict_dependencies=self.strict_dependencies,
        package_canonical=self.package_canonical,
        na_gc_mode=self.na_gc_mode or None,
        native_debug=self.native_debug,
        rc_debug_codegen=self.rc_debug_codegen,
        rc_stats=self.rc_stats,
        nogc_debug=self.nogc_debug,
        na_debug=self.na_debug,
        native_threads=self.native_threads if self.native_threads >= 0 else None,
        opt_level=self.opt_level if self.opt_level >= 0 else None
    );
}

impl ImportResolution.key -> str {
    return resolution_key(self.target, self.base_path, self.string_spec);
}

impl LocalResolution.key -> str {
    return local_key(self.base, self.parts);
}

impl NpmAnswer.key -> str {
    return pair_key(self.spec, self.base_path);
}

impl DeclaredDependencies.key -> str {
    return pair_key(self.module_path, self.fallback_app);
}

impl ManifestSets.is_seed(rel: str) -> bool {
    for entry_path in self.seed_paths {
        if entry_path.endswith("/") {
            if rel.startswith(entry_path) {
                return True;
            }
        } elif rel == entry_path {
            return True;
        }
    }
    return False;
}

impl ManifestSets.is_native_only(rel: str) -> bool {
    if rel in self.native_only_files {
        return True;
    }
    for directory in self.native_only_dirs {
        if rel.startswith(directory + "/") {
            return True;
        }
    }
    return False;
}

impl ManifestSets.is_native_lowered(rel: str) -> bool {
    for prefix in self.native_lowered {
        if rel == prefix or rel.startswith(prefix + "/") {
            return True;
        }
    }
    return False;
}

impl resolution_key(target: str, base_path: str, string_spec: bool) -> str {
    flag = "1" if string_spec else "0";
    return flag + KEY_SEP + target + KEY_SEP + base_path;
}

impl local_key(base: str, parts: list[str]) -> str {
    return base + KEY_SEP + "/".join(parts);
}

impl pair_key(first: str, second: str) -> str {
    return first + KEY_SEP + second;
}

impl request_of(options: CompileOptions) -> RequestOptions {
    return RequestOptions(
        symtab_ir_only=options.symtab_ir_only,
        no_cgen=options.no_cgen,
        native_parity=options.native_parity,
        native_required=options.native_required,
        native_require=list(options.native_require or []),
        iface_ok=options.iface_ok,
        need_full_ast=options.need_full_ast,
        native_tree_demand=options.native_tree_demand,
        no_ir_cache=options.no_ir_cache,
        resolve_annex_parent=options.resolve_annex_parent,
        aot_mode=options.aot_mode,
        native_unit=options.native_unit,
        kernel_build=options.kernel_build,
        force_codespace=options.force_codespace,
        memory_profile=options.memory_profile or "managed",
        nogc_enforce_all=bool(options.nogc_enforce_all),
        memory_enforce=list(options.memory_enforce or []),
        memory_exempt=list(options.memory_exempt or []),
        native_target=options.native_target or "",
        suppress_codes=list(options.suppress_codes),
        default_codespace=options.default_codespace,
        app_kind=options.app_kind,
        target_app=options.target_app,
        entry_point=options.entry_point,
        ui=options.ui,
        project_root=options.project_root,
        client_source_root=options.client_source_root,
        strict_dependencies=options.strict_dependencies,
        package_canonical=options.package_canonical,
        na_gc_mode=options.na_gc_mode or "",
        native_debug=bool(options.native_debug),
        rc_debug_codegen=bool(options.rc_debug_codegen),
        rc_stats=bool(options.rc_stats),
        nogc_debug=bool(options.nogc_debug),
        na_debug=bool(options.na_debug),
        native_threads=options.native_threads
            if options.native_threads is not None
            else -1,
        opt_level=options.opt_level if options.opt_level is not None else -1
    );
}

impl json_str_list(value: object) -> list[str] {
    out: list[str] = [];
    if isinstance(value, list) {
        for item in value {
            out.append(str(item));
        }
    }
    return out;
}

impl json_str_map(value: object) -> dict[str, str] {
    out: dict[str, str] = {};
    if isinstance(value, dict) {
        for (key, item) in value.items() {
            out[str(key)] = str(item);
        }
    }
    return out;
}

impl json_map(value: object) -> dict[str, any] {
    out: dict[str, any] = {};
    if isinstance(value, dict) {
        for (key, item) in value.items() {
            out[str(key)] = item;
        }
    }
    return out;
}

impl json_maps(value: object) -> list[dict[str, any]] {
    out: list[dict[str, any]] = [];
    if isinstance(value, list) {
        for item in value {
            out.append(json_map(item));
        }
    }
    return out;
}

impl json_int(value: object, fallback: int = 0) -> int {
    if isinstance(value, bool) {
        return 1 if value else 0;
    }
    if isinstance(value, int) {
        return value;
    }
    return fallback;
}

impl json_opt_str(value: object) -> (str | None) {
    if value is None {
        return None;
    }
    return str(value);
}

