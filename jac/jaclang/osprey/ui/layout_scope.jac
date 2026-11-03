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
