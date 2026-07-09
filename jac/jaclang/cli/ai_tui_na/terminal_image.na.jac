"""Inline terminal graphics: protocol detection and image escape encoding.

Detects the kitty graphics protocol (kitty/ghostty/wezterm) and iTerm2's
OSC 1337 inline-image protocol from the environment, refusing both under
tmux/screen where passthrough is unreliable. image_rows renders a base64
image as feed rows: one escape-bearing row followed by blank rows that
reserve the cells the image paints over. All wire bytes (kitty APC
chunking at 4096, OSC 1337 form, OSC 8 hyperlinks) are frozen.
"""
import os;
import from .libc_tty { tty_rows, tty_cols, tty_x_pixels, tty_y_pixels }

# Protocol tokens returned by detect_image_protocol (str-typed on purpose:
# part of this module's public surface).
glob _PROTO_KITTY: str = "kitty",
     _PROTO_ITERM2: str = "iterm2",
     _PROTO_NONE: str = "";

glob _KITTY_CHUNK_BYTES: int = 4096;

# Cell pixel sizes assumed when the tty reports no pixel geometry.
glob _DEFAULT_CELL_PX_W: int = 9,
     _DEFAULT_CELL_PX_H: int = 18;

# Fixed-point factor for the aspect-ratio math (na float division is off
# limits; x1000 integer arithmetic loses nothing at terminal scale).
glob _FP_SCALE: int = 1000;

# --- environment probes ---

"""Read an environment variable, mapping unset to ""."""
def _getenv(name: str) -> str {
    v = os.getenv(name);
    return v if v is not None else "";
}

"""True when the named environment variable is set and non-empty."""
def _env_set(name: str) -> bool {
    return _getenv(name) != "";
}

"""Graphics protocol advertised by a terminal identified by term/term_prog.

Shared ladder for detect_image_protocol and detect_hyperlinks: the kitty
protocol family (kitty, ghostty, wezterm) first, then iTerm2. Callers
apply their own tmux/screen guards before consulting this.
"""
def _graphics_protocol(term: str, term_prog: str) -> str {
    if _env_set("KITTY_WINDOW_ID") or term_prog == "kitty" {
        return _PROTO_KITTY;
    }
    if (term_prog == "ghostty"
        or _env_set("GHOSTTY_RESOURCES_DIR")
        or term.find("ghostty") >= 0) {
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

"""Inline-image protocol for this terminal: "kitty", "iterm2", or "" (none).

tmux/screen always report none — graphics passthrough is unreliable there.
"""
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

"""True when the terminal is known to render OSC 8 hyperlinks."""
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
    # Hyperlink-capable terminals beyond the graphics-protocol family.
    if _env_set("WT_SESSION") {
        return True;
    }
    return term_prog == "vscode" or term_prog == "alacritty";
}

# --- escape encoders (wire bytes frozen) ---

"""Wrap text in an OSC 8 hyperlink, or append " (url)" when unsupported.

Concatenation (not f-strings) on purpose: link text/url may exceed the
1024-byte na f-string buffer.
"""
def term_hyperlink(text: str, url: str) -> str {
    if not detect_hyperlinks() {
        return text + " (" + url + ")";
    }
    return "\033]8;;" + url + "\033\\" + text + "\033]8;;\033\\";
}

"""Kitty APC graphics escape(s) for b64, sized cols x rows_cells.

Payloads over 4096 bytes are split into m=1 continuation chunks with a
terminating m=0 chunk, per the kitty protocol.
"""
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

"""iTerm2 OSC 1337 inline-image escape for b64, cols wide."""
def _encode_iterm2(b64: str, cols: int) -> str {
    parts: list[str] = ["inline=1"];
    if cols > 0 {
        parts.append(f"width={cols}");
    }
    parts.append("height=auto;preserveAspectRatio=1");
    return "\033]1337;File=" + ";".join(parts) + ":" + b64 + "\007";
}

"""Placeholder row shown when inline graphics are unavailable."""
def image_fallback(mime: str, w_px: int, h_px: int) -> str {
    return f"[Image: {mime} {w_px}x{h_px}]";
}

# --- geometry ---

"""Pixel size of one terminal cell, or fallback when the tty reports none."""
def _cell_px(px_total: int, cells: int, fallback: int) -> int {
    if px_total > 0 and cells > 0 {
        per_cell = px_total // cells;
        if per_cell > 0 {
            return per_cell;
        }
    }
    return fallback;
}

"""Scale a w_px x h_px image to terminal cells, capped at inner_w columns.

Returns (cols, rows) in cells, each floored at 1. Inputs must already be
clamped positive.
"""
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

"""Render a base64 image as feed rows for a panel inner_w columns wide.

Row 0 carries the protocol escape; the remaining rows are blank and only
reserve the cells the image paints over. Falls back to a text placeholder
when no graphics protocol is detected.
"""
def image_rows(b64: str, mime: str, w_px: int, h_px: int, inner_w: int) -> list[str] {
    proto = detect_image_protocol();
    if proto == _PROTO_NONE {
        return [image_fallback(mime, w_px, h_px)];
    }

    (cols, cell_rows) = _fit_cells(max(w_px, 1), max(h_px, 1), max(inner_w, 1));
    encoded: str = _encode_kitty(b64, cols, cell_rows) if proto == _PROTO_KITTY else _encode_iterm2(b64, cols);

    result: list[str] = [encoded];
    for blank_row in range(1, cell_rows) {
        result.append("");
    }
    return result;
}
