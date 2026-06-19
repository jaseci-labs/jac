#!/usr/bin/env python3
# ruff: noqa: T201
"""Phase-1 gate: load libtui.so under CPython and exercise the :pub surface
headlessly (no TTY).

Validates (plan §13 Phase-1 gate):
  - the .so loads via ctypes.CDLL without an init-order hang (PT_GNU_STACK fix);
  - tui_apply_frame parses a canned KEY:VALUE\\n...\\n--- blob into TuiState;
  - tui_render_buf renders the resulting screen into a memory buffer and the
    event text shows up in the painted bytes;
  - the na -> sv pull queue (tui_next_command) is empty after a pure frame apply.

Run by build.sh; exits non-zero on any failure.
"""

import ctypes
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if sys.platform == "darwin":
    LIB = os.path.join(HERE, "bin", "libtui.dylib")
elif sys.platform == "win32":
    LIB = os.path.join(HERE, "bin", "tui.dll")
else:
    LIB = os.path.join(HERE, "bin", "libtui.so")

MARK_USER = "HELLOUSERMARKER"
MARK_ASSISTANT = "HELLOASSISTANTMARKER"

# Canned frame: TYPE:full resets events, then two upsert-by-id EV lines.
# EV value grammar (ipc.na.jac _parse_ev_val): id:kind:node:text
FRAME = "\n".join(
    [
        "TYPE:full",
        "STATUS:running",
        "MODEL:claude-opus-4-8",
        f"EV:1:user:n:{MARK_USER}",
        f"EV:2:assistant:n:{MARK_ASSISTANT}",
        "---",
    ]
)


def main() -> int:
    build_hint = "build.ps1" if sys.platform == "win32" else "build.sh"
    if not os.path.exists(LIB):
        print(f"FAIL: {LIB} not found (build it with {build_hint})", file=sys.stderr)
        return 1

    lib = ctypes.CDLL(LIB)
    print(f"ok: CDLL loaded {LIB}")

    lib.tui_apply_frame.restype = ctypes.c_int64
    lib.tui_apply_frame.argtypes = [ctypes.c_char_p]
    lib.tui_render_buf.restype = ctypes.c_char_p
    lib.tui_render_buf.argtypes = []
    lib.tui_next_command.restype = ctypes.c_char_p
    lib.tui_next_command.argtypes = []
    lib.tui_quit_requested.restype = ctypes.c_int64
    lib.tui_quit_requested.argtypes = []

    rc = lib.tui_apply_frame(FRAME.encode("utf-8"))
    if rc != 0:
        print(f"FAIL: tui_apply_frame returned {rc}", file=sys.stderr)
        return 1
    print("ok: tui_apply_frame parsed the canned frame")

    buf = lib.tui_render_buf()
    screen = (buf or b"").decode("utf-8", "replace")
    if not screen:
        print("FAIL: tui_render_buf produced no bytes", file=sys.stderr)
        return 1
    print(f"ok: tui_render_buf produced {len(screen)} bytes")

    for mark in (MARK_USER, MARK_ASSISTANT):
        if mark not in screen:
            print(f"FAIL: {mark!r} not found in rendered screen", file=sys.stderr)
            return 1
    print("ok: both event texts appear in the rendered screen")

    # A pure frame apply enqueues no commands (those come from key dispatch).
    cmd = lib.tui_next_command()
    if cmd:
        print(f"FAIL: tui_next_command should be empty, got {cmd!r}", file=sys.stderr)
        return 1
    print('ok: tui_next_command drained empty ("")')

    if lib.tui_quit_requested() != 0:
        print("FAIL: tui_quit_requested should be 0 before any quit", file=sys.stderr)
        return 1
    print("ok: tui_quit_requested == 0")

    print("==> host gate passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
