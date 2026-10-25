def _fail(diagnostics: list[LayoutDiagnostic]) -> LayoutResult;


def _overflow_warning(node_ids: list[str]) -> LayoutDiagnostic;


def _child_ids(scope_order: list[_ScopedNode], parent_id: str) -> list[str];


def _place_axis(
    result: CompileResult,
    values: dict[int, float],
    order: list[_ScopedNode],
    parent_id: str,
    p_start: int,
    p_end: int,
    infos: dict[str, PartitionInfo],
    starts: dict[str, int],
    ends: dict[str, int],
    warnings: list[LayoutDiagnostic],
    horizontal: bool,
) -> None;


def _structural_naturals(
    order: list[_ScopedNode], state: LayoutState, wrap_widths: dict[str, int],
) -> dict[str, Size];


def compute_layout(
    state: LayoutState, layout_root: UiNode, viewport: Viewport,
) -> LayoutResult;
