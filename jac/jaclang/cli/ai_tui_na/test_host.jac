"""Phase-1 gate: load libtui shared library under CPython and exercise the
:pub surface headlessly (no TTY).

Validates:
  - the shared lib loads via ctypes.CDLL;
  - tui_apply_frame parses a canned KEY:VALUE blob into TuiState;
  - tui_render_buf renders the screen and the event text shows up;
  - tui_next_command is empty after a pure frame apply.

Run by build.sh / build.ps1; exits non-zero on any failure.
"""

import ctypes;
import os;
import sys;

def main -> int {
    mark_user = "HELLOUSERMARKER";
    mark_assistant = "HELLOASSISTANTMARKER";
    frame = "\n".join(
        [
            "TYPE:full",
            "STATUS:running",
            "MODEL:claude-opus-4-8",
            f"EV:1:user:n:{mark_user}",
            f"EV:2:assistant:n:{mark_assistant}",
            "---"
        ]
    );

    if sys.platform == "darwin" {
        lib_path = os.path.join("bin", "libtui.dylib");
    } elif sys.platform == "win32" {
        lib_path = os.path.join("bin", "tui.dll");
    } else {
        lib_path = os.path.join("bin", "libtui.so");
    }

    build_hint = "build.ps1" if sys.platform == "win32" else "build.sh";
    if not os.path.exists(lib_path) {
        sys.stderr.write(f"FAIL: {lib_path} not found (build it with {build_hint})\n");
        return 1;
    }

    lib = ctypes.CDLL(lib_path);
    sys.stdout.write(f"ok: CDLL loaded {lib_path}\n");

    # Use bare C names on all platforms. Darwin dlsym prepends '_' internally,
    # so lib["tui_apply_frame"] resolves _tui_apply_frame in the export trie.
    # lib[name] creates a new _FuncPtr each call; cache the objects so
    # that restype/argtypes set below survive to the actual call.
    fn_apply_frame = lib["tui_apply_frame"];
    fn_apply_frame.restype = ctypes.c_int64;
    fn_apply_frame.argtypes = [ctypes.c_char_p];
    fn_render_buf = lib["tui_render_buf"];
    fn_render_buf.restype = ctypes.c_char_p;
    fn_render_buf.argtypes = [];
    fn_next_command = lib["tui_next_command"];
    fn_next_command.restype = ctypes.c_char_p;
    fn_next_command.argtypes = [];
    fn_quit_requested = lib["tui_quit_requested"];
    fn_quit_requested.restype = ctypes.c_int64;
    fn_quit_requested.argtypes = [];

    rc = fn_apply_frame(frame.encode("utf-8"));
    if rc != 0 {
        sys.stderr.write(f"FAIL: tui_apply_frame returned {rc}\n");
        return 1;
    }
    sys.stdout.write("ok: tui_apply_frame parsed the canned frame\n");

    buf = fn_render_buf();
    screen = (buf or b"").decode("utf-8", "replace");
    if not screen {
        sys.stderr.write("FAIL: tui_render_buf produced no bytes\n");
        return 1;
    }
    sys.stdout.write(f"ok: tui_render_buf produced {len(screen)} bytes\n");

    for mark in [mark_user, mark_assistant] {
        if mark not in screen {
            sys.stderr.write(f"FAIL: {repr(mark)} not found in rendered screen\n");
            return 1;
        }
    }
    sys.stdout.write("ok: both event texts appear in the rendered screen\n");

    cmd = fn_next_command();
    if cmd {
        sys.stderr.write(f"FAIL: tui_next_command should be empty, got {repr(cmd)}\n");
        return 1;
    }
    sys.stdout.write('ok: tui_next_command drained empty ("")\n');

    if fn_quit_requested() != 0 {
        sys.stderr.write("FAIL: tui_quit_requested should be 0 before any quit\n");
        return 1;
    }
    sys.stdout.write("ok: tui_quit_requested == 0\n");
    sys.stdout.write("==> host gate passed.\n");
    return 0;
}

with entry {
    sys.exit(main());
}
