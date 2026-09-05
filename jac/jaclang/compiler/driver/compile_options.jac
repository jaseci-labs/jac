import from dataclasses { field }

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
        resolve_annex_parent: bool = False,
        force_target_program: bool = False,
        aot_mode: bool = False,
        native_unit: bool = False,
        native_link_mode: (str | None) = None,
        force_codespace: str = "",
        na_gc_mode: (str | None) = None,
        nogc_enforce_all: bool = False,
        nogc_cli_target: str = "",
        nogc_enforce_modules: (list[str] | None) = None,
        nogc_grandfathered: (list[str] | None) = None,
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
        project_kind: str = "web",
        project_root: (str | None) = None,
        native_module_walk_order: (str | None) = None,
        cancel_token: any = None;

    def postinit {
        import os;
        cfg = _project_config();
        gc_cfg = cfg.gc if cfg is not None else None;
        native_cfg = cfg.build.native if cfg is not None else None;
        if self.na_gc_mode is None {
            self.na_gc_mode = gc_cfg.`default if gc_cfg else "cycles";
        }
        if self.nogc_enforce_modules is None {
            self.nogc_enforce_modules = list(gc_cfg.enforce.modules) if gc_cfg else [];
        }
        if self.nogc_grandfathered is None {
            self.nogc_grandfathered = (
                list(gc_cfg.enforce.grandfathered) if gc_cfg else []
            );
        }
        if self.rc_debug_codegen is None {
            self.rc_debug_codegen = bool(os.environ.get("JAC_RC_DEBUG_CODEGEN", ""))
                or (native_cfg.rc_debug_codegen if native_cfg else False);
        }
        if self.native_target is None {
            self.native_target = os.environ.get("JAC_NATIVE_TARGET", "")
                or (native_cfg.target if native_cfg else "");
        }
        if self.native_debug is None {
            self.native_debug = bool(os.environ.get("JAC_NATIVE_DEBUG", ""))
                or (native_cfg.debug if native_cfg else False);
        }
        if self.opt_level is None {
            _env_opt = os.environ.get("JAC_OPT_LEVEL", "");
            self.opt_level = int(_env_opt)
                if _env_opt
                else (native_cfg.opt_level if native_cfg else 2);
        }
        if self.dump_ir_path is None {
            self.dump_ir_path = os.environ.get("JAC_DUMP_IR", "")
                or (native_cfg.dump_ir if native_cfg else "");
        }
        if self.debug_ir is None {
            self.debug_ir = os.environ.get("JAC_DEBUG_IR", "").strip().lower()
                in ("1", "true", "yes", "on");
        }
        if self.rc_stats is None {
            self.rc_stats = bool(os.environ.get("JAC_RC_STATS", ""));
        }
        if self.nogc_debug is None {
            self.nogc_debug = bool(os.environ.get("JAC_NOGC_DEBUG", ""));
        }
        if self.na_debug is None {
            self.na_debug = env_na_debug();
        }
        if self.native_link_mode is None {
            self.native_link_mode = env_native_link_mode();
        }
        if self.native_link_mode not in NATIVE_LINK_MODES {
            raise ValueError(
                f"native_link_mode must be one of {NATIVE_LINK_MODES}, "
                f"got {self.native_link_mode!r}"
            );
        }
    }

    """The target triple this compile emits for: the override, else the host."""
    def effective_triple -> str {
        if self.native_target {
            return str(self.native_target);
        }
        try {
            import jaclang.compiler.backends.native.llvm.binding as llvm;
            return str(llvm.get_default_triple());
        } except Exception {
            return "";
        }
    }

    def codegen_identity -> str {
        return ";".join(
            [
                f"gc={self.na_gc_mode}",
                f"nogc_all={int(bool(self.nogc_enforce_all))}",
                f"nogc_cli={self.nogc_cli_target}",
                "nogc_mods=" + ",".join(sorted(self.nogc_enforce_modules or [])),
                "nogc_grand=" + ",".join(sorted(self.nogc_grandfathered or [])),
                f"rc_debug={int(bool(self.rc_debug_codegen))}",
                f"target={self.native_target}",
                f"native_debug={int(bool(self.native_debug))}",
                f"opt={self.opt_level}"
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
                f"nogc_cli={self.nogc_cli_target}",
                "nogc_mods=" + ",".join(sorted(self.nogc_enforce_modules or [])),
                "nogc_grand=" + ",".join(sorted(self.nogc_grandfathered or [])),
                f"target={self.native_target}"
            ]
        );
    }

    def analysis_fingerprint -> str {
        import hashlib;
        return hashlib.sha256(self.analysis_identity().encode()).hexdigest()[:12];
    }

    def clone_for_native_import -> CompileOptions {
        return CompileOptions(
            skip_native_engine=True,
            aot_mode=True,
            default_codespace='native',
            force_target_program=True,
            native_unit=self.native_unit,
            native_link_mode=self.native_link_mode,
            na_gc_mode=self.na_gc_mode,
            nogc_enforce_all=self.nogc_enforce_all,
            nogc_enforce_modules=list(self.nogc_enforce_modules or []),
            nogc_grandfathered=list(self.nogc_grandfathered or []),
            rc_debug_codegen=self.rc_debug_codegen,
            native_target=self.native_target,
            native_debug=self.native_debug,
            opt_level=self.opt_level,
            dump_ir_path=self.dump_ir_path,
            debug_ir=self.debug_ir,
            rc_stats=self.rc_stats,
            nogc_debug=self.nogc_debug,
            na_debug=self.na_debug
        );
    }

    def nogc_enforced_for(mod_name: str) -> bool {
        if self.nogc_enforce_all {
            return True;
        }
        if not self.nogc_enforce_modules {
            return False;
        }
        import fnmatch;
        for _pat in self.nogc_grandfathered or [] {
            if fnmatch.fnmatchcase(mod_name, _pat) {
                return False;
            }
        }
        for _pat in self.nogc_enforce_modules {
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

"""How the link plan combines units: relocatable objects (the incremental
default) or one whole-program LLVM module from every unit's bitcode (the
release lane). `JAC_NATIVE_LINK_MODE` selects it for a whole build."""
def env_native_link_mode -> str {
    import os;
    raw = os.environ.get("JAC_NATIVE_LINK_MODE", "").strip().lower();
    return raw if raw in NATIVE_LINK_MODES else NATIVE_LINK_MODE_OBJECTS;
}

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

def push_native_target_env(triple: str) -> (str | None) {
    import os;
    prev = os.environ.get("JAC_NATIVE_TARGET", None);
    os.environ["JAC_NATIVE_TARGET"] = triple;
    return prev;
}

def pop_native_target_env(prev: (str | None)) {
    import os;
    if prev is None {
        os.environ.pop("JAC_NATIVE_TARGET", None);
    } else {
        os.environ["JAC_NATIVE_TARGET"] = prev;
    }
}
