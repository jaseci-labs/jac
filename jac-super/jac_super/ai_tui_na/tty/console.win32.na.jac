"""Win32 console backend — kernel32 Console API, no termios.

Implements the same function surface as libc_tty.linux.na.jac. Attaches to
the parent console (parent-console v1 mode); no ConPTY (v2 follow-up).

KEY TRANSLATION (the crux — see PLAN-tui-windows.md §"The real crux"):
ReadConsoleInputW delivers INPUT_RECORD structs; each keystroke is a discrete
KEY_EVENT. Unlike the Linux byte stream, no coalescing is needed: arrow keys
arrive as VK_UP/VK_DOWN/... records and map directly to the escape strings
input.na.jac expects. The translation table covers all sequences the rest of
the TUI relies on. ENABLE_VIRTUAL_TERMINAL_INPUT is NOT set for
ReadConsoleInputW callers -- VT input mode affects ReadFile(stdin), not the
low-level ReadConsoleInputW path, and would not help here.

CONSOLE MODE FLAGS (set on tty_open_dev):
  Input  : disable ENABLE_PROCESSED_INPUT | ENABLE_LINE_INPUT | ENABLE_ECHO_INPUT
           Disabling ENABLE_PROCESSED_INPUT routes Ctrl+C as UnicodeChar=0x03
           (same as Linux raw mode clearing ISIG) instead of a console event.
  Output : enable  ENABLE_VIRTUAL_TERMINAL_PROCESSING
           Fail fast if VT output is unavailable (legacy conhost unsupported).

INPUT_RECORD layout (20 bytes, Win64):
  +0   EventType        WORD   (1 = KEY_EVENT)
  +2   (padding)        WORD
  +4   bKeyDown         BOOL   (i32; 0 = key-up event, skip)
  +8   wRepeatCount     WORD
  +10  wVirtualKeyCode  WORD
  +12  wVirtualScanCode WORD
  +14  uChar.UnicodeChar WCHAR (u16, BMP code point or 0 for pure-VK keys)
  +16  dwControlKeyState DWORD

CONSOLE_SCREEN_BUFFER_INFO layout (22 bytes):
  +0   dwSize             COORD (X=WORD, Y=WORD)
  +4   dwCursorPosition   COORD
  +8   wAttributes        WORD
  +10  srWindow           SMALL_RECT (Left, Top, Right, Bottom each WORD)
  +18  dwMaximumWindowSize COORD

FFI buffers (INPUT_RECORD[], CONSOLE_SCREEN_BUFFER_INFO, DWORD*) MUST be
calloc'd -- NA strings are NUL-terminated and concat of chr(0) truncates at
the first zero byte, corrupting struct layouts. Never use chr()+concat for
struct buffers.

Type rule: Jac `int` for locals; `i32`/`i64` only in FFI decl slots.
"""

import os;

# PeekConsoleInputW: reserved for Phase 6 subprocess IPC multiplex.
# WaitForSingleObject: used by tty_poll as the Windows poll(2) equivalent.
import from "kernel32.dll" {
    def GetStdHandle(std: i32) -> i64;  def GetConsoleMode(
        handle: i64, mode: str
    ) -> i32;  def SetConsoleMode(handle: i64, mode: i32) -> i32;  def ReadConsoleInputW(
        handle: i64, buf: str, count: i32, read: str
    ) -> i32;  def WriteFile(
        handle: i64, buf: str, n: i32, written: str, overlapped: i64
    ) -> i32;  def PeekConsoleInputW(
        handle: i64, buf: str, count: i32, read: str
    ) -> i32;  def GetConsoleScreenBufferInfo(handle: i64, info: str) -> i32;  def WaitForSingleObject(
        handle: i64, ms: i32
    ) -> i32;  def AttachConsole(pid: i32) -> i32;  def AllocConsole -> i32;  def FreeConsole -> i32;
}

import from "msvcrt.dll" {
    def calloc(n: int, sz: int) -> int;  def free(p: int) -> None;  def memset(
        s: int, c: i32, n: int
    ) -> int;  def memcpy(dst: int, src: str, n: int) -> int;
}

