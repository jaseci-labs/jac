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

impl CompileOptions.codegen_identity -> str {
    return ";".join(
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
    );
}

impl CompileOptions.codegen_fingerprint -> str {
    import hashlib;
    return hashlib.sha256(self.codegen_identity().encode()).hexdigest()[:12];
}

impl CompileOptions.analysis_identity -> str {
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
        + (";strict_deps=1" if self.strict_dependencies else "");
}

impl CompileOptions.analysis_fingerprint -> str {
    import hashlib;
    return hashlib.sha256(self.analysis_identity().encode()).hexdigest()[:12];
}

impl CompileOptions.base_codegen_identity -> str {
    return ";".join(
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
    );
}

impl CompileOptions.module_projection -> str {
    return ";".join(
        [
            self.analysis_identity(),
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
        memory_profile=self.memory_profile,
        native_threads=self.native_threads,
        memory_enforce=list(self.memory_enforce or []),
        memory_exempt=list(self.memory_exempt or []),
        rc_debug_codegen=self.rc_debug_codegen,
        native_target=self.native_target,
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
        project_root=self.project_root
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
