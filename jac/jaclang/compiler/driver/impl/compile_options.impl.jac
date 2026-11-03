impl CancelToken.set {
    self.requested = True;
}

impl CancelToken.clear {
    self.requested = False;
}

impl CancelToken.is_set -> bool {
    return self.requested;
}

impl CompileOptions.postinit {
    project = active_host().project_defaults();
    if self.native_require is None {
        self.native_require = list(project.native_require) if project else [];
    }
    if self.memory_profile is None {
        self.memory_profile = project.memory_profile if project else "managed";
    }
    if self.memory_profile not in ("managed", "rc", "nogc") {
        raise ValueError(
            f"memory profile must be managed, rc or nogc (got '{self.memory_profile}')"
        );
    }
    if self.na_gc_mode is None {
        modes: dict[str, str] = {"managed": "cycles", "rc": "rc", "nogc": "none"};
        assert self.memory_profile is not None;
        self.na_gc_mode = modes[self.memory_profile];
    }
    if self.nogc_enforce_all is None {
        self.nogc_enforce_all = self.memory_profile == "nogc";
    }
    if self.memory_enforce is None {
        self.memory_enforce = list(project.memory_enforce) if project else [];
    }
    if self.memory_exempt is None {
        self.memory_exempt = list(project.memory_exempt) if project else [];
    }
    if self.native_target is None {
        import from jaclang.compiler.frontend.codeinfo { effective_native_target }
        self.native_target = effective_native_target();
    }
    if self.native_debug is None {
        self.native_debug = project.native_debug if project else False;
    }
    if self.rc_debug_codegen is None {
        self.rc_debug_codegen = bool(self.native_debug);
    }
    if self.opt_level is None {
        self.opt_level = project.native_opt if project else 2;
    }
    if self.native_threads is None {
        self.native_threads = project.native_threads if project else 4;
    }
    if self.dump_ir_path is None {
        self.dump_ir_path = "";
    }
    if self.debug_ir is None {
        self.debug_ir = bool(self.native_debug);
    }
    if self.rc_stats is None {
        self.rc_stats = False;
    }
    if self.nogc_debug is None {
        self.nogc_debug = False;
    }
    if self.na_debug is None {
        self.na_debug = env_na_debug();
    }
    if self.native_link_mode is None {
        self.native_link_mode = project.native_link_mode if project else "objects";
    }
    if self.native_link_mode not in NATIVE_LINK_MODES {
        raise ValueError(
            f"native_link_mode must be one of {NATIVE_LINK_MODES}, "
            f"got {self.native_link_mode!r}"
        );
    }
}

impl CompileOptions.effective_triple -> str {
    if self.native_target {
        return str(self.native_target);
    }
    import from jaclang.compiler.frontend.host { active_host }
    return active_host().default_target_triple();
}

impl CompileOptions.native_options_identity -> str {
    return ("tls=1;" if self.native_tls else "")
        + ("sjlj=1;" if self.native_sjlj else "")
        + ("rawview=1;" if self.native_unchecked_views else "")
        + ("directc=1;" if self.native_direct_c_entries else "")
        + (f"heap={self.native_heap};" if self.native_heap else "");
}

impl CompileOptions.codegen_identity -> str {
    return self.native_options_identity()
        + ";".join(
            [
                f"native_required={int(self.native_required)}",
                "native_require=" + ",".join(sorted(self.native_require or [])),
                f"gc={self.na_gc_mode}",
                f"nogc_all={int(bool(self.nogc_enforce_all))}",
                "nogc_mods=" + ",".join(sorted(self.memory_enforce or [])),
                "nogc_grand=" + ",".join(sorted(self.memory_exempt or [])),
                f"rc_debug={int(bool(self.rc_debug_codegen))}",
                f"target={self.native_target}",
                f"native_debug={int(bool(self.native_debug))}",
                f"opt={self.opt_level}",
                f"threads={self.native_threads}",
                f"app={self.target_app}",
                f"app_kind={self.app_kind}"
            ]
        )
        + ("" if self.na_borrow_infer else ";borrow_infer=0")
        + ("" if self.na_move_flow else ";move_flow=0")
        + (
            f";client_root={self.client_source_root}" if self.client_source_root else ""
        );
}

impl CompileOptions.codegen_fingerprint -> str {
    import hashlib;
    return hashlib.sha256(self.codegen_identity().encode()).hexdigest()[:12];
}