# ── constants ────────────────────────────────────────────────────────────────

# GetStdHandle sentinel for failure (INVALID_HANDLE_VALUE as i64).
glob INVALID_HANDLE: int = -1;

# Input mode flags to DISABLE for raw input.
glob ENABLE_PROCESSED_INPUT: int = 0x0001,
     ENABLE_LINE_INPUT: int = 0x0002,
     ENABLE_ECHO_INPUT: int = 0x0004;

# Output mode flag to ENABLE for ANSI escape rendering.
glob ENABLE_VT_PROCESSING: int = 0x0004;

# WaitForSingleObject return codes.
glob WAIT_OBJECT_0: int = 0,
     WAIT_TIMEOUT: int = 258;

# INPUT_RECORD EventType values.
glob KEY_EVENT_TYPE: int = 1;

# dwControlKeyState bitmask for Shift.
glob SHIFT_PRESSED: int = 0x0010;

# Virtual key codes for keys that need explicit VK-to-escape mapping.
glob VK_BACK: int = 0x08,
     VK_TAB: int = 0x09,
     VK_PRIOR: int = 0x21,
     VK_NEXT: int = 0x22,
     VK_END: int = 0x23,
     VK_HOME: int = 0x24,
     VK_LEFT: int = 0x25,
     VK_UP: int = 0x26,
     VK_RIGHT: int = 0x27,
     VK_DOWN: int = 0x28,
     VK_INSERT: int = 0x2D,
     VK_DELETE: int = 0x2E,
     VK_F1: int = 0x70,
     VK_F2: int = 0x71,
     VK_F3: int = 0x72,
     VK_F4: int = 0x73,
     VK_F5: int = 0x74,
     VK_F6: int = 0x75,
     VK_F7: int = 0x76,
     VK_F8: int = 0x77,
     VK_F9: int = 0x78,
     VK_F10: int = 0x79,
     VK_F11: int = 0x7A,
     VK_F12: int = 0x7B;

# ── context object ───────────────────────────────────────────────────────────
obj TtyCtx {
    has in_handle: int = -1,
        out_handle: int = -1,
        saved_in_mode: int = 0,
        saved_out_mode: int = 0,
        rows: int = 24,
        cols: int = 80,
        stdin_ready: int = 0,
        key_ready: int = 0,
        # 1 if we called AllocConsole() ourselves; never FreeConsole an inherited
        # console (that would detach Python's own I/O after the TUI closes).
        allocated_console: int = 0;
}

glob g_tty: TtyCtx = TtyCtx();

# ── struct helpers ───────────────────────────────────────────────────────────
def read_u32(buf: str, off: int) -> int {
    b0: int = ord(buf[off]);
    b1: int = ord(buf[off + 1]);
    b2: int = ord(buf[off + 2]);
    b3: int = ord(buf[off + 3]);
    return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24);
}

def u16le(buf: str, off: int) -> int {
    lo: int = ord(buf[off]);
    hi: int = ord(buf[off + 1]);
    return lo | (hi << 8);
}

# Encode a BMP Unicode code point (non-NUL) to a UTF-8 str using chr().
# All output bytes for non-NUL BMP points are >= 0x80 for multi-byte sequences,
# so no NUL truncation can occur. U+0000 returns "" (NUL would truncate NA str).
def wchar_to_utf8(c: int) -> str {
    if c <= 0 {
        return "";
    }
    if c < 0x80 {
        return chr(c);
    }
    if c < 0x800 {
        return chr(0xC0 | (c >> 6)) + chr(0x80 | (c & 0x3F));
    }
    return chr(0xE0 | (c >> 12)) + chr(0x80 | ((c >> 6) & 0x3F)) + chr(
        0x80 | (c & 0x3F)
    );
}

