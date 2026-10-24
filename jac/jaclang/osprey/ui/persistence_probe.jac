def ui_jids_reachable_from_persistent_root(ui_jids: set[str]) -> list[str];

impl ui_jids_reachable_from_persistent_root(ui_jids: set[str]) -> list[str] {
    found: list[str] = [];
    visited: set[str] = set();

    queue: list[any] = [];
    queue.append(root);
    while queue {
        current = queue.pop(0);
        current_jid = jid(current);
        if current_jid in ui_jids {
            found.append(current_jid);
        }
        for neighbor in [current-->] {
            nj = jid(neighbor);
            if nj not in visited {
                visited.add(nj);
                queue.append(neighbor);
            }
        }
        for neighbor in [current<--] {
            nj = jid(neighbor);
            if nj not in visited {
                visited.add(nj);
                queue.append(neighbor);
            }
        }
    }
    return found;
}
