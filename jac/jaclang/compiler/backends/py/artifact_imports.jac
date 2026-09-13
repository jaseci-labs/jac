import dis;
import os;
import types;
import from pathlib { Path }
import from jaclang.project.modresolver { resolve_local_module }

def runtime_sources(code: types.CodeType, source: str, `root: str) -> set[str] {
    sources: set[str] = `set();
    pending = [code];
    while pending {
        unit = pending.pop();
        pending.extend(
            c
            for c in unit.co_consts
            if isinstance(c, types.CodeType)
        );

        instructions = [
            instruction
            for instruction in dis.get_instructions(unit)
            if instruction.opname != 'EXTENDED_ARG'
        ];
        for (index, instruction) in enumerate(instructions) {
            if ((instruction.opname != 'IMPORT_NAME') or (index < 2)) {
                continue;
            }
            level = instructions[(index - 2)].argval;
            names = instructions[(index - 1)].argval;
            if not isinstance(level, int) {
                raise RuntimeError(
                    f'Nonconstant import level in prepared module {source}'
                );
            }
            name = instruction.argval;
            base = Path(source).parent;
            if level {
                for _ in range((level - 1)) {
                    base = base.parent;
                }
                roots = [base];
            } else {
                roots = `list(`dict.fromkeys([base, Path(`root)]));
            }
            for search_root in roots {
                target = search_root.joinpath(*name.split('.'))
                    if name
                    else search_root;
                resolved = resolve_local_module(
                    str(search_root), name.split('.') if name else []
                );
                if resolved and resolved[1] in ('jac', 'py') {
                    sources.add(os.path.realpath(resolved[0]));
                } elif not target.is_dir() {
                    continue;
                }
                if target.is_dir() and isinstance(names, tuple) {
                    for member in names {
                        child = resolve_local_module(str(target), [member]);
                        if child and child[1] in ('jac', 'py') {
                            sources.add(os.path.realpath(child[0]));
                        }
                    }
                }
                sources.update(
                    package_sources(
                        str(target / '__init__') if target.is_dir() else str(target),
                        str(search_root)
                    )
                );
                break;
            }
        }
    }
    return sources;
}

def package_sources(source: str, project_root: str) -> set[str] {
    result: set[str] = set();
    parent = Path(source).parent;
    while parent.is_relative_to(project_root) {
        initializer = resolve_local_module(str(parent), []);
        if initializer and initializer[1] in ('jac', 'py') {
            result.add(os.path.realpath(initializer[0]));
        }
        if parent == Path(project_root) {
            break;
        }
        parent = parent.parent;
    }
    return result;
}