def _read_console_mode(handle: int) -> int {
    p: int = calloc(4, 1);
    mode_buf: str = p;
    ok: int = GetConsoleMode(handle, mode_buf);
    val: int = 0;
    if ok != 0 {
        val = read_u32(mode_buf, 0);
    }
    free(p);
    return val;
}

# ── lifecycle ────────────────────────────────────────────────────────────────
def tty_open -> int {
    return tty_open_dev("");
}

def tty_fd -> int {
    # Returns 0 as a non-negative sentinel when the console is open (handles
    # don't map to POSIX fds). tty_write() ignores this value and uses
    # g_tty.out_handle directly. Returns -1 when not open.
    if g_tty.in_handle < 0 {
        return -1;
    }
    return 0;
}

def tty_open_dev(dev: str) -> int {
    # dev is ignored in v1; always attach the parent console.
    #
    # AttachConsole(-1) = ATTACH_PARENT_PROCESS. It fails with ERROR_ACCESS_DENIED
    # when the process already owns a console (the normal case: Python has one).
    # In that case, GetStdHandle() returns the existing valid handles. We call
    # AllocConsole() only as a last resort when both handles are INVALID_HANDLE_VALUE.
    AttachConsole(-1);
    in_h: int = GetStdHandle(-10);
    out_h: int = GetStdHandle(-11);
    if in_h == INVALID_HANDLE or out_h == INVALID_HANDLE {
        if AllocConsole() == 0 {
            return -1;
        }
        g_tty.allocated_console = 1;
        in_h = GetStdHandle(-10);
        out_h = GetStdHandle(-11);
        if in_h == INVALID_HANDLE or out_h == INVALID_HANDLE {
            return -1;
        }
    }

    g_tty.saved_in_mode = _read_console_mode(in_h);
    g_tty.saved_out_mode = _read_console_mode(out_h);

    # Raw input: disable line buffering, local echo, and signal generation.
    # Clearing ENABLE_PROCESSED_INPUT makes Ctrl+C arrive as UnicodeChar=0x03
    # in ReadConsoleInputW instead of firing a console ctrl-break event.
    new_in: int = g_tty.saved_in_mode & ~(
        ENABLE_PROCESSED_INPUT | ENABLE_LINE_INPUT | ENABLE_ECHO_INPUT
    );
    if SetConsoleMode(in_h, new_in) == 0 {
        return -1;
    }

    # VT output: required for the ANSI diff renderer. Fail fast on legacy
    # conhost without VT — a garbled screen is worse than a clear error.
    new_out: int = g_tty.saved_out_mode | ENABLE_VT_PROCESSING;
    if SetConsoleMode(out_h, new_out) == 0 {
        SetConsoleMode(in_h, g_tty.saved_in_mode);
        return -1;
    }

    g_tty.in_handle = in_h;
    g_tty.out_handle = out_h;
    tty_update_size();
    return 0;
}

def tty_close {
    in_h: int = g_tty.in_handle;
    out_h: int = g_tty.out_handle;
    if in_h >= 0 {
        # Restore input mode with error checking
        if SetConsoleMode(in_h, g_tty.saved_in_mode) == 0 {
            # Fallback: restore at least processed input and line input
            # so Ctrl+C and other keybindings work after exit
            fallback: int = g_tty.saved_in_mode | ENABLE_PROCESSED_INPUT | ENABLE_LINE_INPUT;
            SetConsoleMode(in_h, fallback);
        }
    }
    if out_h >= 0 {
        # Restore output mode with error checking
        if SetConsoleMode(out_h, g_tty.saved_out_mode) == 0 {
            # Fallback: clear VT processing if restore fails
            fallback: int = g_tty.saved_out_mode & ~ENABLE_VT_PROCESSING;
            SetConsoleMode(out_h, fallback);
        }
    }
    g_tty.in_handle = -1;
    g_tty.out_handle = -1;
    if g_tty.allocated_console != 0 {
        FreeConsole();
        g_tty.allocated_console = 0;
    }
}

