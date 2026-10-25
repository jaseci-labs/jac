def fill_axis -> AxisSize;


def fixed_axis(n: float) -> AxisSize;


def grow_axis(weight: float) -> AxisSize;


def intrinsic_axis -> AxisSize;


def _error(
    code: LayoutError, message: str, node_ids: list[str] = []
) -> MutationResult;


def _ok -> MutationResult;


def create_layout_state(columns: int = 80, rows: int = 24) -> LayoutState;


def _validate_axis_size(
    axis_name: str, size: AxisSize, node_id_str: str
) -> list[LayoutDiagnostic];


def _kind_label(kind: LayoutRelationKind) -> str;


def _axis_label(axis: Axis) -> str;


def validate_spec(spec: LayoutSpec, node_id_str: str = "") -> list[LayoutDiagnostic];


def set_spec(state: LayoutState, target: UiNode, spec: LayoutSpec) -> MutationResult;


def _validate_relation_shape(rel: LayoutRelation) -> LayoutDiagnostic | None;


def add_relation(state: LayoutState, relation: LayoutRelation) -> MutationResult;


def remove_relation(state: LayoutState, handle: RelationHandle) -> MutationResult;


def set_content(
    state: LayoutState,
    target: UiNode,
    lines: list[str],
    content_revision: int,
    style_revision: int = 0,
) -> MutationResult;


def set_scroll_offset(
    state: LayoutState, target: UiNode, requested_offset: int
) -> MutationResult;


def clear_node(state: LayoutState, target: UiNode) -> MutationResult;


def frame_entry_of(state: LayoutState, target: UiNode) -> FrameEntry | None;


def rect_of(state: LayoutState, target: UiNode) -> Rect | None;


def _copy_rect(r: Rect) -> Rect;
