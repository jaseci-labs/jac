obj RendererState {
    has layout: dict[str, dict[str, int]] = {},
        damage: list[dict[str, int]] = [],
        cursor_holder_id: str = "";
}


obj CapabilityRegistry {
    has by_node: dict[str, list[str]] = {};
}


obj InvalidationRecord {
    has node_id: str,
        layout_root_id: str,
        reason: str;
}


obj SessionEventRecord {
    has kind: str = "",
        payload: dict[str, int] = {};
}


obj UiSession {
    has bindings: BindingRegistry,
        renderer: RendererState,
        capabilities: CapabilityRegistry,
        ui_root: UiSessionRoot | None = None,
        current_screen: Screen | None = None,
        focus_id: str = "",
        saved_focus_id: str = "",
        graph_revision: int = 0,
        disposed: bool = False,
        invalidation_journal: list[InvalidationRecord] = [],
        event_queue: list[SessionEventRecord] = [],
        tracked_node_ids: set[str] = set();
}


obj SessionLeak {
    has kind: str,
        detail: str;
}


obj UiSessionHandle {
    has session: UiSession,
        ui_root_id: str;
}


def create_session -> UiSessionHandle;


def track_node(session: UiSession, n: UiNode);


def is_reachable_from_root(session: UiSession, n: UiNode) -> bool;


def assert_mutation_parent(session: UiSession, parent: UiContainer);


def append_child_session(
    session: UiSession, parent: UiContainer, child: UiNode,
) -> MutationResult;


def set_current_screen(session: UiSession, screen: Screen);


def set_focus(session: UiSession, n: UiNode | None);


def register_capability(session: UiSession, node_id_str: str, cap_name: str);


def release_capabilities(session: UiSession, node_id_str: str);


def record_invalidation(
    session: UiSession, node_id_str: str, layout_root_id: str, reason: str,
);


def _endpoint_tracked(session: UiSession, n: UiNode) -> bool;


def _collect_stale_edges(session: UiSession) -> list[str];


def validate_session(session: UiSession) -> list[SessionLeak];


def dispose_session(session: UiSession);


def get_focus_node(session: UiSession) -> UiNode | None;

impl create_session -> UiSessionHandle {
    ui_root = UiSessionRoot(key="session");
    session = UiSession(
        ui_root=ui_root,
        bindings=BindingRegistry(),
        renderer=RendererState(),
        capabilities=CapabilityRegistry(),
    );
    track_node(session, ui_root);
    return UiSessionHandle(session=session, ui_root_id=node_id(ui_root));
}


impl track_node(session: UiSession, n: UiNode) {
    session.tracked_node_ids.add(node_id(n));
}


impl is_reachable_from_root(session: UiSession, n: UiNode) -> bool {
    if session.disposed or session.ui_root is None {
        return False;
    }
    current: UiNode | None = n;
    while current is not None {
        if current is session.ui_root {
            return True;
        }
        parents = [current<-:Child:<-];
        if not parents {
            return False;
        }
        current = parents[0];
    }
    return False;
}


impl assert_mutation_parent(session: UiSession, parent: UiContainer) {
    if session.disposed {
        raise ValueError("UiSession is disposed");
    }
    if not is_reachable_from_root(session, parent) {
        raise ValueError(
            "Mutation parent is not reachable from UiSessionRoot: " + parent.key
        );
    }
}


impl append_child_session(
    session: UiSession, parent: UiContainer, child: UiNode,
) -> MutationResult {
    assert_mutation_parent(session, parent);
    result = append_child(parent, child);
    track_node(session, child);
    session.graph_revision += result.graph_revision;
    if result.layout_root_id {
        record_invalidation(
            session, node_id(child), result.layout_root_id, "append_child",
        );
    }
    return result;
}


impl set_current_screen(session: UiSession, screen: Screen) {
    session.current_screen = screen;
    track_node(session, screen);
}


impl set_focus(session: UiSession, n: UiNode | None) {
    if n is None {
        session.focus_id = "";
        return;
    }
    session.focus_id = node_id(n);
}


