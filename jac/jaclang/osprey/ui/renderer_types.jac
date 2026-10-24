obj DamageRect {
    has rect: Rect = Rect(),
        reason: str = "";
}


obj FrameResult {
    has damage: list[DamageRect] = [],
        cells_written: int = 0,
        used_full_clear: bool = False,
        patch_rects: list[Rect] = [],
        cursor_row: int = -1,
        cursor_col: int = -1,
        cursor_visible: bool = False,
        sync_wrapped: bool = False;
}


obj AnsiDiff {
    has text: str = "",
        cells_written: int = 0;
}


obj _OverlayHit {
    has nd: UiNode,
        z: int = 0,
        id_str: str = "";
}


obj CursorPos {
    has row: int = -1,
        col: int = -1;
}


obj Renderer {
    has layout: LayoutState,
        previous: CellBuffer | None = None,
        prev_rects: dict[str, Rect] = {},
        damage: list[DamageRect] = [],
        cursor_node_id: str = "",
        cursor_row_offset: int = 0,
        cursor_col_offset: int = 0,
        last_cursor_row: int = -1,
        last_cursor_col: int = -1,
        last_cursor_visible: bool = False,
        graph_revision: int = 0,
        content_revisions: dict[str, int] = {},
        pending_semantic: set[str] = set(),
        pending_layout: set[str] = set(),
        last_frame_columns: int = 0,
        last_frame_rows: int = 0,
        styled: dict[str, list[list[TextSpan]]] = {},
        fills: dict[str, StyleAttrs] = {};
}
