import from jaclang.jac0core.passes.pass_rim { _NATIVE_SERVED_PASSES }

glob _PASS_ARTIFACT_PREFIXES: tuple = (
         "jaclang.jac0core.passes.",
         "jaclang.compiler.passes."
     ),
     _ANNEX_MODULE: str = "jaclang.jac0core.passes.annex_pass",
     _MERGE_CANARY_MAIN: tuple = (
         "obj Gadget {",
         "    has n: int = 1;",
         "    def bump -> int;",
         "}",

     ),
     _MERGE_CANARY_ANNEX: tuple = (
         "impl Gadget.bump -> int {",
         "    self.n += 1;",
         "    return self.n;",
         "}",

     ),
     _BIND_KEEP: list = [];

def _serve_error(fullname: str, reason: str) -> RuntimeError {
    return RuntimeError(
        f"sealed pass artifact for {fullname} could not be bound: {reason}. "
        "The image claims this pass module natively and refuses the "
        "bytecode tier; reinstall or rebuild the payload."
    );
}

def _bind_one(fullname: str) {
    import from jaclang.jac0core.sealed { native_artifact_for }
    found = native_artifact_for(fullname);
    if found is None {
        raise _serve_error(fullname, "the manifest names it but no image resolves it");
    }
    (lib_path, layout_dict) = found;
    import from jaclang.jac0core.native_dylib { DylibEngine }
    try {
        eng = DylibEngine(lib_path);
        eng.initialize();
    } except Exception as open_exc {
        raise _serve_error(
            fullname, f"dlopen/init failed ({type(open_exc).__name__}: {open_exc})"
        );
    }
    advertised: set[str] = set((layout_dict.get("functions") or {}).keys());
    structs: dict[str, dict] = layout_dict.get("structs") or {};
    for sd in structs.values() {
        accessors: dict[str, dict[str, str]] = sd.get("accessors") or {};
        for kinds in accessors.values() {
            advertised.update(kinds.values());
        }
    }
    missing = sorted(
        m
        for m in advertised
        if eng.get_function_address(m) == 0
    );
    if missing {
        shown = ", ".join(missing[:6]);
        raise _serve_error(
            fullname,
            f"{len(missing)} advertised export(s) are not in the linked "
            f"artifact (first: {shown})"
        );
    }
    import ctypes;
    probe = eng.get_function_address("jac_str_new");
    if not probe {
        raise _serve_error(fullname, "jac_str_new is not exported");
    }
    made = ctypes.CFUNCTYPE(ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int64)(probe)(
        b"jac", 3
    );
    if not made {
        raise _serve_error(
            fullname, "jac_str_new returned NULL; the runtime is not live"
        );
    }
    if fullname == _ANNEX_MODULE {
        _native_merge_canary();
    }
    _BIND_KEEP.append(eng);
    _NATIVE_SERVED_PASSES.add(fullname);
}

def _native_merge_canary {
    import from jaclang.jac0core.native_brands { native_parser }
    np = native_parser("pass_serve:merge_canary");
    if np is None {
        raise _serve_error(
            _ANNEX_MODULE,
            "the image seals the annex pass but binds no native parser, so "
            "the merge canary cannot run"
        );
    }
    nl = chr(10);
    annex_path = "__pass_serve_merge_canary__.impl.jac";
    (merged, m_errs, a_errs) = np.merge_probe(
        nl.join(list(_MERGE_CANARY_MAIN)),
        "__pass_serve_merge_canary__.jac",
        nl.join(list(_MERGE_CANARY_ANNEX)),
        annex_path
    );
    if m_errs or a_errs {
        raise _serve_error(
            _ANNEX_MODULE,
            f"the merge canary sources did not parse cleanly (main {m_errs}, "
            f"annex {a_errs} error(s))"
        );
    }
    woven = [
        stmt
        for stmt in merged.body
        if stmt.loc.mod_path == annex_path
    ];
    if not woven {
        raise _serve_error(
            _ANNEX_MODULE,
            "mat_merge_probe returned a module with no statement from the "
            "annex source; the native JacAnnexPass._merge_annex did not weave"
        );
    }
}

def bind_sealed_pass_artifacts {
    import from jaclang.jac0core.sealed { native_artifact_names }
    for fullname in sorted(native_artifact_names()) {
        if fullname in _NATIVE_SERVED_PASSES {
            continue;
        }
        if not any(fullname.startswith(p) for p in _PASS_ARTIFACT_PREFIXES) {
            continue;
        }
        _bind_one(fullname);
    }
}
