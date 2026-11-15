obj InspectFinding {
    has kind: str,
        detail: str;
}


obj InvalidationExplanation {
    has node_id: str,
        origin: str,
        layout_root_id: str,
        damage_reason: str;
}


def _node_label(n: UiNode) -> str;


def _node_sort_key(n: UiNode) -> str;


def _binding_line_key(binding: Binding) -> str;


def _walk_nodes(session: UiSession) -> list[UiNode];


def dump_graph(session: UiSession) -> str;


def dump_session_bindings(session: UiSession) -> str;


def dump_event_path(
    session: UiSession, event: any, target: UiNode | None = None,
) -> str;


def explain_invalidation(session: UiSession, n: UiNode,) -> InvalidationExplanation;


def dump_layout(session: UiSession, n: UiNode) -> str;


def dump_damage(session: UiSession, frame: any = None) -> str;


def dump_lifetimes(session: UiSession, n: UiNode) -> str;


def _detect_cycles(session: UiSession) -> list[InspectFinding];


def _detect_duplicate_keys(session: UiSession) -> list[InspectFinding];


def _detect_invalid_ranks(session: UiSession) -> list[InspectFinding];


def validate_invariants(session: UiSession) -> list[InspectFinding];
