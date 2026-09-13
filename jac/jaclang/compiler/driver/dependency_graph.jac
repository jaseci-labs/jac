import jaclang.compiler.frontend.unitree as uni;

obj DepGraph {
    has dependents: dict[str, set[str]] = {},
        dependencies: dict[str, set[str]] = {},
        tracking: bool = False;

    def record(importer_path: str, target_path: str) -> None {
        if importer_path == target_path {
            return;
        }
        bucket = self.dependents.get(target_path);
        if bucket is None {
            bucket = set();
            self.dependents[target_path] = bucket;
        }
        bucket.add(importer_path);
        self.dependencies.setdefault(importer_path, set()).add(target_path);
    }

    def record_module(mod: uni.Module) -> None {
        import from pathlib { Path }
        if mod.loc is None {
            return;
        }
        mod_path = mod.loc.mod_path;
        if not mod_path.endswith(".jac") {
            return;
        }
        try {
            importer = str(Path(mod_path).resolve());
        } except Exception {
            return;
        }
        for imp in mod.get_all_sub_nodes(uni.Import) {
            paths: list[uni.ModulePath] = [];
            if imp.from_loc is not None {
                paths.append(imp.from_loc);
            } else {
                for item in imp.items {
                    if isinstance(item, uni.ModulePath) {
                        paths.append(item);
                    }
                }
            }
            for mp in paths {
                try {
                    target = str(Path(mp.resolve_relative_path()).resolve());
                } except Exception {
                    continue;
                }
                self.record(importer, target);
            }
        }
    }

    def transitive_dependents(target_path: str) -> set[str] {
        out: set[str] = set();
        frontier: list[str] = [target_path];
        while frontier {
            current = frontier.pop();
            for importer in self.dependents.get(current, set()) {
                if importer in out {
                    continue;
                }
                out.add(importer);
                frontier.append(importer);
            }
        }
        return out;
    }

    def transitive_dependencies(source_path: str) -> set[str] {
        found: set[str] = set();
        pending = [source_path];
        while pending {
            for dependency in self.dependencies.get(pending.pop(), set()) {
                if dependency not in found {
                    found.add(dependency);
                    pending.append(dependency);
                }
            }
        }
        return found;
    }

    def forget(resolved_path: str) {
        self.dependencies.pop(resolved_path, None);
        for bucket in self.dependents.values() {
            bucket.discard(resolved_path);
        }
    }

    def clear {
        self.dependents.clear();
        self.dependencies.clear();
    }
}

def dependency_groups(
    edges: dict[str, list[str]], roots: list[str]
) -> list[list[str]] {
    visited: set[str] = set();
    finished: list[str] = [];
    for start in sorted(set(roots)) {
        stack: list[tuple[str, bool]] = [(start, False)];
        while stack {
            (path, leaving) = stack.pop();
            if leaving {
                finished.append(path);
                continue;
            }
            if path in visited {
                continue;
            }
            visited.add(path);
            stack.append((path, True));
            for dep in sorted(set(edges.get(path, [])), reverse=True) {
                if dep not in visited {
                    stack.append((dep, False));
                }
            }
        }
    }
    consumers: dict[str, list[str]] = {p: [] for p in visited};
    for path in sorted(visited) {
        for dep in sorted(set(edges.get(path, []))) {
            consumers[dep].append(path);
        }
    }
    assigned: set[str] = set();
    groups: list[list[str]] = [];
    for path in reversed(finished) {
        if path in assigned {
            continue;
        }
        group: list[str] = [];
        pending: list[str] = [path];
        while pending {
            member = pending.pop();
            if member in assigned {
                continue;
            }
            assigned.add(member);
            group.append(member);
            pending.extend(consumers[member]);
        }
        groups.append(sorted(group));
    }
    return list(reversed(groups));
}
