import os;
import from jaclang.compiler.ir.schema {
    Import,
    ModulePath,
    ModuleItem,
    Module,
    Name,
    NameAtom
}

def annex_base(module: Module) -> (str | None) {
    if module.stub_only {
        return None;
    }
    import from jaclang.compiler.session.cache.annexes { discover_base_file }
    return discover_base_file(module.loc.mod_path);
}


def resolve_module_path(path: ModulePath, target_item: (str | None) = None) -> str {
    import from jaclang.compiler.session.resolver { resolve_relative_path }
    bundled = native_bundled_path(path);
    if bundled is not None {
        return bundled;
    }
    spv = path.string_path_value;
    if spv is not None {
        return resolve_relative_path(spv, path.loc.mod_path, string_spec=True);
    }
    target = path.dot_path_str + (f".{target_item}" if target_item else '');
    return resolve_relative_path(target, path.loc.mod_path);
}


def native_bundled_path(path: ModulePath) -> (str | None) {
    import os;

    import os;
    import from jaclang.compiler.session.native_resolution {
        is_bundled_native_module,
        resolve_native_module
    }
    mod_path = path.loc.mod_path if path.loc else None;
    if not path.in_native_context() {
        return None;
    }
    if mod_path and mod_path.endswith(".pyi") {
        return None;
    }
    base = path.dot_path_str;
    if not is_bundled_native_module(base) {
        return None;
    }
    base_dir = os.path.dirname(mod_path) if mod_path else os.getcwd();
    (_src, full_path) = resolve_native_module(base, base_dir);
    return full_path;
}


def resolve_import_chain(path: ModulePath) -> list[str] {
    import os;

    parts = path.dot_path_str.split('.');
    if not parts {
        return [];
    }

    full_path = resolve_import_path(path);

    paths: list[str] = [''] * len(parts);
    paths[-1] = full_path;

    full_basename = os.path.basename(full_path);
    cur_dir = os.path.dirname(full_path);
    if full_basename.startswith('__init__') {
        cur_dir = os.path.dirname(cur_dir);
    }
    for i in range(len(parts) - 2, -1, -1) {
        init_found = False;
        for init_name in ('__init__.jac', '__init__.py', '__init__.pyi') {
            init_path = os.path.join(cur_dir, init_name);
            if os.path.isfile(init_path) {
                paths[i] = init_path;
                init_found = True;
                break;
            }
        }
        if not init_found {
            paths[i] = cur_dir;
        }
        cur_dir = os.path.dirname(cur_dir);
    }
    return paths;
}


def resolve_import_item(item: ModuleItem) -> str {
    item_name = item.name.value if isinstance(item.name, Name) else None;

    if item_name is None {
        return resolve_import_path(item.from_mod_path);
    }

    return resolve_import_path(item.from_mod_path, target_item=item_name);
}


def resolve_import_path(
    path: ModulePath | ModuleItem, target_item: str | None = None
) -> str {
    if isinstance(path, ModuleItem) {
        return resolve_import_item(path);
    }
    return resolve_module_path(path, target_item);
}
