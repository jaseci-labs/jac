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
