import os;
import from .libc_tty { tty_rows, tty_cols, tty_x_pixels, tty_y_pixels }

glob _PROTO_KITTY: str = "kitty",
     _PROTO_ITERM2: str = "iterm2",
     _PROTO_NONE: str = "";

glob _KITTY_CHUNK_BYTES: int = 4096;

glob _DEFAULT_CELL_PX_W: int = 9,
     _DEFAULT_CELL_PX_H: int = 18;

glob _FP_SCALE: int = 1000;

def _getenv(name: str) -> str {
    v = os.getenv(name);
    return v if v is not None else "";
}

def _env_set(name: str) -> bool {
    return _getenv(name) != "";
}

def _graphics_protocol(term: str, term_prog: str) -> str {
    if _env_set("KITTY_WINDOW_ID") or term_prog == "kitty" {
        return _PROTO_KITTY;
    }
    if (
        term_prog == "ghostty"
        or _env_set("GHOSTTY_RESOURCES_DIR")
        or term.find("ghostty") >= 0
    ) {
        return _PROTO_KITTY;
    }
    if _env_set("WEZTERM_PANE") or term_prog == "wezterm" {
        return _PROTO_KITTY;
    }
    if _env_set("ITERM_SESSION_ID") or term_prog == "iterm.app" {
        return _PROTO_ITERM2;
    }
    return _PROTO_NONE;
}

def detect_image_protocol -> str {
    if _env_set("TMUX") {
        return _PROTO_NONE;
    }
    term: str = _getenv("TERM");
    if term.startswith("tmux") or term.startswith("screen") {
        return _PROTO_NONE;
    }
    return _graphics_protocol(term, _getenv("TERM_PROGRAM"));
}

def detect_hyperlinks -> bool {
    if _env_set("TMUX") {
        return False;
    }
    term: str = _getenv("TERM");
    if term.startswith("screen") {
        return False;
    }
    term_prog: str = _getenv("TERM_PROGRAM");
    if _graphics_protocol(term, term_prog) != _PROTO_NONE {
        return True;
    }

    if _env_set("WT_SESSION") {
        return True;
    }
    return term_prog == "vscode" or term_prog == "alacritty";
}

def term_hyperlink(text: str, url: str) -> str {
    if not detect_hyperlinks() {
        return text + " (" + url + ")";
    }
    return "\033]8;;" + url + "\033\\" + text + "\033]8;;\033\\";
}

def _encode_kitty(b64: str, cols: int, rows_cells: int) -> str {
    parts: list[str] = ["a=T,f=100,q=2"];
    if cols > 0 {
        parts.append(f"c={cols}");
    }
    if rows_cells > 0 {
        parts.append(f"r={rows_cells}");
    }
    params: str = ",".join(parts);

    n = len(b64);
    if n <= _KITTY_CHUNK_BYTES {
        return "\033_G" + params + ";" + b64 + "\033\\";
    }

    chunks: list[str] = [];
    offset: int = 0;
    while offset < n {
        end = min(n, offset + _KITTY_CHUNK_BYTES);
        chunk = b64[offset:end];
        if offset == 0 {
            chunks.append("\033_G" + params + ",m=1;" + chunk + "\033\\");
        } elif end == n {
            chunks.append("\033_Gm=0;" + chunk + "\033\\");
        } else {
            chunks.append("\033_Gm=1;" + chunk + "\033\\");
        }
        offset += _KITTY_CHUNK_BYTES;
    }
    return "".join(chunks);
}

def _encode_iterm2(b64: str, cols: int) -> str {
    parts: list[str] = ["inline=1"];
    if cols > 0 {
        parts.append(f"width={cols}");
    }
    parts.append("height=auto;preserveAspectRatio=1");
    return "\033]1337;File=" + ";".join(parts) + ":" + b64 + "\007";
}

def image_fallback(mime: str, w_px: int, h_px: int) -> str {
    return f"[Image: {mime} {w_px}x{h_px}]";
}

def _cell_px(px_total: int, cells: int, fallback: int) -> int {
    if px_total > 0 and cells > 0 {
        per_cell = px_total // cells;
        if per_cell > 0 {
            return per_cell;
        }
    }
    return fallback;
}

def _fit_cells(w_px: int, h_px: int, inner_w: int) -> tuple[int, int] {
    cell_w: int = _cell_px(tty_x_pixels(), tty_cols(), _DEFAULT_CELL_PX_W);
    cell_h: int = _cell_px(tty_y_pixels(), tty_rows(), _DEFAULT_CELL_PX_H);

    scale_k: int = inner_w * cell_w * _FP_SCALE // w_px;
    scaled_w_px: int = w_px * scale_k // _FP_SCALE;
    scaled_h_px: int = h_px * scale_k // _FP_SCALE;

    cols: int = (scaled_w_px + cell_w - 1) // cell_w;
    rows: int = (scaled_h_px + cell_h - 1) // cell_h;
    return (min(max(cols, 1), inner_w), max(rows, 1));
}

def image_rows(b64: str, mime: str, w_px: int, h_px: int, inner_w: int) -> list[str] {
    proto = detect_image_protocol();
    if proto == _PROTO_NONE {
        return [image_fallback(mime, w_px, h_px)];
    }

    (cols, cell_rows) = _fit_cells(max(w_px, 1), max(h_px, 1), max(inner_w, 1));
    encoded: str = _encode_kitty(b64, cols, cell_rows)
        if proto == _PROTO_KITTY
        else _encode_iterm2(b64, cols);

    result: list[str] = [encoded];
    for blank_row in range(1, cell_rows) {
        result.append("");
    }
    return result;
}