# ── size ─────────────────────────────────────────────────────────────────────
def tty_update_size {
    out_h: int = g_tty.out_handle;
    if out_h < 0 {
        return;
    }
    # CONSOLE_SCREEN_BUFFER_INFO (22 bytes). Window size from srWindow, not
    # dwSize (buffer can be larger with scrollback). srWindow at offset +10:
    #   Left  (WORD) +10,  Top    (WORD) +12
    #   Right (WORD) +14,  Bottom (WORD) +16
    p: int = calloc(22, 1);
    info: str = p;
    if GetConsoleScreenBufferInfo(out_h, info) != 0 {
        left: int = u16le(info, 10);
        top: int = u16le(info, 12);
        right: int = u16le(info, 14);
        bottom: int = u16le(info, 16);
        col: int = right - left + 1;
        row: int = bottom - top + 1;
        if col > 0 {
            if row > 0 {
                g_tty.cols = col;
                g_tty.rows = row;
            }
        }
    }
    free(p);
}

def tty_rows -> int {
    return g_tty.rows;
}

def tty_cols -> int {
    return g_tty.cols;
}

def tty_x_pixels -> int {
    # Windows Console API does not expose terminal pixel dimensions; return 0
    # so callers fall back to their default cell-pixel estimates.
    return 0;
}

def tty_y_pixels -> int {
    return 0;
}

# ── poll ─────────────────────────────────────────────────────────────────────
def tty_poll(timeout_ms: int) {
    g_tty.stdin_ready = 0;
    g_tty.key_ready = 0;
    in_h: int = g_tty.in_handle;
    if in_h < 0 {
        return;
    }
    # WaitForSingleObject on the console input handle signals when INPUT_RECORDs
    # are available. This is the Windows equivalent of poll(fd, POLLIN, timeout).
    # In-process v1 has no IPC pipe, so stdin_ready stays 0.
    r: int = WaitForSingleObject(in_h, timeout_ms);
    if r == WAIT_OBJECT_0 {
        g_tty.key_ready = 1;
    }
}

def tty_stdin_ready -> int {
    return g_tty.stdin_ready;
}

def tty_key_ready -> int {
    return g_tty.key_ready;
}

# ── write ────────────────────────────────────────────────────────────────────
def tty_write(fd: int, text: str) {
    # When a console is open (interactive TUI) we always render to out_handle and
    # ignore fd — the diff renderer owns the screen. Only in the headless case
    # (no tty_open_dev call, e.g. CI tests) do we honor fd, routing it to the
    # matching std handle: fd 2 → STD_ERROR_HANDLE (-12), anything else →
    # STD_OUTPUT_HANDLE (-11). This mirrors the POSIX backends' write(fd, ...) so
    # platform-neutral test output (and stderr markers) are not silently lost.
    out_h: int = g_tty.out_handle;
    if out_h < 0 {
        std_id: int = -11;
        if fd == 2 {
            std_id = -12;
        }
        out_h = GetStdHandle(std_id);
        if out_h <= 0 {
            return;
        }
    }
    n: int = len(text);
    if n <= 0 {
        return;
    }
    # WriteFile needs a DWORD* for lpNumberOfBytesWritten (must be non-null for
    # synchronous I/O). Calloc a 4-byte buffer; result value is discarded.
    p: int = calloc(4, 1);
    written: str = p;
    WriteFile(out_h, text, n, written, 0);
    free(p);
}

