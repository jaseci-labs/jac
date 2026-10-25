def _rects_equal(a: Rect, b: Rect) -> bool;


def _walk_damage(renderer: Renderer, n: UiNode, out: list[DamageRect],);


def compute_damage(renderer: Renderer, layout_root: UiNode) -> list[DamageRect];


def _merge_damage(damage: list[DamageRect]) -> list[Rect];


def _diff_ansi(
    previous: CellBuffer | None,
    desired: CellBuffer,
    patch_rects: list[Rect],
    columns: int,
    rows_n: int,
    force: bool = False,
) -> AnsiDiff;


def _resolve_cursor(renderer: Renderer) -> CursorPos;


def _run_layout(renderer: Renderer, layout_root: UiNode) -> LayoutResult;


def _snapshot_rects(renderer: Renderer);
