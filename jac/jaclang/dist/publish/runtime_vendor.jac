import ast as py_ast;
import json;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.driver.program { JacProgram }

def _pkg_root -> Path {
    import jaclang;
    return Path(str(jaclang.__file__)).parent;
}

def _module_to_file(pkg_root: Path, mod: str) -> Path | None {
    import from jaclang.project.modresolver { resolve_local_module }
    if not mod.startswith('jaclang.') {
        return None;
    }
    resolved = resolve_local_module(str(pkg_root.parent), mod.split('.'));
    return Path(resolved[0]) if resolved and resolved[1] in ('jac', 'py') else None;
}

def scan_jaclang_imports(
    py_src: str | py_ast.Module,
    module: str = '',
    package: bool = False,
    include_symbols: bool = True
) -> set[str] {
    import from importlib.util { resolve_name }
    found: set[str] = set();
    tree = py_ast.parse(py_src) if isinstance(py_src, str) else py_src;
    pending: list[py_ast.AST] = [tree];
    while pending {
        current = pending.pop();
        if isinstance(current, py_ast.If) {
            condition = current.`test;
            checking = isinstance(condition, py_ast.Name)
                and condition.id == 'TYPE_CHECKING'
                or isinstance(condition, py_ast.Attribute)
                and condition.attr == 'TYPE_CHECKING';
            if checking {
                pending.extend(current.orelse);
                continue;
            }
        }
        if isinstance(current, py_ast.Import) {
            found.update(
                alias.name
                for alias in current.names
                if alias.name.startswith('jaclang.')
            );
        } elif isinstance(current, py_ast.ImportFrom) {
            base = current.module or '';
            if current.level {
                namespace = module if package else module.rpartition('.')[0];
                if not namespace {
                    continue;
                }
                base = resolve_name('.' * current.level + base, namespace);
            }
            if base == 'jaclang' or base.startswith('jaclang.') {
                found.add(base);
                if include_symbols {
                    found.update(
                        base + '.' + alias.name
                        for alias in current.names
                        if alias.name != '*'
                    );
                }
            }
        }
        pending.extend(py_ast.iter_child_nodes(current));
    }
    return found;
}

def _runtime_dependencies(
    pkg_root: Path, source: py_ast.Module, module: str = '', package: bool = False
) -> set[str] {
    for required in scan_jaclang_imports(
        source, module, package, include_symbols=False
    ) {
        namespace = pkg_root.joinpath(*required.split('.')[1:]);
        if required != 'jaclang'
            and _module_to_file(pkg_root, required) is None
            and not namespace.is_dir() {
            raise ValueError(
                f'Runtime import does not resolve: {required} (imported by {module
                    or "application"})'
            );
        }
    }
    return scan_jaclang_imports(source, module, package);
}

def _declared_literal(tree: py_ast.Module, name: str) -> object {
    for statement in tree.body {
        if isinstance(statement, py_ast.Assign) {
            targets = statement.targets;
        } elif isinstance(statement, py_ast.AnnAssign) {
            targets = [statement.target];
        } else {
            continue;
        }
        if any(
            isinstance(target, py_ast.Name) and target.id == name for target in targets
        )
            and statement.value is not None {
            return py_ast.literal_eval(statement.value);
        }
    }
    return None;
}

def _compile_runtime_module(
    pkg_root: Path,
    path: Path,
    prog: JacProgram,
    native: dict[str, any] | None = None,
    native_sources: bool = True
) -> str {
    if path.suffix == ".py" {
        return path.read_text(encoding="utf-8");
    }
    import from jaclang.bootstrap_manifest { is_seed_source }
    rel_posix = path.relative_to(pkg_root).as_posix();
    if is_seed_source(rel_posix) {
        import from jaclang.jac0 { compile_jac, discover_impl_files }
        jac_source = path.read_text(encoding="utf-8");
        impl_sources: list[tuple[str, str]] = [];
        for impl_path in discover_impl_files(str(path)) {
            impl_sources.append(
                (Path(impl_path).read_text(encoding="utf-8"), impl_path)
            );
        }
        return compile_jac(jac_source, str(path), impl_sources=impl_sources or None);
    }
    import from jaclang.compiler.driver.source_products { python_source }
    (py_out, ir) = python_source(str(path), prog);
    if native is not None and ir is not None and ir.gen.native_engine is not None {
        import from jaclang.dist.native_product { write_native_product }
        with tempfile.TemporaryDirectory(prefix='jac-runtime-native-') as temporary {
            directory = Path(temporary);
            record = write_native_product(
                ir,
                directory,
                Path('native') / path.relative_to(pkg_root).with_suffix('.py'),
                emit_source=native_sources
            );
            native['record'] = record;
            native['path'] = record['source'] if native_sources else record['output'];
            native['content'] = (directory / native['path']).read_bytes();
        }
    }
    return py_out;
}


def build_runtime_closure(
    user_codes: list[str],
    include_byllm: bool = False,
    extra_seeds: list[str] | None = None,
    prepared: bool = True,
    native_sources: bool = True
) -> dict[str, bytes] {
    pkg_root = _pkg_root();
    requested = set(extra_seeds or []);
    if prepared {
        requested.add('jaclang.runtime.source_app');
    }
    if include_byllm {
        requested.add('jaclang.byllm.lib');
    }
    for name in requested {
        if _module_to_file(pkg_root, name) is None {
            raise ValueError(f'Runtime module does not resolve: {name}');
        }
    }
    pending = set(requested);
    for source in user_codes {
        pending.update(_runtime_dependencies(pkg_root, py_ast.parse(source)));
    }
    initializer = (pkg_root / '__init__.py').read_text(encoding='utf-8')
        if prepared
        else '';
    closure: dict[str, bytes] = {'__init__.py': initializer.encode('utf-8')};
    sources: dict[str, py_ast.Module] = {'jaclang': py_ast.parse(initializer)};
    pending.update(
        _runtime_dependencies(pkg_root, sources['jaclang'], 'jaclang', True)
    );
    processed: set[str] = {'jaclang'};
    program = JacProgram();
    modules: list[dict[str, any]] = [];
    while pending {
        module = min(pending);
        pending.remove(module);
        if module in processed {
            continue;
        }
        parts = module.split('.');
        parents = ['.'.join(parts[:i]) for i in range(2, len(parts))];
        missing = [
            parent
            for parent in parents
            if parent not in processed
        ];
        if missing {
            pending.update(missing);
            pending.add(module);
            continue;
        }
        processed.add(module);
        path = _module_to_file(pkg_root, module);
        if path is None {
            namespace = pkg_root.joinpath(*parts[1:]);
            if namespace.is_dir() {
                relative = '/'.join(parts[1:]) + '/__init__.py';
                closure[relative] = b'';
                continue;
            }
            (parent, _, name) = module.rpartition('.');
            declared = _declared_literal(sources[parent], '_LAZY_EXPORTS')
                if parent in sources
                else None;
            exports: dict[str, str] = {};
            if isinstance(declared, dict) {
                exports = declared;
            }
            if name in exports {
                pending.add(exports[name]);
            }
            continue;
        }
        native: dict[str, any] = {};
        source = _compile_runtime_module(
            pkg_root, path, program, native, native_sources
        );
        tree = py_ast.parse(source, filename=str(path));
        sources[module] = tree;
        relative = module.removeprefix('jaclang.').replace('.', '/');
        package = path.name.startswith('__init__.');
        relative += '/__init__.py' if package else '.py';
        closure[relative] = source.encode('utf-8');
        resources = _declared_literal(tree, '__jac_resources__');
        if resources is not None {
            if not isinstance(resources, list)
                or not all(isinstance(pattern, str) for pattern in resources) {
                raise ValueError(
                    f'{module}.__jac_resources__ must be a list of package-relative glob patterns'
                );
            }
            for pattern in resources {
                matches = [
                    item
                    for item in path.parent.glob(pattern)
                    if item.is_file()
                ];
                if not matches {
                    raise ValueError(
                        f'Resource declaration does not resolve: {module}: {pattern}'
                    );
                }
                for item in matches {
                    resolved = item.resolve();
                    if not resolved.is_relative_to(pkg_root.resolve()) {
                        raise ValueError(f'Resource escapes its package: {item}');
                    }
                    closure[item.relative_to(pkg_root).as_posix()] = item.read_bytes();
                }
            }
        }
        record = {'path': relative, 'origin': path.relative_to(pkg_root).as_posix()};
        if native {
            record['native'] = native['record'];
            closure[native['path']] = native['content'];
        }
        modules.append(record);
        pending.update(
            _runtime_dependencies(pkg_root, tree, module, package) - processed
        );
    }
    for relative in [
        name
        for name in closure
        if name.endswith('.py')
    ] {
        for parent in Path(relative).parents {
            if str(parent) != '.' {
                closure.setdefault((parent / '__init__.py').as_posix(), b'');
            }
        }
    }
    closure['runtime.json'] = json.dumps(
        {
            'name': 'jaclang',
            'namespace': 'jaclang',
            'scope_imports': False,
            'root': '.',
            'entry': '__init__.py',
            'modules': modules
        },
        indent=2
    ).encode(
        'utf-8'
    );
    return closure;
}

def vendor_runtime(
    backend_dir: Path,
    user_codes: list[str],
    include_byllm: bool = False,
    extra_seeds: list[str] | None = None,
    prepared: bool = True
) -> int {
    import from importlib.metadata { distribution }
    runtime_distribution = distribution('jaclang');
    metadata = runtime_distribution.read_text('METADATA');
    if metadata is None {
        raise RuntimeError('The Jac runtime distribution has no package metadata');
    }
    closure = build_runtime_closure(user_codes, include_byllm, extra_seeds, prepared);
    for (relative, source) in closure.items() {
        target = backend_dir / 'jaclang' / relative;
        target.parent.mkdir(parents=True, exist_ok=True);
        target.write_bytes(source);
    }
    metadata_dir = backend_dir / f'jaclang-{runtime_distribution.version}.dist-info';
    metadata_dir.mkdir(parents=True, exist_ok=True);
    (metadata_dir / 'METADATA').write_text(metadata, encoding='utf-8');
    return len(closure);
}