# ── key translation ──────────────────────────────────────────────────────────
def tty_read_key -> str {
    # Read one INPUT_RECORD (20 bytes) from the console input queue.
    # Returns the escape string input.na.jac expects, or "" to skip.
    #
    # Translation strategy: VK-to-escape mapping has priority for navigation and
    # function keys (many have UnicodeChar == 0). For everything else, UnicodeChar
    # is the typed code point (regular chars, Ctrl+letter as 0x01..0x1A, Enter=13,
    # ESC=27). Backspace is special: VK_BACK gives UnicodeChar=8 (BS) but Linux
    # raw mode emits DEL (0x7f), so we override it explicitly.
    in_h: int = g_tty.in_handle;
    if in_h < 0 {
        return "";
    }

    # Alloc INPUT_RECORD (20 bytes) and DWORD read-count (4 bytes).
    rec_p: int = calloc(1, 20);
    cnt_p: int = calloc(1, 4);
    rec: str = rec_p;
    cnt: str = cnt_p;
    ok: int = ReadConsoleInputW(in_h, rec, 1, cnt);
    free(cnt_p);
    if ok == 0 {
        free(rec_p);
        return "";
    }

    evt: int = u16le(rec, 0);
    if evt != KEY_EVENT_TYPE {
        free(rec_p);
        return "";
    }
    key_down: int = read_u32(rec, 4);
    if key_down == 0 {
        free(rec_p);
        return "";
    }
    vk: int = u16le(rec, 10);
    uc: int = u16le(rec, 14);
    ctrl_state: int = read_u32(rec, 16);
    free(rec_p);

    shift: int = 0;
    if ctrl_state & SHIFT_PRESSED != 0 {
        shift = 1;
    }

    # ── navigation keys (UnicodeChar == 0 for most; check VK first) ──────────
    if vk == VK_BACK {
        return "\x7f";
    }  # Backspace → DEL (matches Linux raw)
    if vk == VK_TAB {
        if shift != 0 {
            return "\x1b[Z";
        }  # Shift+Tab
        return "\t";
    }
    if vk == VK_UP {
        return "\x1b[A";
    }
    if vk == VK_DOWN {
        return "\x1b[B";
    }
    if vk == VK_RIGHT {
        return "\x1b[C";
    }
    if vk == VK_LEFT {
        return "\x1b[D";
    }
    if vk == VK_HOME {
        return "\x1b[H";
    }
    if vk == VK_END {
        return "\x1b[F";
    }
    if vk == VK_PRIOR {
        return "\x1b[5~";
    }  # Page Up
    if vk == VK_NEXT {
        return "\x1b[6~";
    }  # Page Down
    if vk == VK_INSERT {
        return "\x1b[2~";
    }
    if vk == VK_DELETE {
        return "\x1b[3~";
    }

    # ── function keys ─────────────────────────────────────────────────────────
    if vk == VK_F1 {
        return "\x1bOP";
    }
    if vk == VK_F2 {
        return "\x1bOQ";
    }
    if vk == VK_F3 {
        return "\x1bOR";
    }
    if vk == VK_F4 {
        return "\x1bOS";
    }
    if vk == VK_F5 {
        return "\x1b[15~";
    }
    if vk == VK_F6 {
        return "\x1b[17~";
    }
    if vk == VK_F7 {
        return "\x1b[18~";
    }
    if vk == VK_F8 {
        return "\x1b[19~";
    }
    if vk == VK_F9 {
        return "\x1b[20~";
    }
    if vk == VK_F10 {
        return "\x1b[21~";
    }
    if vk == VK_F11 {
        return "\x1b[23~";
    }
    if vk == VK_F12 {
        return "\x1b[24~";
    }

    # ── regular characters ────────────────────────────────────────────────────
    # UnicodeChar covers: printable chars, Enter (13=\r), ESC (27=\x1b),
    # Ctrl+letter (1..26 = \x01..\x1a, including Ctrl+C = 3 = \x03).
    if uc > 0 {
        return wchar_to_utf8(uc);
    }

    return "";
}

# ── subprocess-only stubs (in-process v1 does not call these) ────────────────
def tty_read_line -> str {
    # Subprocess IPC: read one line from the IPC pipe. Stubbed for v1.
    return "";
}

def tty_init_stdio_remap -> int {
    # Subprocess IPC: remap fd 1 → fd 3 for the command channel. Stubbed for v1.
    return -1;
}

def tty_restore_stdio {
# Subprocess IPC: restore fd 1 from fd 3. Stubbed for v1.
}

def tty_ipc_fd -> int {
    # Subprocess IPC: returns the fd for the IPC command channel. Stubbed for v1.
    return -1;
}