impl CompileOptions.analysis_identity -> str {
    return self.artifact_identity()
        + (";strict_deps=1" if self.strict_dependencies else "");
}

impl CompileOptions.artifact_identity -> str {
    return ";".join(
        [
            f"native_required={int(self.native_required)}",
            "native_require=" + ",".join(sorted(self.native_require or [])),
            f"gc={self.na_gc_mode}",
            f"nogc_all={int(bool(self.nogc_enforce_all))}",
            "nogc_mods=" + ",".join(sorted(self.memory_enforce or [])),
            "nogc_grand=" + ",".join(sorted(self.memory_exempt or [])),
            f"target={self.native_target}",
            f"app={self.target_app}",
            f"app_kind={self.app_kind}"
        ]
    )
        + ("" if self.na_borrow_infer else ";borrow_infer=0")
        + ("" if self.na_move_flow else ";move_flow=0");
}

impl CompileOptions.analysis_fingerprint -> str {
    import hashlib;
    return hashlib.sha256(self.analysis_identity().encode()).hexdigest()[:12];
}

impl CompileOptions.base_codegen_identity -> str {
    return self.native_options_identity()
        + ";".join(
            [
                f"gc={self.na_gc_mode}",
                f"nogc_all={int(bool(self.nogc_enforce_all))}",
                "nogc_mods=" + ",".join(sorted(self.memory_enforce or [])),
                "nogc_grand=" + ",".join(sorted(self.memory_exempt or [])),
                f"rc_debug={int(bool(self.rc_debug_codegen))}",
                f"target={self.native_target}",
                f"native_debug={int(bool(self.native_debug))}",
                f"opt={self.opt_level}",
                f"threads={self.native_threads}"
            ]
        );
}

impl CompileOptions.unit_codegen_identity(path: str) -> str {
    required = int(self.native_required_for(path)) if path else 0;
    return self.base_codegen_identity() + f";required={required}";
}

impl CompileOptions.dependency_projection(path: str) -> str {
    return ";".join(
        [
            self.unit_codegen_identity(path),
            f"app_kind={self.app_kind}",
            f"aot={int(bool(self.aot_mode))}",
            f"force_cs={self.force_codespace}",
            f"default_cs={self.default_codespace}",
            f"ui={self.ui}"
        ]
    )
        + (
            f";client_root={self.client_source_root}" if self.client_source_root else ""
        );
}

impl CompileOptions.module_projection -> str {
    return ";".join(
        [
            self.artifact_identity(),
            self.codegen_identity(),
            f"aot={int(bool(self.aot_mode))}",
            f"force_cs={self.force_codespace}",
            f"default_cs={self.default_codespace}",
            f"ui={self.ui}",
            f"root={self.project_root or ''}"
        ]
    );
}

impl CompileOptions.keeps_interfaces -> bool {
    return not (
        self.aot_mode or bool(self.force_codespace) or bool(self.default_codespace)
    );
}

impl CompileOptions.for_symbols(need_tree: bool = False) -> CompileOptions {
    import copy;
    result = copy.copy(self);
    result.no_cgen = True;
    result.symtab_ir_only = True;
    result.iface_ok = not need_tree;
    result.need_full_ast = need_tree;
    result.native_parity = False;

    return result;
}

impl CompileOptions.clone_for_native_import -> CompileOptions {
    return CompileOptions(
        need_full_ast=True,
        skip_native_engine=True,
        no_ir_cache=self.no_ir_cache,
        native_required=self.native_required,
        native_require=list(self.native_require or []),
        aot_mode=True,
        default_codespace='native',
        native_unit=self.native_unit,
        kernel_build=self.kernel_build,
        native_link_mode=self.native_link_mode,
        na_gc_mode=self.na_gc_mode,
        nogc_enforce_all=self.nogc_enforce_all,
        na_borrow_infer=self.na_borrow_infer,
        memory_profile=self.memory_profile,
        native_threads=self.native_threads,
        memory_enforce=list(self.memory_enforce or []),
        memory_exempt=list(self.memory_exempt or []),
        rc_debug_codegen=self.rc_debug_codegen,
        native_target=self.native_target,
        native_tls=self.native_tls,
        native_sjlj=self.native_sjlj,
        native_unchecked_views=self.native_unchecked_views,
        native_direct_c_entries=self.native_direct_c_entries,
        native_heap=self.native_heap,
        native_debug=self.native_debug,
        opt_level=self.opt_level,
        dump_ir_path=self.dump_ir_path,
        debug_ir=self.debug_ir,
        rc_stats=self.rc_stats,
        nogc_debug=self.nogc_debug,
        na_debug=self.na_debug,
        app_kind=self.app_kind,
        target_app=self.target_app,
        ui=self.ui,
        project_root=self.project_root,
        na_move_flow=self.na_move_flow
    );
}

