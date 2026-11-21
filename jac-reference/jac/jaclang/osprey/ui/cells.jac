obj StyleAttrs {
    has fg: int | None = None,
        bg: int | None = None,
        bold: bool = False,
        dim: bool = False,
        italic: bool = False,
        underline: bool = False,
        reverse: bool = False;
}


obj StyledCell {
    has ch: str = " ",
        attrs: StyleAttrs = StyleAttrs(),
        wide_cont: bool = False;
}


obj CellBuffer {
    has columns: int = 80,
        rows: int = 24,
        cells: list[list[StyledCell]] = [];
}


obj CellDiff {
    has text: str = "",
        cells_written: int = 0;
}


def blank_cell -> StyledCell;


def attrs_eq(a: StyleAttrs, b: StyleAttrs) -> bool;


def cell_eq(a: StyledCell, b: StyledCell) -> bool;


def copy_attrs(a: StyleAttrs) -> StyleAttrs;


def copy_cell(c: StyledCell) -> StyledCell;


def sgr_reset -> str;


def sgr_for(attrs: StyleAttrs) -> str;


def create_buffer(columns: int, rows: int) -> CellBuffer;


def buffer_get(buf: CellBuffer, row: int, col: int) -> StyledCell;


def buffer_clear_rect(
    buf: CellBuffer,
    x: int,
    y: int,
    width: int,
    height: int,
    attrs: StyleAttrs | None = None,
);


def buffer_blit_text(
    buf: CellBuffer,
    row: int,
    col: int,
    text: str,
    attrs: StyleAttrs | None = None,
    max_width: int = -1,
);


obj TextSpan {
    has text: str = "",
        attrs: StyleAttrs | None = None;
}


def buffer_blit_spans(
    buf: CellBuffer, row: int, col: int, spans: list[TextSpan], max_width: int = -1,
);


def buffer_to_plain_rows(buf: CellBuffer) -> list[str];


def buffer_from_plain_rows(rows: list[str], columns: int, rows_n: int) -> CellBuffer;


def _rect_bounds(rect: Rect, columns: int, rows_n: int) -> tuple[int, int, int, int];


def diff_buffers_ansi(
    previous: CellBuffer | None,
    desired: CellBuffer,
    patch_rects: list[Rect],
    force: bool = False,
) -> CellDiff;
