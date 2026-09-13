"""Project the transitive runtime module closure using the normal compiler products."""

import ast as py_ast;
import json;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.driver.program { JacProgram }

glob _VENDORED_INIT: str = '''"""Application runtime exported from Jac."""
from pathlib import Path
from jaclang.runtime.source_app import load_runtime
load_runtime(Path(__file__).parent)
def __getattr__(name):
    if name in {"JacRuntime", "JacRuntimeInterface"}:
        from jaclang.runtime import runtime
        return getattr(runtime, name)
    raise AttributeError(name)
__all__ = ["JacRuntime", "JacRuntimeInterface"]
''';

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
    py_src: str, module: str = '', package: bool = False
) -> set[str] {
    import from importlib.util { resolve_name }
    found: set[str] = set();
    tree = py_ast.parse(py_src);
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
                found.update(
                    base + '.' + alias.name
                    for alias in current.names
                    if alias.name != '*'
                );
            }
        }
        pending.extend(py_ast.iter_child_nodes(current));
    }
    return found;
}

def _lazy_exports(source: str) -> dict[str, str] {
    for statement in py_ast.parse(source).body {
        if isinstance(statement, py_ast.Assign) {
            targets = statement.targets;
        } elif isinstance(statement, py_ast.AnnAssign) {
            targets = [statement.target];
        } else {
            continue;
        }
        if any(
            isinstance(target, py_ast.Name) and target.id == '_LAZY_EXPORTS'
            for target in targets
        ) {
            return dict(py_ast.literal_eval(statement.value));
        }
    }
    return {};
}

def _compile_runtime_module(
    pkg_root: Path, path: Path, prog: JacProgram, native: dict | None = None
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
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    ir = prog.compile(file_path=str(path), options=CompileOptions(need_full_ast=True));
    if prog.errors_had {
        details = "\n".join(f"  {err}" for err in prog.errors_had);
        raise ValueError(f"runtime vendor: {path.name} failed to compile:\n{details}");
    }
    if ir is None {
        raise ValueError(
            f"runtime vendor: {path.name}: compiler returned no module "
            "(and reported no errors)."
        );
    }
    py_out = str(ir.gen.py or "");
    if not py_out.strip() {
        raise ValueError(
            f"runtime vendor: {path.name}: compiler produced no Python output "
            "(and reported no errors)."
        );
    }
    if native is not None and ir.gen.native_engine is not None {
        import from jaclang.dist.source.native { write_native_library }
        with tempfile.TemporaryDirectory(prefix='jac-runtime-native-') as temporary {
            directory = Path(temporary);
            record = write_native_library(
                ir, directory, path.relative_to(pkg_root).with_suffix('.py')
            );
            native['record'] = record;
            native['source'] = (directory / record['source']).read_text(
                encoding='utf-8'
            );
        }
    }
    return py_out;
}


def build_runtime_closure(
    user_codes: list[str],
    include_byllm: bool = False,
    extra_seeds: list[str] | None = None
) -> dict[str, str] {
    pkg_root = _pkg_root();
    requested = set(extra_seeds or []);
    requested.add('jaclang.runtime.source_app');
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
        pending.update(scan_jaclang_imports(source));
    }
    closure: dict[str, str] = {'__init__.py': _VENDORED_INIT};
    sources: dict[str, str] = {};
    processed: set[str] = {'jaclang'};
    program = JacProgram();
    modules: list[dict] = [];
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
            (parent, _, name) = module.rpartition('.');
            exports = _lazy_exports(sources[parent]) if parent in sources else {};
            if name in exports {
                pending.add(exports[name]);
            }
            continue;
        }
        native: dict = {};
        source = _compile_runtime_module(pkg_root, path, program, native);
        py_ast.parse(source, filename=str(path));
        sources[module] = source;
        relative = module.removeprefix('jaclang.').replace('.', '/');
        package = path.name.startswith('__init__.');
        relative += '/__init__.py' if package else '.py';
        closure[relative] = source;
        record = {'path': relative, 'origin': path.relative_to(pkg_root).as_posix()};
        if native {
            record['native'] = native['record'];
            closure[native['record']['source']] = native['source'];
        }
        modules.append(record);
        pending.update(scan_jaclang_imports(source, module, package) - processed);
    }
    for relative in list(closure) {
        for parent in Path(relative).parents {
            if str(parent) != '.' {
                closure.setdefault((parent / '__init__.py').as_posix(), '');
            }
        }
    }
    closure['runtime.json'] = json.dumps(
        {
            'name': 'jaclang',
            'namespace': 'jaclang',
            'root': '.',
            'entry': '__init__.py',
            'modules': modules
        },
        indent=2
    );
    return closure;
}

def vendor_runtime(
    backend_dir: Path,
    user_codes: list[str],
    include_byllm: bool = False,
    extra_seeds: list[str] | None = None
) -> int {
    closure = build_runtime_closure(user_codes, include_byllm, extra_seeds);
    for (relative, source) in closure.items() {
        target = backend_dir / 'jaclang' / relative;
        target.parent.mkdir(parents=True, exist_ok=True);
        target.write_text(source, encoding='utf-8');
    }
    return len(closure);
}
