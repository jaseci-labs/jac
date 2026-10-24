obj Rect {
    has x: int = 0,
        y: int = 0,
        width: int = 0,
        height: int = 0;

    def right -> int;
    def bottom -> int;
    def is_empty -> bool;
    def contains_point(col: int, row: int) -> bool;
    def intersects(other: Rect) -> bool;
    def copy -> Rect;
}


obj Size {
    has width: int = 0,
        height: int = 0;
}


def rect_union(a: Rect, b: Rect) -> Rect;


enum Axis { HORIZONTAL = "horizontal", VERTICAL = "vertical" }
enum SizeMode {
    FIXED = "fixed",
    INTRINSIC = "intrinsic",
    BOUNDED = "bounded",
    FILL = "fill",
    GROW = "grow"
}

enum Align { START = "start", CENTER = "center", END = "end", STRETCH = "stretch" }
enum OverlayAnchor {
    CENTER = "center",
    TOP = "top",
    BOTTOM = "bottom",
    LEFT = "left",
    RIGHT = "right"
}


obj AxisSize {
    has mode: SizeMode,
        minimum: float = 0.0,
        preferred: float | None = None,
        maximum: float | None = None,
        grow_weight: float = 0.0;
}


obj LayoutSpec {
    has width: AxisSize,
        height: AxisSize,
        flow_axis: Axis = Axis.VERTICAL,
        cross_align: Align = Align.STRETCH,
        scroll_vertical: bool = False,
        overlay_anchor: OverlayAnchor | None = None;
}


enum LayoutSeverity { WARNING = "warning", ERROR = "error" }
enum LayoutError {
    INVALID_SPEC = "invalid_spec",
    INVALID_RELATION = "invalid_relation",
    STALE_NODE = "stale_node",
    OUT_OF_SCOPE = "out_of_scope",
    INVALID_TOPOLOGY = "invalid_topology",
    UNSATISFIABLE = "unsatisfiable",
    OVERFLOW = "overflow",
    UNSUPPORTED_AXIS_COUPLING = "unsupported_axis_coupling",
    INTERNAL_INVARIANT = "internal_invariant"
}


obj Viewport {
    has columns: int,
        rows: int;
}


obj RelationHandle {
    has id: int;
}


obj LayoutDiagnostic {
    has code: LayoutError,
        severity: LayoutSeverity,
        message: str,
        node_ids: list[str] = [],
        provenance: list[str] = [];
}


obj FrameEntry {
    has measured: Size,
        rect: Rect,
        clip: Rect,
        wrapped_lines: list[str],
        requested_scroll_offset: int = 0,
        scroll_offset: int = 0,
        max_scroll_offset: int = 0;
}


obj LayoutFrame {
    has generation: int,
        viewport: Viewport,
        entries: dict[str, FrameEntry],
        overlay_ids: list[str];
}


obj MutationResult {
    has ok: bool,
        relation_handle: RelationHandle | None = None,
        diagnostics: list[LayoutDiagnostic] = [];
}


obj LayoutResult {
    has ok: bool,
        frame: LayoutFrame | None = None,
        diagnostics: list[LayoutDiagnostic] = [];
}


enum LayoutRelationKind {
    LEFT_OF = "left_of",
    RIGHT_OF = "right_of",
    ABOVE = "above",
    BELOW = "below",
    ALIGN_START = "align_start",
    ALIGN_END = "align_end",
    ALIGN_CENTER = "align_center",
    SAME_SIZE = "same_size"
}


obj LayoutRelation {
    has owner_id: str,
        source_id: str,
        target_id: str,
        kind: LayoutRelationKind,
        axis: Axis,
        provenance: str,
        gap: float = 0.0,
        strength: StrengthTier = StrengthTier.REQUIRED;
}


obj ContentEntry {
    has lines: list[str],
        content_revision: int,
        style_revision: int;
}


obj MeasureEntry {
    has width: int,
        content_revision: int,
        style_revision: int,
        lines: list[str];
}


obj LayoutState {
    has viewport: Viewport = Viewport(columns=80, rows=24),
        specs: dict[str, LayoutSpec] = {},
        content: dict[str, ContentEntry] = {},
        relations: dict[int, LayoutRelation] = {},
        next_relation_id: int = 1,
        measurement_cache: dict[str, MeasureEntry] = {},
        scroll_requests: dict[str, int] = {},
        last_frame: LayoutFrame | None = None;
}

impl Rect.right -> int {
    return self.x + self.width;
}

impl Rect.bottom -> int {
    return self.y + self.height;
}

impl Rect.is_empty -> bool {
    return self.width <= 0 or self.height <= 0;
}

impl Rect.contains_point(col: int, row: int) -> bool {
    return (
        col >= self.x and col < self.right() and row >= self.y and row < self.bottom()
    );
}

impl Rect.intersects(other: Rect) -> bool {
    if self.is_empty() or other.is_empty() {
        return False;
    }
    return (
        self.x < other.right()
        and self.right() > other.x
        and self.y < other.bottom()
        and self.bottom() > other.y
    );
}

impl Rect.copy -> Rect {
    return Rect(x=self.x, y=self.y, width=self.width, height=self.height,);
}


impl rect_union(a: Rect, b: Rect) -> Rect {
    if a.is_empty() {
        return b.copy();
    }
    if b.is_empty() {
        return a.copy();
    }
    x0 = min(a.x, b.x);
    y0 = min(a.y, b.y);
    x1 = max(a.right(), b.right());
    y1 = max(a.bottom(), b.bottom());
    return Rect(x=x0, y=y0, width=x1 - x0, height=y1 - y0);
}
