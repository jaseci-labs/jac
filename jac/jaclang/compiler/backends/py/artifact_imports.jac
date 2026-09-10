import dis;
import os;
import types;
import from pathlib { Path }
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
        instructions = `list(dis.get_instructions(unit));
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
                module = target.with_suffix('.jac');
                package = target / '__init__.jac';
                if module.is_file() {
                    sources.add(os.path.realpath(module));
                } elif target.is_dir() {
                    if package.is_file() {
                        sources.add(os.path.realpath(package));
                    }
                    if isinstance(names, `tuple) {
                        for member in names {
                            child = target / (member + '.jac');
                            child_package = target / member / '__init__.jac';
                            if child.is_file() {
                                sources.add(os.path.realpath(child));
                            } elif child_package.is_file() {
                                sources.add(os.path.realpath(child_package));
                            }
                        }
                    }
                } else {
                    continue;
                }
                parent = target.parent;
                while parent.is_relative_to(search_root) {
                    `init = parent / '__init__.jac';
                    if `init.is_file() {
                        sources.add(os.path.realpath(`init));
                    }
                    if (parent == search_root) {
                        break;
                    }
                    parent = parent.parent;
                }
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
        initializer = parent / '__init__.jac';
        if initializer.is_file() {
            result.add(os.path.realpath(initializer));
        }
        if parent == Path(project_root) {
            break;
        }
        parent = parent.parent;
    }
    return result;
}
