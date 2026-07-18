import ast as py_ast;
import os;

import from pathlib { Path }
import from jaclang.jac0core.modresolver { resolve_module }

impl wheel_module_name(wheel_path: str) -> str {
    path = wheel_path;
    if path.endswith(".py") {
        path = path[:-len(".py")];
    }
    parts = [
        p
        for p in path.split("/")
        if p
    ];
    if parts and (parts[-1] == "__init__") {
        parts = parts[:-1];
    }
    return ".".join(parts);
}

def _lookup(target: str, base_path: str, module_map: dict[str, str]) -> str | None {
    try {
        (resolved, _lang) = resolve_module(target, base_path);
    } except Exception {
        return None;
    }
    return module_map.get(os.path.normpath(os.path.abspath(str(resolved))));
}

def _parent_and_leaf(dotted: str) -> tuple[str, str] {
    if "." in dotted {
        (parent, leaf) = dotted.rsplit(".", 1);
        return (parent, leaf);
    }
    return ("", dotted);
}

def _rewrite_plain_import(alias: py_ast.alias, dotted: str) -> list[py_ast.stmt] {
    if alias.asname {
        return [py_ast.Import(names=[py_ast.alias(name=dotted, asname=alias.asname)])];
    }
    if "." not in alias.name {
        (parent, leaf) = _parent_and_leaf(dotted);
        if not parent {
            return [py_ast.Import(names=[py_ast.alias(name=dotted)])];
        }
        return [
            py_ast.ImportFrom(module=parent, names=[py_ast.alias(name=leaf)], level=0)
        ];
    }

    top = alias.name.split(".")[0];
    depth = len(alias.name.split("."));
    dotted_parts = dotted.split(".");
    bind_dotted = ".".join(dotted_parts[:len(dotted_parts) - depth + 1]);
    (bind_parent, bind_leaf) = _parent_and_leaf(bind_dotted);
    stmts: list[py_ast.stmt] = [
        py_ast.Import(names=[py_ast.alias(name=dotted, asname=f"_jac_sub_{top}")])
    ];
    if bind_parent {
        stmts.append(
            py_ast.ImportFrom(
                module=bind_parent,
                names=[py_ast.alias(name=bind_leaf, asname=top)],
                level=0
            )
        );
    }
    return stmts;
}

impl rewrite_imports(
    py_source: str, source_path: Path, module_map: dict[str, str],
) -> str {
    base_path = str(source_path);
    tree = py_ast.parse(py_source);
    replacements: list[tuple[int, int, str]] = [];

    for node in py_ast.walk(tree) {
        new_stmts: list[py_ast.stmt] = [];
        if isinstance(node, py_ast.ImportFrom) {
            if (node.level != 0) or (not node.module) {
                continue;
            }
            dotted = _lookup(str(node.module), base_path, module_map);
            if (dotted is None) or (dotted == node.module) {
                continue;
            }
            new_stmts = [py_ast.ImportFrom(module=dotted, names=node.names, level=0)];
        } elif isinstance(node, py_ast.Import) {
            targets = [
                (alias, _lookup(alias.name, base_path, module_map))
                for alias in node.names
            ];
            if all(
                (dotted is None) or (dotted == alias.name)
                for (alias, dotted) in targets
            ) {
                continue;
            }
            for (alias, dotted) in targets {
                if (dotted is None) or (dotted == alias.name) {
                    new_stmts.append(py_ast.Import(names=[alias]));
                } else {
                    new_stmts.extend(_rewrite_plain_import(alias, dotted));
                }
            }
        } else {
            continue;
        }
        indent = " " * node.col_offset;
        text = "\n".join(
            indent + py_ast.unparse(py_ast.fix_missing_locations(stmt))
            for stmt in new_stmts
        );
        replacements.append((node.lineno, int(node.end_lineno or node.lineno), text));
    }

    if not replacements {
        return py_source;
    }

    lines = py_source.splitlines();
    for (start, end, text) in sorted(replacements, reverse=True) {
        lines[start - 1:end] = text.splitlines();
    }
    out = "\n".join(lines);
    if py_source.endswith("\n") and not out.endswith("\n") {
        out += "\n";
    }
    return out;
}