impl CompileOptions.native_required_for(mod_path: str) -> bool {
    if self.native_required {
        return True;
    }
    if not self.native_require {
        return False;
    }
    import fnmatch;
    import from jaclang.compiler.frontend.codeinfo { module_dotted_name }
    name = module_dotted_name(mod_path);
    return any(fnmatch.fnmatchcase(name, pattern) for pattern in self.native_require);
}

impl CompileOptions.nogc_enforced_for(mod_name: str) -> bool {
    if self.nogc_enforce_all {
        return True;
    }
    if not self.memory_enforce {
        return False;
    }
    import fnmatch;
    for _pat in self.memory_exempt or [] {
        if fnmatch.fnmatchcase(mod_name, _pat) {
            return False;
        }
    }
    for _pat in self.memory_enforce {
        if fnmatch.fnmatchcase(mod_name, _pat) {
            return True;
        }
    }
    return False;
}

impl effective_codegen_fingerprint -> str {
    return CompileOptions().codegen_fingerprint();
}

impl effective_analysis_fingerprint -> str {
    return CompileOptions().analysis_fingerprint();
}

impl link_fingerprint_mismatches(
    participants: list[tuple[str, str]], current_fp: str
) -> list[str] {
    out: list[str] = [];
    for (name, fp) in participants {
        if fp != current_fp {
            out.append(name);
        }
    }
    return out;
}

impl env_symmap_requested -> bool {
    import os;
    return bool(os.environ.get("JAC_SYMMAP", ""));
}

impl env_na_debug -> bool {
    import os;
    return os.environ.get("JAC_NA_DEBUG", "").strip().lower()
        in ("1", "true", "yes", "on");
}

impl env_typed_pointers_enabled -> bool {
    import os;
    return os.environ.get(
        "JAC_LLVM_TYPED_POINTERS",
        os.environ.get("LLVMLITE_ENABLE_IR_LAYER_TYPED_POINTERS", "1")
    )
        == "1";
}

impl push_native_target(triple: str) -> (str | None) {
    return set_native_target_override(triple);
}

impl pop_native_target(prev: (str | None)) {
    _native_target_ctx.set(prev);
}

impl CompileOptions.to_dict -> dict[str, any] {
    return {
        "symtab_ir_only": self.symtab_ir_only,
        "no_cgen": self.no_cgen,
        "native_parity": self.native_parity,
        "native_required": self.native_required,
        "native_require": (list(self.native_require) if self.native_require is not None else None),
        "iface_ok": self.iface_ok,
        "need_full_ast": self.need_full_ast,
        "native_tree_demand": self.native_tree_demand,
        "skip_analysis": self.skip_analysis,
        "skip_native_engine": self.skip_native_engine,
        "no_ir_cache": self.no_ir_cache,
        "resolve_annex_parent": self.resolve_annex_parent,
        "aot_mode": self.aot_mode,
        "native_unit": self.native_unit,
        "kernel_build": self.kernel_build,
        "native_link_mode": self.native_link_mode,
        "force_codespace": self.force_codespace,
        "memory_profile": self.memory_profile,
        "na_gc_mode": self.na_gc_mode,
        "nogc_enforce_all": self.nogc_enforce_all,
        "na_borrow_infer": self.na_borrow_infer,
        "memory_enforce": (list(self.memory_enforce) if self.memory_enforce is not None else None),
        "memory_exempt": (list(self.memory_exempt) if self.memory_exempt is not None else None),
        "native_threads": self.native_threads,
        "rc_debug_codegen": self.rc_debug_codegen,
        "native_target": self.native_target,
        "native_tls": self.native_tls,
        "native_sjlj": self.native_sjlj,
        "native_unchecked_views": self.native_unchecked_views,
        "native_direct_c_entries": self.native_direct_c_entries,
        "native_heap": self.native_heap,
        "native_debug": self.native_debug,
        "opt_level": self.opt_level,
        "dump_ir_path": self.dump_ir_path,
        "debug_ir": self.debug_ir,
        "rc_stats": self.rc_stats,
        "nogc_debug": self.nogc_debug,
        "na_debug": self.na_debug,
        "suppress_codes": list(self.suppress_codes),
        "default_codespace": self.default_codespace,
        "app_kind": self.app_kind,
        "target_app": self.target_app,
        "entry_point": self.entry_point,
        "ui": self.ui,
        "project_root": self.project_root,
        "client_source_root": self.client_source_root,
        "native_module_walk_order": self.native_module_walk_order,
        "strict_dependencies": self.strict_dependencies,
        "package_canonical": self.package_canonical,
        "na_move_flow": self.na_move_flow
    };
}

