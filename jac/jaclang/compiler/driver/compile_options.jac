import from jaclang.runtime.object_model { field }

glob _config_probe: dict = {"active": False};

def _project_config -> any {
    if _config_probe["active"] {
        return None;
    }
    _config_probe["active"] = True;
    try {
        config_mod = __import__("jaclang.project.config", fromlist=["get_config"]);
        return config_mod.get_config();
    } except Exception {
        return None;
    } finally {
        _config_probe["active"] = False;
    }
}

obj CompileOptions {
    has symtab_ir_only: bool = False,
        no_cgen: bool = False,
        native_parity: bool = False,
        iface_ok: bool = False,
        need_full_ast: bool = False,
        skip_native_engine: bool = False,
        no_ir_cache: bool = False,
        resolve_annex_parent: bool = False,
        aot_mode: bool = False,
        native_unit: bool = False,
        native_link_mode: (str | None) = None,
        force_codespace: str = "",
        memory_profile: (str | None) = None,
        na_gc_mode: (str | None) = None,
        nogc_enforce_all: (bool | None) = None,
        memory_enforce: (list[str] | None) = None,
        memory_exempt: (list[str] | None) = None,
        native_threads: (int | None) = None,
        rc_debug_codegen: (bool | None) = None,
        native_target: (str | None) = None,
        native_debug: (bool | None) = None,
        opt_level: (int | None) = None,
        dump_ir_path: (str | None) = None,
        debug_ir: (bool | None) = None,
        rc_stats: (bool | None) = None,
        nogc_debug: (bool | None) = None,
        na_debug: (bool | None) = None,
        suppress_codes: list[str] = field(default_factory=`list),
        default_codespace: str = "",
        app_kind: str = "",
        target_app: str = "",
        ui: str = "",
        project_root: (str | None) = None,
        native_module_walk_order: (str | None) = None,
        cancel_token: any = None;

    def postinit {
        cfg = _project_config();
        mem_cfg = cfg.memory if cfg is not None else None;
        native_cfg = cfg.native if cfg is not None else None;
        if self.memory_profile is None {
            self.memory_profile = mem_cfg.profile if mem_cfg else "managed";
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
            self.memory_enforce = list(mem_cfg.enforce) if mem_cfg else [];
        }
        if self.memory_exempt is None {
            self.memory_exempt = list(mem_cfg.exempt) if mem_cfg else [];
        }
        if self.native_target is None {
            import from jaclang.compiler.frontend.codeinfo { effective_native_target }
            self.native_target = effective_native_target();
        }
        if self.native_debug is None {
            self.native_debug = native_cfg.debug if native_cfg else False;
        }
        if self.rc_debug_codegen is None {
            self.rc_debug_codegen = bool(self.native_debug);
        }
        if self.opt_level is None {
            self.opt_level = native_cfg.opt if native_cfg else 2;
        }
        if self.native_threads is None {
            self.native_threads = native_cfg.threads if native_cfg else 4;
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
            self.native_link_mode = native_cfg.link_mode if native_cfg else "objects";
        }
        if self.native_link_mode not in NATIVE_LINK_MODES {
            raise ValueError(
                f"native_link_mode must be one of {NATIVE_LINK_MODES}, "
                f"got {self.native_link_mode!r}"
            );
        }
    }

    def effective_triple -> str {
        if self.native_target {
            return str(self.native_target);
        }
        try {
            import from jaclang.compiler.backends.native.llvm.binding {
                get_default_triple
            }
            return str(get_default_triple());
        } except Exception {
            return "";
        }
    }

    def codegen_identity -> str {
        return ";".join(
            [
                f"gc={self.na_gc_mode}",
                f"nogc_all={int(bool(self.nogc_enforce_all))}",
                "nogc_mods=" + ",".join(sorted(self.memory_enforce or [])),
                "nogc_grand=" + ",".join(sorted(self.memory_exempt or [])),
                f"rc_debug={int(bool(self.rc_debug_codegen))}",
                f"target={self.effective_triple()}",
                f"native_debug={int(bool(self.native_debug))}",
                f"opt={self.opt_level}",
                f"threads={self.native_threads}",
                f"app={self.target_app}",
                f"app_kind={self.app_kind}"
            ]
        );
    }

    def codegen_fingerprint -> str {
        import hashlib;
        return hashlib.sha256(self.codegen_identity().encode()).hexdigest()[:12];
    }

    def analysis_identity -> str {
        return ";".join(
            [
                f"gc={self.na_gc_mode}",
                f"nogc_all={int(bool(self.nogc_enforce_all))}",
                "nogc_mods=" + ",".join(sorted(self.memory_enforce or [])),
                "nogc_grand=" + ",".join(sorted(self.memory_exempt or [])),
                f"target={self.native_target}",
                f"app={self.target_app}",
                f"app_kind={self.app_kind}"
            ]
        );
    }

    def analysis_fingerprint -> str {
        import hashlib;
        return hashlib.sha256(self.analysis_identity().encode()).hexdigest()[:12];
    }

    def clone_for_native_import -> CompileOptions {
        return CompileOptions(
            need_full_ast=True,
            skip_native_engine=True,
            no_ir_cache=self.no_ir_cache,
            aot_mode=True,
            default_codespace='native',
            native_unit=self.native_unit,
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

    def nogc_enforced_for(mod_name: str) -> bool {
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
}

glob NATIVE_LINK_MODE_OBJECTS: str = "objects",
     NATIVE_LINK_MODE_BITCODE: str = "bitcode",
     NATIVE_LINK_MODES: tuple[str, str] = ("objects", "bitcode");

def effective_codegen_fingerprint -> str {
    return CompileOptions().codegen_fingerprint();
}


def effective_analysis_fingerprint -> str {
    return CompileOptions().analysis_fingerprint();
}

def link_fingerprint_mismatches(
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

def env_symmap_requested -> bool {
    import os;
    return bool(os.environ.get("JAC_SYMMAP", ""));
}

def env_floor_dir -> str {
    import os;
    return os.environ.get("JAC_NATIVE_FLOOR_DIR", "");
}

def env_na_debug -> bool {
    import os;
    return os.environ.get("JAC_NA_DEBUG", "").strip().lower()
        in ("1", "true", "yes", "on");
}

def env_wasm_libc_dir -> str {
    import os;
    return os.environ.get("JAC_NATIVE_WASM_LIBC_DIR", "");
}

def env_llvm_shim_override -> (str | None) {
    import os;
    return os.environ.get("JAC_LLVM_SHIM", None);
}

def env_typed_pointers_enabled -> bool {
    import os;
    return os.environ.get(
        "JAC_LLVM_TYPED_POINTERS",
        os.environ.get("LLVMLITE_ENABLE_IR_LAYER_TYPED_POINTERS", "1")
    )
        == "1";
}

def push_native_target(triple: str) -> (str | None) {
    import from jaclang.compiler.frontend.codeinfo { set_native_target_override }
    return set_native_target_override(triple);
}

def pop_native_target(prev: (str | None)) {
    import from jaclang.compiler.frontend.codeinfo { _native_target_ctx }
    _native_target_ctx.set(prev);
}
