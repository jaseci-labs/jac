"""Regression tests for the in-process `jac ai --tui` backend (PLAN-tui-in-process
Phase 3).

`test_ai_tui_bridge.jac` covers the *subprocess* transport; this file covers the
*in-process* one: the `TuiHost` ctypes binding to `ai_tui_na/bin/libtui.so` and
the frozen frame/command seam crossing it. Two layers:

  1. Headless (always runs, CI-safe): bind the `.so`, push a canned frame through
     the shared `_frame_blob` encoder + native parser, and assert it round-trips
     into the rendered screen buffer. Also proves the na -> sv pull queue starts
     drained and quit is unset. This is the sv-side twin of the native Phase-1
     gate (`jac/jaclang/cli/ai_tui_na/test_host.jac`), reached through the real `TuiHost` wrapper
     rather than raw ctypes.
  2. Real PTY (skips cleanly where openpty is unavailable): open a pseudo-tty,
     `start` the host on it, type `hi`+Enter into the controller end, and drive
     the same wait_key -> handle_key -> next_command loop the in-process ticker
     uses, asserting it yields `SEND:hi`. This is the only path that exercises the
     tty-bound half of the seam (start / wait_key / handle_key / render /
     shutdown) headlessly.

The artifact (`libtui.so`) is produced by `ai_tui_na/build.sh`; if it is absent
and cannot be built, the tests skip rather than fail (the native build gate owns
.so production).
"""

import importlib;
import os;
import from pathlib { Path }


def _host_env -> dict {
    # Resolve the TuiHost binding, the shared frame encoder, and the libtui.so
    # path. Returns {"ok": False} when the .so is unavailable so callers can skip.
    host_mod = importlib.import_module("jaclang.cli.ai_tui.tui_host");
    shared_mod = importlib.import_module("jaclang.cli.ai_tui.tui_shared");
    pkg_root = Path(host_mod.__file__).resolve().parent.parent;

    ensure_lib = getattr(host_mod, "_ensure_tui_lib");
    lib_path_of = getattr(host_mod, "_tui_lib_path");
    # Build from NA sources on a dev checkout if the .so is missing; a no-op when
    # it already exists (the common case -- build.sh built it).
    try {
        ensure_lib(pkg_root);
    } except Exception { }

    lib_path = lib_path_of(pkg_root);
    if not os.path.exists(lib_path) {
        return {"ok": False};
    }
    return {
        "ok": True,
        "TuiHost": getattr(host_mod, "TuiHost"),
        "frame_blob": getattr(shared_mod, "_frame_blob"),
        "lib_path": lib_path,

    };
}


test "TuiHost binds libtui.so and the sv frame encoder round-trips the native parser" {
    import ctypes;

    env = _host_env();
    if not env["ok"] {
        return;  # libtui.so unavailable; native build gate owns .so production.
    }

    mark_user = "HELLOUSERMARKER";
    mark_answer = "HELLOANSWERMARKER";
    frame = {
        "full": True,
        "status": "running",
        "active": "",
        "model_name": "claude-opus-4-8",
        "needs_key": False,
        "key_env": "",
        "events": [
            {"id": 1, "kind": "user", "node": "", "text": mark_user},
            {"id": 2, "kind": "answer", "node": "", "text": mark_answer},

        ],

    };
    blob = env["frame_blob"](frame);

    host = env["TuiHost"]();
    host.load(env["lib_path"]);

    rc = host.apply_frame(blob);
    assert rc == 0 , f"tui_apply_frame should return 0, got {rc}";

    # tui_render_buf (fd=-1 headless paint) is the Phase-1 gate symbol, not one of
    # the eight seam exports TuiHost.load() binds -- reach it through host.lib.
    host.lib.tui_render_buf.restype = ctypes.c_char_p;
    host.lib.tui_render_buf.argtypes = [];
    raw = host.lib.tui_render_buf();
    screen = (raw or b"").decode("utf-8", "replace");
    assert mark_user in screen , f"user event text missing from rendered screen";
    assert mark_answer in screen , f"answer event text missing from rendered screen";

    # A pure frame apply enqueues no commands; quit is unset.
    assert host.next_command() == "" , "pull queue should be empty after a frame apply";
    assert host.quit_requested() == 0 , "quit must be unset before any quit key/command";
}


test "TuiHost drives a real pty: typing hi+Enter yields SEND:hi" {
    env = _host_env();
    if not env["ok"] {
        return;  # libtui.so unavailable.
    }

    # openpty gives an isolated master/slave pair, independent of any controlling
    # terminal, so this runs headlessly (and skips where the sandbox forbids it).
    try {
        (controller_fd, follower_fd) = os.openpty();
    } except Exception {
        return;  # no pty available in this environment; skip.
    }

    cmds: list = [];
    started = False;
    host = env["TuiHost"]();
    try {
        # Give the pty a real size so the native layout has room to render.
        try {
            import struct;
            import fcntl;
            import termios;
            winsz = struct.pack("HHHH", 24, 80, 0, 0);
            fcntl.ioctl(follower_fd, termios.TIOCSWINSZ, winsz);
        } except Exception { }

        # Don't let the native paint back-pressure on a full master buffer.
        try {
            os.set_blocking(controller_fd, False);
        } except Exception { }

        tty_dev = os.ttyname(follower_fd);
        host.load(env["lib_path"]);
        rc = host.start(os.getcwd(), "", "", tty_dev);
        assert rc == 0 , f"host.start should return 0 on the pty, got {rc}";
        started = True;

        # Type into the controller end; the native side (follower) reads it. Enter
        # is CR ("\r", code 13) per input.na.jac -> editor_submit -> SEND:.
        os.write(controller_fd, b"hi\r");

        # Mirror the in-process ticker: poll, dispatch one key, drain the queue,
        # render. Bounded (<=40 * 50ms = 2s) so a missed key can never hang.
        i = 0;
        while i < 40 {
            n = host.wait_key(50);
            if n > 0 {
                host.handle_key();
                while True {
                    c = host.next_command();
                    if not c {
                        break;
                    }
                    cmds.append(c);
                }
            }
            host.render();
            # Drain the paint so the master buffer never fills.
            try {
                os.read(controller_fd, 65536);
            } except Exception { }
            if "SEND:hi" in cmds {
                break;
            }
            i += 1;
        }
    } finally {
        if started {
            try {
                host.shutdown();
            } except Exception { }
        }
        try {
            os.close(controller_fd);
        } except Exception { }
        try {
            os.close(follower_fd);
        } except Exception { }
    }

    assert "SEND:hi" in cmds , f"typing hi+Enter must enqueue SEND:hi; got {cmds!r}";
}


