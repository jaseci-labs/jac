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

impl blank_cell -> StyledCell {
    return StyledCell(ch=" ", attrs=StyleAttrs());
}


impl attrs_eq(a: StyleAttrs, b: StyleAttrs) -> bool {
    if a is b {
        return True;
    }
    return (
        a.fg == b.fg
        and a.bg == b.bg
        and a.bold == b.bold
        and a.dim == b.dim
        and a.italic == b.italic
        and a.underline == b.underline
        and a.reverse == b.reverse
    );
}


impl cell_eq(a: StyledCell, b: StyledCell) -> bool {
    if a is b {
        return True;
    }
    if a.wide_cont != b.wide_cont {
        return False;
    }
    if a.ch != b.ch {
        return False;
    }
    return attrs_eq(a.attrs, b.attrs);
}


impl copy_attrs(a: StyleAttrs) -> StyleAttrs {
    return StyleAttrs(
        fg=a.fg,
        bg=a.bg,
        bold=a.bold,
        dim=a.dim,
        italic=a.italic,
        underline=a.underline,
        reverse=a.reverse,
    );
}


impl copy_cell(c: StyledCell) -> StyledCell {
    return StyledCell(ch=c.ch, attrs=copy_attrs(c.attrs), wide_cont=c.wide_cont,);
}


impl sgr_reset -> str {
    return "\x1b[0m";
}


impl sgr_for(attrs: StyleAttrs) -> str {
    parts: list[str] = ["0"];
    if attrs.bold {
        parts.append("1");
    }
    if attrs.dim {
        parts.append("2");
    }
    if attrs.italic {
        parts.append("3");
    }
    if attrs.underline {
        parts.append("4");
    }
    if attrs.reverse {
        parts.append("7");
    }
    if attrs.fg is not None {
        fg = attrs.fg as int;
        if fg >= 0 and fg <= 7 {
            parts.append(str(30 + fg));
        } elif fg >= 8 and fg <= 15 {
            parts.append(str(90 + (fg - 8)));
        } elif fg >= 0 and fg <= 255 {
            parts.append("38;5;" + str(fg));
        }
    }
    if attrs.bg is not None {
        bg = attrs.bg as int;
        if bg >= 0 and bg <= 7 {
            parts.append(str(40 + bg));
        } elif bg >= 8 and bg <= 15 {
            parts.append(str(100 + (bg - 8)));
        } elif bg >= 0 and bg <= 255 {
            parts.append("48;5;" + str(bg));
        }
    }
    return "\x1b[" + ";".join(parts) + "m";
}


impl create_buffer(columns: int, rows: int) -> CellBuffer {
    cols = max(1, columns);
    rows_n = max(1, rows);
    grid: list[list[StyledCell]] = [];
    blank = blank_cell();
    for _r in range(rows_n) {
        grid.append([blank] * cols);
    }
    return CellBuffer(columns=cols, rows=rows_n, cells=grid);
}


impl buffer_get(buf: CellBuffer, row: int, col: int) -> StyledCell {
    if row < 0 or row >= buf.rows or col < 0 or col >= buf.columns {
        return blank_cell();
    }
    return buf.cells[row][col];
}


impl buffer_clear_rect(
    buf: CellBuffer,
    x: int,
    y: int,
    width: int,
    height: int,
    attrs: StyleAttrs | None = None,
) {
    cell = StyledCell(ch=" ", attrs=copy_attrs(attrs))
        if attrs is not None
        else blank_cell();
    y0 = max(0, y);
    y1 = min(buf.rows, y + height);
    x0 = max(0, x);
    x1 = min(buf.columns, x + width);
    if x1 <= x0 {
        return;
    }
    for r in range(y0, y1) {
        line = buf.cells[r];
        for c in range(x0, x1) {
            line[c] = cell;
        }
    }
}


impl buffer_blit_text(
    buf: CellBuffer,
    row: int,
    col: int,
    text: str,
    attrs: StyleAttrs | None = None,
    max_width: int = -1,
) {
    style = attrs if attrs is not None else StyleAttrs();
    if row < 0 or row >= buf.rows or col < 0 or col >= buf.columns {
        return;
    }
    limit = max_width if max_width >= 0 else (buf.columns - col);
    if limit <= 0 {
        return;
    }
    end = col + limit;
    if end > buf.columns {
        end = buf.columns;
    }
    x = col;
    shared = copy_attrs(style);
    made: dict[str, StyledCell] = {};
    line = buf.cells[row];
    if text.isascii() and text.isprintable() {
        for ch in text[:end - x] {
            cell = made.get(ch);
            if cell is None {
                cell = StyledCell(ch=ch, attrs=shared, wide_cont=False);
                made[ch] = cell;
            }
            line[x] = cell;
            x += 1;
        }
        return;
    }
    cont: StyledCell | None = None;
    for g in segment_graphemes(text) {
        seg = g.text;
        if not seg {
            continue;
        }
        if "\n" in seg or "\r" in seg {
            break;
        }
        w = grapheme_width(seg);
        if w <= 0 {
            continue;
        }
        if x + w > end {
            break;
        }
        cell = made.get(seg);
        if cell is None {
            cell = StyledCell(ch=seg, attrs=shared, wide_cont=False);
            made[seg] = cell;
        }
        line[x] = cell;
        if w > 1 {
            tail = cont
                if cont is not None
                else StyledCell(ch=" ", attrs=shared, wide_cont=True);
            cont = tail;
            for i in range(1, w) {
                line[x + i] = tail;
            }
        }
        x += w;
    }
}


