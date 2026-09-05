"""The kernel's unit roster.

`NATIVE_SCOPE` names the frontend modules the compiler runs as bytecode and
the kernel links as native units. Whether a compile treats them as native is
`CompileOptions.native_unit` (see `placement_facts.native_unit`); this module
only answers the roster question.
"""
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

     );

"""The kernel's link root: the unit whose `jc_*` exports are the C ABI the
loader binds."""
glob KERNEL_ROOT_MODULE: str = "jaclang.compiler.jc_unit";

glob _SCOPE_SUFFIX_CACHE: list = [];

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

def scope_module_path(module: str) -> str {
    import from jaclang.compiler.frontend.codeinfo { jaclang_pkg_root }
    rel = module.replace("jaclang.", "", 1).replace(".", os.sep) + ".jac";
    return os.path.join(jaclang_pkg_root(), rel);
}

"""The source path of every unit in the roster, kernel root last."""
def native_scope_paths -> list[str] {
    return [scope_module_path(e.module) for e in NATIVE_SCOPE];
}

def kernel_root_path -> str {
    return scope_module_path(KERNEL_ROOT_MODULE);
}