test "TuiHost gated render repaints on a status-only frame (dirty invariant)" {
    # Regression for the repaint invariant: a frame that changes only header/
    # footer status fields (no transcript event) must still repaint through the
    # *gated* render path (tui_render -> tui_render_once, which keys solely on
    # `state.dirty`). The bug it guards: status fields were written without
    # marking dirty, so the screen went stale until the next keystroke. This
    # exercises the real tty path (tui_render_buf forces dirty and would mask it).
    env = _host_env();
    if not env["ok"] {
        return;  # libtui.so unavailable.
    }

    try {
        (controller_fd, follower_fd) = os.openpty();
    } except Exception {
        return;  # no pty available in this environment; skip.
    }

    started = False;
    host = env["TuiHost"]();
    try {
        try {
            import struct;
            import fcntl;
            import termios;
            winsz = struct.pack("HHHH", 24, 80, 0, 0);
            fcntl.ioctl(follower_fd, termios.TIOCSWINSZ, winsz);
        } except Exception { }
        try {
            os.set_blocking(controller_fd, False);
        } except Exception { }

        host.load(env["lib_path"]);
        rc = host.start(os.getcwd(), "", "", os.ttyname(follower_fd));
        assert rc == 0 , f"host.start should return 0 on the pty, got {rc}";
        started = True;

        # Drain the startup paint so `dirty` is clear; once settled the gated
        # render must report idle (nothing left to paint).
        i = 0;
        while i < 5 {
            host.render();
            try {
                os.read(controller_fd, 65536);
            } except Exception { }
            i += 1;
        }
        assert host.render() == 0 , "gated render should be idle once the startup paint is drained";

        # A status-only delta frame (no events) -- the exact case that used to
        # leave the gate unmarked.
        blob = env["frame_blob"]({"status": "running"});
        assert host.apply_frame(blob) == 0 , "apply_frame should accept a status-only frame";
        assert host.render() == 1 , "a status-only frame must repaint via the gated render path";
    } finally {
        if started {
            try {
                host.shutdown();
            } except Exception { }
        }
        try {
            os.close(controller_fd);
        } except Exception { }
        try {
            os.close(follower_fd);
        } except Exception { }
    }
}


test "TuiHost repaints on a rows-only terminal resize (_sync_size dirty invariant)" {
    # Regression for _sync_size: a purely VERTICAL resize (rows change, cols
    # unchanged) leaves line wrapping intact but resizes the viewport that
    # screen_render paints, so it must still mark `dirty` and repaint. The bug it
    # guards: _sync_size only marked dirty on a column change, so a rows-only
    # resize went stale. tui_render re-syncs size each tick (the in-process host
    # has no SIGWINCH handler), which is the seam this exercises.
    import struct;
    import fcntl;
    import termios;

    env = _host_env();
    if not env["ok"] {
        return;  # libtui.so unavailable.
    }

    try {
        (controller_fd, follower_fd) = os.openpty();
    } except Exception {
        return;  # no pty available in this environment; skip.
    }

    started = False;
    host = env["TuiHost"]();
    try {
        try {
            fcntl.ioctl(
                follower_fd, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 0, 0)
            );
        } except Exception {
            return;  # cannot size the pty; skip rather than assert on a no-op.
        }
        try {
            os.set_blocking(controller_fd, False);
        } except Exception { }

        host.load(env["lib_path"]);
        rc = host.start(os.getcwd(), "", "", os.ttyname(follower_fd));
        assert rc == 0 , f"host.start should return 0 on the pty, got {rc}";
        started = True;

        # Settle the startup paint so the gate is clear (render reports idle).
        i = 0;
        while i < 5 {
            host.render();
            try {
                os.read(controller_fd, 65536);
            } except Exception { }
            i += 1;
        }
        assert host.render() == 0 , "gated render should be idle once the startup paint is drained";

        # Rows-only resize: cols stay 80, rows go 24 -> 30. The old _sync_size
        # marked nothing dirty here, so render would stay idle (the bug).
        fcntl.ioctl(follower_fd, termios.TIOCSWINSZ, struct.pack("HHHH", 30, 80, 0, 0));
        assert host.render() == 1 , "a rows-only resize must repaint via the gated render path";
    } finally {
        if started {
            try {
                host.shutdown();
            } except Exception { }
        }
        try {
            os.close(controller_fd);
        } except Exception { }
        try {
            os.close(follower_fd);
        } except Exception { }
    }
}
