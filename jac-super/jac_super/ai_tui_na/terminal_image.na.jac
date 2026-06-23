"""Terminal image & hyperlink helpers — capability detection, Kitty/iTerm2
encoding, OSC-8 hyperlinks. Ported from pi packages/tui/src/terminal-image.ts.

Protocol detection is env-var only (no DA2 query) — correct for the supported
terminal set and zero I/O at import time.

Protocols:
  Kitty  ESC_G params ; base64data ESC \\  (APC chunked at 4096 bytes)
  iTerm2 ESC ] 1337 ; File=params : base64data BEL
  OSC-8  ESC ] 8 ;; URL ESC \\ TEXT ESC ] 8 ;; ESC \\

Image event node format: "mime/type:width_px:height_px"  (e.g. "image/png:640:480")
Image event text: base64-encoded image data (escaped via the standard IPC escaping).
"""

import os;
import from .libc_tty { tty_rows, tty_cols, tty_x_pixels, tty_y_pixels }

def _getenv(name: str) -> str {
    # Returns the env var value or "" if unset/None.
    v = os.getenv(name);
    if v is None {
        return "";
    }
    return v;
}

def detect_image_protocol -> str {
    # Kitty/iTerm2 image protocols don't work reliably inside tmux or screen.
    if len(_getenv("TMUX")) > 0 {
        return "";
    }
    term: str = _getenv("TERM");
    if term.startswith("tmux") or term.startswith("screen") {
        return "";
    }

    # Kitty-protocol terminals
    if len(_getenv("KITTY_WINDOW_ID")) > 0 {
        return "kitty";
    }
    term_prog: str = _getenv("TERM_PROGRAM");
    if term_prog == "kitty" {
        return "kitty";
    }
    if term_prog == "ghostty" {
        return "kitty";
    }
    if len(_getenv("GHOSTTY_RESOURCES_DIR")) > 0 {
        return "kitty";
    }
    if term.find("ghostty") >= 0 {
        return "kitty";
    }
    if len(_getenv("WEZTERM_PANE")) > 0 {
        return "kitty";
    }
    if term_prog == "wezterm" {
        return "kitty";
    }

    # iTerm2-protocol terminals
    if len(_getenv("ITERM_SESSION_ID")) > 0 {
        return "iterm2";
    }
    if term_prog == "iterm.app" {
        return "iterm2";
    }

    return "";
}

def detect_hyperlinks -> bool {
    # tmux forwards OSC-8 only when client_termfeatures lists "hyperlinks" —
    # we can't probe that from NA, so be conservative and disable by default.
    if len(_getenv("TMUX")) > 0 {
        return False;
    }
    term: str = _getenv("TERM");
    if term.startswith("screen") {
        return False;
    }

    if len(_getenv("KITTY_WINDOW_ID")) > 0 {
        return True;
    }
    term_prog: str = _getenv("TERM_PROGRAM");
    if term_prog == "kitty" {
        return True;
    }
    if term_prog == "ghostty" {
        return True;
    }
    if len(_getenv("GHOSTTY_RESOURCES_DIR")) > 0 {
        return True;
    }
    if term.find("ghostty") >= 0 {
        return True;
    }
    if len(_getenv("WEZTERM_PANE")) > 0 {
        return True;
    }
    if term_prog == "wezterm" {
        return True;
    }
    if len(_getenv("ITERM_SESSION_ID")) > 0 {
        return True;
    }
    if term_prog == "iterm.app" {
        return True;
    }
    if len(_getenv("WT_SESSION")) > 0 {
        return True;
    }
    if term_prog == "vscode" {
        return True;
    }
    if term_prog == "alacritty" {
        return True;
    }
    return False;
}

def term_hyperlink(text: str, url: str) -> str {
    # OSC-8 hyperlink, or "text (url)" fallback for unsupported terminals.
    if not detect_hyperlinks() {
        return text + " (" + url + ")";
    }
    return "\033]8;;" + url + "\033\\" + text + "\033]8;;\033\\";
}

