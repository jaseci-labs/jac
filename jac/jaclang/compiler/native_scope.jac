import os;

obj NativeScopeEntry {
    has module: str,
        strict: bool = False;
}

glob NATIVE_SCOPE: tuple[NativeScopeEntry, ...] = (
         NativeScopeEntry(module="jaclang.compiler.frontend.constant", strict=True),
         NativeScopeEntry(module="jaclang.compiler.frontend.srcloc", strict=True),
         NativeScopeEntry(module="jaclang.compiler.frontend.roles", strict=True),
         NativeScopeEntry(module="jaclang.compiler.frontend.relations", strict=True),
         NativeScopeEntry(module="jaclang.compiler.frontend.unitree", strict=True),
         NativeScopeEntry(
             module="jaclang.compiler.frontend.parser.tokens", strict=True
         ),
         NativeScopeEntry(module="jaclang.compiler.frontend.parser.lexer", strict=True),
         NativeScopeEntry(
             module="jaclang.compiler.frontend.parser.parser", strict=True
         ),
         NativeScopeEntry(module="jaclang.compiler.jc_materialize", strict=True),
         NativeScopeEntry(module="jaclang.compiler.jc_unit", strict=True),
         NativeScopeEntry(module="jaclang.compiler.frontend.diagnostics", strict=True),
         NativeScopeEntry(module="jaclang.compiler.passes.transform", strict=True),
         NativeScopeEntry(module="jaclang.compiler.passes.uni_pass", strict=True),
         NativeScopeEntry(
             module="jaclang.compiler.passes.ast_validation_pass", strict=True
         ),
         NativeScopeEntry(
             module="jaclang.compiler.passes.sym_tab_build_pass", strict=True
         ),

     );

glob _SCOPE_SUFFIX_CACHE: list[str] = [],
     _SCOPE_ACTIVE: list[int] = [];

def activate_scope_lowering -> None {
    if _SCOPE_ACTIVE {
        return;
    }
    _SCOPE_ACTIVE.append(1);
    try {
        import from jaclang.runtime.runtime { JacRuntime }
        sh = JacRuntime.get_selfhost();
        prog = sh.peek_program();
        if prog is not None {
            hub = prog.mod.hub;
            for k in list(hub.keys()) {
                if in_native_scope_path(k) {
                    del hub[k];
                }
            }
        }
    } except Exception {}
}

def scope_lowering_active -> bool {
    return len(_SCOPE_ACTIVE) > 0;
}

def deactivate_scope_lowering {
    """Turn scope lowering back off once the build that armed it is done.

    Scope lowering is a property of one ahead-of-time native build (the
    kernel's), not of the process. While it is on, the selfhost resolver
    hands NATIVE_SCOPE modules to the target program instead of the
    compiler's own, so in a sealed image, where those are two different
    trees, a compile that outlives the build sees the frontend twice:
    `Source` from the checkout and `Source` from the shipped compiler, and
    the checker reports "Cannot assign Source to parameter of type Source".
    The outermost compile that armed it disarms it on exit.
    """;
    _SCOPE_ACTIVE.clear();
}

def native_scope_path_suffixes -> list[str] {
    if not _SCOPE_SUFFIX_CACHE {
        for e in NATIVE_SCOPE {
            rel = e.module.replace("jaclang.", "", 1).replace(".", "/") + ".jac";
            _SCOPE_SUFFIX_CACHE.append("jaclang/" + rel);
        }
    }
    return _SCOPE_SUFFIX_CACHE;
}

def in_native_scope_path(mod_path: str) -> bool {
    if not mod_path {
        return False;
    }
    p = mod_path.replace(os.sep, "/");
    for suf in native_scope_path_suffixes() {
        if p.endswith(suf) {
            return True;
        }
    }
    return False;
}