impl register_capability(session: UiSession, node_id_str: str, cap_name: str) {
    if node_id_str not in session.capabilities.by_node {
        session.capabilities.by_node[node_id_str] = [];
    }
    session.capabilities.by_node[node_id_str].append(cap_name);
}


impl release_capabilities(session: UiSession, node_id_str: str) {
    if node_id_str in session.capabilities.by_node {
        del session.capabilities.by_node[node_id_str];
    }
}


impl record_invalidation(
    session: UiSession, node_id_str: str, layout_root_id: str, reason: str,
) {
    session.invalidation_journal.append(
        InvalidationRecord(
            node_id=node_id_str, layout_root_id=layout_root_id, reason=reason,
        )
    );
}


impl _endpoint_tracked(session: UiSession, n: UiNode) -> bool {
    return node_id(n) in session.tracked_node_ids;
}


impl _collect_stale_edges(session: UiSession) -> list[str] {
    stale: list[str] = [];
    if session.ui_root is None {
        return stale;
    }
    stack: list[UiNode] = [session.ui_root];
    while stack {
        current = stack.pop();
        if isinstance(current, UiContainer) {
            for child in ordered_children(current) {
                if not _endpoint_tracked(session, child) {
                    stale.append("Child:" + node_id(current) + "->" + node_id(child));
                }
                stack.append(child);
            }
        }
        for target in [current->:Owns:->] {
            if not _endpoint_tracked(session, target) {
                stale.append("Owns:" + node_id(current) + "->" + node_id(target));
            }
        }
        for target in [current->:Feeds:->] {
            if not _endpoint_tracked(session, target) {
                stale.append("Feeds:" + node_id(current) + "->" + node_id(target));
            }
        }
        for target in [current->:FocusNext:->] {
            if not _endpoint_tracked(session, target) {
                stale.append("FocusNext:" + node_id(current) + "->" + node_id(target));
            }
        }
        for target in [current->:Layer:->] {
            if not _endpoint_tracked(session, target) {
                stale.append("Layer:" + node_id(current) + "->" + node_id(target));
            }
        }
    }
    return stale;
}


impl validate_session(session: UiSession) -> list[SessionLeak] {
    if session.disposed {
        return [];
    }
    leaks: list[SessionLeak] = [];
    for binding in find_orphan_bindings(session.bindings, session.tracked_node_ids,) {
        leaks.append(SessionLeak(kind="orphan_binding", detail=binding.target_id,));
    }
    if session.focus_id and session.focus_id not in session.tracked_node_ids {
        leaks.append(SessionLeak(kind="invalid_focus", detail=session.focus_id,));
    }
    for cap_node_id in session.capabilities.by_node {
        if cap_node_id not in session.tracked_node_ids {
            leaks.append(
                SessionLeak(kind="unreleased_capability", detail=cap_node_id,)
            );
        }
    }
    for layout_id in session.renderer.layout {
        if layout_id not in session.tracked_node_ids {
            leaks.append(SessionLeak(kind="stale_renderer_layout", detail=layout_id,));
        }
    }
    for edge_detail in _collect_stale_edges(session) {
        leaks.append(SessionLeak(kind="stale_edge", detail=edge_detail,));
    }
    return leaks;
}


impl dispose_session(session: UiSession) {
    if session.disposed {
        return;
    }
    session.disposed = True;
    clear_bindings(session.bindings);
    session.capabilities.by_node = {};
    session.renderer.layout = {};
    session.renderer.damage = [];
    session.renderer.cursor_holder_id = "";
    session.event_queue = [];
    session.invalidation_journal = [];
    session.focus_id = "";
    session.saved_focus_id = "";
    session.current_screen = None;
    if session.ui_root is not None {
        dispose_subtree(session.ui_root);
        session.ui_root = None;
    }
    session.tracked_node_ids.clear();
}


impl get_focus_node(session: UiSession) -> UiNode | None {
    if session.disposed or session.ui_root is None or not session.focus_id {
        return None;
    }
    if session.focus_id not in session.tracked_node_ids {
        return None;
    }
    return find_node_by_jid(session.ui_root, session.focus_id);
}