def _encode_kitty(b64: str, cols: int, img_rows: int, img_id: int) -> str {
    # Kitty graphics protocol: APC sequence chunked at 4096 bytes.
    # a=T: transmit+display, f=100: PNG, q=2: quiet (no OK/ERR response).
    chunk_sz: int = 4096;
    params: str = "a=T,f=100,q=2";
    if cols > 0 {
        params = params + f",c={cols}";
    }
    if img_rows > 0 {
        params = params + f",r={img_rows}";
    }
    if img_id > 0 {
        params = params + f",i={img_id}";
    }

    n = len(b64);
    if n <= chunk_sz {
        return "\033_G" + params + ";" + b64 + "\033\\";
    }

    result: str = "";
    offset: int = 0;
    first: bool = True;
    while offset < n {
        chunk = b64[offset:offset + chunk_sz];
        is_last: bool = (offset + chunk_sz) >= n;
        if first {
            result = result + "\033_G" + params + ",m=1;" + chunk + "\033\\";
            first = False;
        } else {
            if is_last {
                result = result + "\033_Gm=0;" + chunk + "\033\\";
            } else {
                result = result + "\033_Gm=1;" + chunk + "\033\\";
            }
        }
        offset = offset + chunk_sz;
    }
    return result;
}

def _encode_iterm2(b64: str, cols: int) -> str {
    # iTerm2 inline image protocol (OSC 1337).
    params: str = "inline=1";
    if cols > 0 {
        params = params + f";width={cols}";
    }
    params = params + ";height=auto;preserveAspectRatio=1";
    return "\033]1337;File=" + params + ":" + b64 + "\007";
}

def image_fallback(mime: str, w_px: int, h_px: int) -> str {
    # Text placeholder for terminals that don't support image protocols.
    return f"[Image: {mime} {w_px}x{h_px}]";
}

def _cell_px_w -> int {
    # Width of one terminal cell in pixels. Falls back to 9 if the terminal
    # didn't report pixel dimensions (common in xterm-compatible terminals).
    xpx = tty_x_pixels();
    cols = tty_cols();
    if xpx > 0 and cols > 0 {
        return xpx // cols;
    }
    return 9;
}

def _cell_px_h -> int {
    # Height of one terminal cell in pixels. Falls back to 18.
    ypx = tty_y_pixels();
    rows = tty_rows();
    if ypx > 0 and rows > 0 {
        return ypx // rows;
    }
    return 18;
}

def image_rows(b64: str, mime: str, w_px: int, h_px: int, inner_w: int) -> list[str] {
    # Render an image to a list of terminal rows. Returns [fallback_text] when
    # the terminal has no image protocol. For Kitty/iTerm2, returns the APC/OSC
    # sequence on row 0 followed by (img_cell_rows-1) empty placeholder rows so
    # the diff engine reserves the correct height in the transcript.
    result: list[str] = [];
    proto = detect_image_protocol();

    if proto == "" {
        result.append(image_fallback(mime, w_px, h_px));
        return result;
    }

    # Scale image to fit inner_w columns, preserving aspect ratio.
    if w_px <= 0 {
        w_px = 1;
    }
    if h_px <= 0 {
        h_px = 1;
    }
    if inner_w <= 0 {
        inner_w = 1;
    }

    cpx_w = _cell_px_w();
    cpx_h = _cell_px_h();
    if cpx_w <= 0 {
        cpx_w = 9;
    }
    if cpx_h <= 0 {
        cpx_h = 18;
    }

    # max_px_w = the total pixel width available to the image
    max_px_w = inner_w * cpx_w;
    # Scale factor (keep as integer * 1000 to avoid float)
    scale_num: int = max_px_w * 1000;
    scale_k = scale_num // w_px;  # scaled_w_px = w_px * scale_k / 1000 = max_px_w

    scaled_w_px = w_px * scale_k // 1000;
    scaled_h_px = h_px * scale_k // 1000;

    img_cols = (scaled_w_px + cpx_w - 1) // cpx_w;
    img_cell_rows = (scaled_h_px + cpx_h - 1) // cpx_h;

    if img_cols < 1 {
        img_cols = 1;
    }
    if img_cell_rows < 1 {
        img_cell_rows = 1;
    }
    if img_cols > inner_w {
        img_cols = inner_w;
    }

    if proto == "kitty" {
        result.append(_encode_kitty(b64, img_cols, img_cell_rows, 0));
    } else {
        result.append(_encode_iterm2(b64, img_cols));
    }

    # Placeholder rows: the image pixel data spans these terminal rows; the diff
    # engine emits ESC[r;1H ESC[2K for each — that clears cell text but not Kitty
    # pixel placements, so the image remains visible.
    i: int = 1;
    while i < img_cell_rows {
        result.append("");
        i = i + 1;
    }

    return result;
}
