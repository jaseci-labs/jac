obj _ScopedNode {
    has target: UiNode,
        id_str: str = "",
        key: str = "",
        parent_id: str = "",
        rank: int = 0,
        is_overlay: bool = False,
        z_index: int = 0;
}


obj _Scope {
    has order: list[_ScopedNode] = [],
        parent_of: dict[str, str] = {},
        error: LayoutDiagnostic | None = None;
}


def _topology_error(message: str) -> LayoutDiagnostic;


def _z_index_of(screen: Screen, overlay: Overlay) -> int;


def _scoped_jid_key(pair: _ScopedNode) -> str;


def _scoped_z_key(pair: _ScopedNode) -> int;


def _collect_overlays(layout_root: UiNode, seen: dict[str, bool]) -> list[_ScopedNode];


def _walk_children(
    parent_target: UiContainer,
    parent_id: str,
    in_flow_walk: bool,
    overlay_ids: dict[str, bool],
    seen: dict[str, bool],
    scope: _Scope,
    queue: list[_ScopedNode],
) -> bool;


def _collect_scope(layout_root: UiNode) -> _Scope;

impl _topology_error(message: str) -> LayoutDiagnostic {
    return LayoutDiagnostic(
        code=LayoutError.INVALID_TOPOLOGY,
        severity=LayoutSeverity.ERROR,
        message=message,
    );
}


impl _z_index_of(screen: Screen, overlay: Overlay) -> int {
    for edge in [edge screen->:Layer:->overlay] {
        return int(edge.z_index);
    }
    return 0;
}


impl _scoped_jid_key(pair: _ScopedNode) -> str {
    return pair.id_str;
}


impl _scoped_z_key(pair: _ScopedNode) -> int {
    return pair.z_index;
}


impl _collect_overlays(
    layout_root: UiNode, seen: dict[str, bool]
) -> list[_ScopedNode] {
    found: list[_ScopedNode] = [];
    if not isinstance(layout_root, Screen) {
        return found;
    }
    for ov in [layout_root->:Layer:->] {
        oid = node_id(ov);
        if oid in seen {
            continue;
        }
        seen[oid] = True;
        found.append(
            _ScopedNode(
                target=ov,
                id_str=oid,
                key=str(ov.key),
                is_overlay=True,
                z_index=_z_index_of(layout_root, ov),
            )
        );
    }
    found.sort(key=_scoped_jid_key);
    found.sort(key=_scoped_z_key);
    return found;
}


impl _walk_children(
    parent_target: UiContainer,
    parent_id: str,
    in_flow_walk: bool,
    overlay_ids: dict[str, bool],
    seen: dict[str, bool],
    scope: _Scope,
    queue: list[_ScopedNode],
) -> bool {
    for child in ordered_children(parent_target) {
        cid = node_id(child);
        if cid in overlay_ids {
            if in_flow_walk {
                continue;
            }

            scope.error = _topology_error(
                "Layer overlay nested under another overlay: " + cid
            );
            return False;
        }
        if cid in seen {
            scope.error = _topology_error(
                "node visited twice in one scope (cycle or diamond): " + cid
            );
            return False;
        }
        seen[cid] = True;
        rank_val = 0;
        for edge in [edge parent_target->:Child:->child] {
            rank_val = int(edge.rank);
            break;
        }
        scoped = _ScopedNode(
            target=child,
            id_str=cid,
            key=str(child.key),
            parent_id=parent_id,
            rank=rank_val,
        );
        scope.order.append(scoped);
        scope.parent_of[cid] = parent_id;
        queue.append(scoped);
    }
    return True;
}


impl _collect_scope(layout_root: UiNode) -> _Scope {
    scope = _Scope();
    seen: dict[str, bool] = {};
    overlay_ids: dict[str, bool] = {};

    overlays = _collect_overlays(layout_root, seen);
    for scoped in overlays {
        overlay_ids[scoped.id_str] = True;

        scope.order.append(scoped);
    }

    root_id = node_id(layout_root);
    seen[root_id] = True;
    root_scoped = _ScopedNode(target=layout_root, id_str=root_id, key=layout_root.key);
    scope.order.append(root_scoped);

    queue: list[_ScopedNode] = [root_scoped];
    while len(queue) {
        current = queue.pop(0);
        if len([current.target<-:Child:<-]) > 1 {
            scope.error = _topology_error(
                "node has multiple Child parents: " + current.id_str
            );
            return scope;
        }
        if isinstance(current.target, UiContainer) {
            ok = _walk_children(
                current.target, current.id_str, True, overlay_ids, seen, scope, queue,
            );
            if not ok {
                return scope;
            }
        }
    }

    queue = overlays;
    while len(queue) {
        current = queue.pop(0);
        if isinstance(current.target, UiContainer) {
            ok = _walk_children(
                current.target, current.id_str, False, overlay_ids, seen, scope, queue,
            );
            if not ok {
                return scope;
            }
        }
    }
    return scope;
}