impl CompileOptions.from_dict(raw: dict[str, any]) -> CompileOptions {
    return CompileOptions(
        symtab_ir_only=bool(raw["symtab_ir_only"]),
        no_cgen=bool(raw["no_cgen"]),
        native_parity=bool(raw["native_parity"]),
        native_required=bool(raw["native_required"]),
        native_require=optional_texts(raw["native_require"]),
        iface_ok=bool(raw["iface_ok"]),
        need_full_ast=bool(raw["need_full_ast"]),
        native_tree_demand=bool(raw["native_tree_demand"]),
        skip_analysis=bool(raw["skip_analysis"]),
        skip_native_engine=bool(raw["skip_native_engine"]),
        no_ir_cache=bool(raw["no_ir_cache"]),
        resolve_annex_parent=bool(raw["resolve_annex_parent"]),
        aot_mode=bool(raw["aot_mode"]),
        native_unit=bool(raw["native_unit"]),
        kernel_build=bool(raw["kernel_build"]),
        native_link_mode=optional_text(raw["native_link_mode"]),
        force_codespace=str(raw["force_codespace"]),
        memory_profile=optional_text(raw["memory_profile"]),
        na_gc_mode=optional_text(raw["na_gc_mode"]),
        nogc_enforce_all=optional_flag(raw["nogc_enforce_all"]),
        na_borrow_infer=bool(raw["na_borrow_infer"]),
        memory_enforce=optional_texts(raw["memory_enforce"]),
        memory_exempt=optional_texts(raw["memory_exempt"]),
        native_threads=optional_number(raw["native_threads"]),
        rc_debug_codegen=optional_flag(raw["rc_debug_codegen"]),
        native_target=optional_text(raw["native_target"]),
        native_tls=bool(raw["native_tls"]),
        native_sjlj=bool(raw["native_sjlj"]),
        native_unchecked_views=bool(raw["native_unchecked_views"]),
        native_direct_c_entries=bool(raw["native_direct_c_entries"]),
        native_heap=str(raw["native_heap"]),
        native_debug=optional_flag(raw["native_debug"]),
        opt_level=optional_number(raw["opt_level"]),
        dump_ir_path=optional_text(raw["dump_ir_path"]),
        debug_ir=optional_flag(raw["debug_ir"]),
        rc_stats=optional_flag(raw["rc_stats"]),
        nogc_debug=optional_flag(raw["nogc_debug"]),
        na_debug=optional_flag(raw["na_debug"]),
        suppress_codes=[str(item) for item in raw["suppress_codes"]],
        default_codespace=str(raw["default_codespace"]),
        app_kind=str(raw["app_kind"]),
        target_app=str(raw["target_app"]),
        entry_point=str(raw["entry_point"]),
        ui=str(raw["ui"]),
        project_root=optional_text(raw["project_root"]),
        client_source_root=str(raw["client_source_root"]),
        native_module_walk_order=optional_text(raw["native_module_walk_order"]),
        strict_dependencies=bool(raw["strict_dependencies"]),
        package_canonical=bool(raw["package_canonical"]),
        na_move_flow=bool(raw["na_move_flow"])
    );
}

impl optional_flag(value: any) -> (bool | None) {
    if value is None {
        return None;
    }
    return bool(value);
}

impl optional_number(value: any) -> (int | None) {
    if value is None {
        return None;
    }
    return int(value);
}

impl optional_text(value: any) -> (str | None) {
    if value is None {
        return None;
    }
    return str(value);
}

impl optional_texts(value: any) -> (list[str] | None) {
    if value is None {
        return None;
    }
    return [str(item) for item in value];
}
