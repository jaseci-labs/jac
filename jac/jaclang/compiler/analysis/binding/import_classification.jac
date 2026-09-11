import from jaclang.compiler.session.import_paths { resolve_import_path }
import os;
import from jaclang.compiler.ir.schema {
    Import,
    ModulePath,
    ModuleItem,
    Module,
    Name,
    NameAtom
}

def detect_jac_import(imp: Import) -> bool {
    if imp.hint is not None {
        return imp.hint.tag.value == 'jac';
    }

    import os;

    import from jaclang.jac0core.ext_registry { is_jac, INIT_FILES }
    if imp.from_loc {
        if is_jac(resolve_import_path(imp.from_loc)) {
            return True;
        }
        if os.path.isdir(resolve_import_path(imp.from_loc)) {
            for init_name in INIT_FILES {
                if os.path.exists(
                    os.path.join(resolve_import_path(imp.from_loc), init_name)
                ) {
                    return True;
                }
            }
            for i in imp.items {
                if (
                    isinstance(i, ModuleItem)
                    and is_jac(resolve_import_path(imp.from_loc, i.name.value))
                ) {
                    return True;
                }
            }
        }
    }
    return `any(
        (isinstance(i, ModulePath) and is_jac(resolve_import_path(i)))
        for i in imp.items
    );
}