impl buffer_blit_spans(
    buf: CellBuffer, row: int, col: int, spans: list[TextSpan], max_width: int = -1,
) {
    if row < 0 or row >= buf.rows or col < 0 or col >= buf.columns {
        return;
    }
    limit = max_width if max_width >= 0 else (buf.columns - col);
    if limit <= 0 {
        return;
    }
    x = col;
    remaining = limit;
    for span in spans {
        if remaining <= 0 or x >= buf.columns {
            break;
        }
        if not span.text {
            continue;
        }
        buffer_blit_text(buf, row, x, span.text, span.attrs, remaining);
        text = span.text;
        adv = display_width(text);
        if adv > remaining {
            adv = remaining;
        }
        if adv < 1 {
            continue;
        }
        x += adv;
        remaining -= adv;
    }
}


impl buffer_to_plain_rows(buf: CellBuffer) -> list[str] {
    out: list[str] = [];
    for r in range(buf.rows) {
        chars: list[str] = [];
        for c in range(buf.columns) {
            cell = buf.cells[r][c];
            if cell.wide_cont {
                continue;
            }
            chars.append(cell.ch or " ");
        }
        out.append("".join(chars));
    }
    return out;
}


impl buffer_from_plain_rows(rows: list[str], columns: int, rows_n: int) -> CellBuffer {
    buf = create_buffer(columns, rows_n);
    for r in range(rows_n) {
        line = rows[r] if r < len(rows) else "";
        buffer_blit_text(buf, r, 0, line, None, columns);
    }
    return buf;
}


impl _rect_bounds(rect: Rect, columns: int, rows_n: int) -> tuple[int, int, int, int] {
    x = rect.x;
    y = rect.y;
    w = rect.width;
    h = rect.height;
    x0 = max(0, x);
    y0 = max(0, y);
    x1 = min(columns, x + w);
    y1 = min(rows_n, y + h);
    return (x0, y0, x1, y1);
}


impl diff_buffers_ansi(
    previous: CellBuffer | None,
    desired: CellBuffer,
    patch_rects: list[Rect],
    force: bool = False,
) -> CellDiff {
    parts: list[str] = [];
    blank = blank_cell();
    written = 0;
    columns = desired.columns;
    rows_n = desired.rows;
    rects: list[any] = patch_rects;
    if not rects {
        rects = [Rect(x=0, y=0, width=columns, height=rows_n)];
    }
    cur_attrs = StyleAttrs();
    sgr_on = False;
    need_attrs = True;

    for rect in rects {
        (x0, y0, x1, y1) = _rect_bounds(rect, columns, rows_n);
        for y in range(y0, y1) {
            run_start = -1;
            run_chars: list[str] = [];
            run_attrs = StyleAttrs();
            for x in range(x0, x1) {
                want = blank;
                if y < len(desired.cells) and x < len(desired.cells[y]) {
                    want = desired.cells[y][x];
                }
                if want.wide_cont {
                    if run_start >= 0 {
                        if need_attrs or not attrs_eq(cur_attrs, run_attrs) {
                            parts.append(sgr_for(run_attrs));
                            cur_attrs = copy_attrs(run_attrs);
                            sgr_on = True;
                            need_attrs = False;
                        }
                        parts.append(
                            f"\x1b[{y + 1};{run_start + 1}H" + "".join(run_chars)
                        );
                        written += len(run_chars);
                        run_start = -1;
                        run_chars = [];
                    }
                    continue;
                }
                had = blank;
                if (
                    previous is not None and y < previous.rows and x < previous.columns
                ) {
                    had = previous.cells[y][x];
                }
                if cell_eq(want, had) and not force {
                    if run_start >= 0 {
                        if need_attrs or not attrs_eq(cur_attrs, run_attrs) {
                            parts.append(sgr_for(run_attrs));
                            cur_attrs = copy_attrs(run_attrs);
                            sgr_on = True;
                            need_attrs = False;
                        }
                        parts.append(
                            f"\x1b[{y + 1};{run_start + 1}H" + "".join(run_chars)
                        );
                        written += len(run_chars);
                        run_start = -1;
                        run_chars = [];
                    }
                    continue;
                }
                ch = want.ch or " ";
                if run_start < 0 {
                    run_start = x;
                    run_attrs = copy_attrs(want.attrs);
                    run_chars = [ch];
                } elif attrs_eq(run_attrs, want.attrs) {
                    run_chars.append(ch);
                } else {
                    if need_attrs or not attrs_eq(cur_attrs, run_attrs) {
                        parts.append(sgr_for(run_attrs));
                        cur_attrs = copy_attrs(run_attrs);
                        sgr_on = True;
                        need_attrs = False;
                    }
                    parts.append(f"\x1b[{y + 1};{run_start + 1}H" + "".join(run_chars));
                    written += len(run_chars);
                    run_start = x;
                    run_attrs = copy_attrs(want.attrs);
                    run_chars = [ch];
                }
            }
            if run_start >= 0 {
                if need_attrs or not attrs_eq(cur_attrs, run_attrs) {
                    parts.append(sgr_for(run_attrs));
                    cur_attrs = copy_attrs(run_attrs);
                    sgr_on = True;
                    need_attrs = False;
                }
                parts.append(f"\x1b[{y + 1};{run_start + 1}H" + "".join(run_chars));
                written += len(run_chars);
            }
        }
    }
    if sgr_on {
        parts.append(sgr_reset());
    }
    return CellDiff(text="".join(parts), cells_written=written);
}
