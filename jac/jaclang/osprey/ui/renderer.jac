def create_renderer(columns: int = 80, rows: int = 24) -> Renderer;


def set_node_contract(renderer: Renderer, n: UiNode, spec: LayoutSpec);


def set_node_content(renderer: Renderer, n: UiNode, lines: list[str]);


def set_node_spans(
    renderer: Renderer,
    n: UiNode,
    rows: list[list[TextSpan]],
    fill: StyleAttrs | None = None,
);


def set_node_fill(renderer: Renderer, n: UiNode, fill: StyleAttrs | None);


def mark_semantic_dirty(renderer: Renderer, n: UiNode);


def mark_layout_dirty(renderer: Renderer, n: UiNode);


def request_cursor(
    renderer: Renderer, n: UiNode, row_offset: int = 0, col_offset: int = 0,
);


def clear_cursor(renderer: Renderer);


def detach_node(renderer: Renderer, n: UiNode);

def relayout(renderer: Renderer, layout_root: UiNode) -> LayoutResult;


def desired_cells(renderer: Renderer, layout_root: UiNode) -> list[str];


def render_frame(
    renderer: Renderer, layout_root: UiNode, term: Terminal,
) -> FrameResult;


def frame_used_full_clear(writes: list[str]) -> bool;


def damage_cell_count(damage: list[DamageRect]) -> int;
