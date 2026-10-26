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
