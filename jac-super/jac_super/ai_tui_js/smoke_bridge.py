#!/usr/bin/env python
# ruff: noqa: T201, SIM105, ANN202
"""Phase 4 integration smoke: exercise the *real bridge* against the *real js
sidecar*.

Unlike `smoke_render.py` (which writes a hand-authored frame literal), this drives
the actual control-plane serializer — `_write_frame` imported straight from
`jac_super.ai_agent.run_tui_session` — so it proves the python frame format the
bridge emits and the Jac `Protocol` parser the js sidecar runs still agree on the
wire. It also runs the cutover's default code path end to end: spawn the js
sidecar, stream a `full` frame in, read a command back.

Setup mirrors smoke_render.py: a real controlling tty (so `/dev/tty` resolves)
with stdin/stdout kept as the protocol pipes.

Asserts: exit 0, the seed `SEND:` lands on the command pipe, and no exception text
leaks to stderr (the sidecar parsed the bridge's frame and painted without
throwing).

Skips cleanly (exit 0, prints SKIP) when prerequisites are absent: `bun` not on
PATH, `dist/main.js` not built, or the jac bridge module can't be imported.
"""

import fcntl
import os
import pty
import select
import shutil
import struct
import subprocess
import sys
import termios
import time

HERE = os.path.dirname(os.path.abspath(__file__))
MAIN = os.path.join(HERE, "dist", "main.js")
# HERE = .../jac_super/ai_tui_js ; the importable `jac_super` package's parent is
# two levels up (.../jac-super), which must be on sys.path to import the bridge.
REPO_PKG_PARENT = os.path.dirname(os.path.dirname(HERE))

# A frame that exercises every transcript kind plus escaping (the embedded "\n"
# forces _esc_text -> the js unescape path) and NEEDS_KEY -> the warning row.
FRAME = {
    "full": True,
    "status": "running",
    "active": "Build",
    "model_name": "claude-opus-4-8",
    "needs_key": True,
    "key_env": "ANTHROPIC_API_KEY",
    "events": [
        {"id": 1, "kind": "user", "node": "", "text": "hello there"},
        {"id": 2, "kind": "reasoning", "node": "", "text": "thinking about it"},
        {"id": 3, "kind": "phase", "node": "Build", "text": "Build phase"},
        {"id": 4, "kind": "call", "node": "", "text": "read_file(path=x)"},
        {"id": 5, "kind": "tool_result", "node": "", "text": "ok 42 lines"},
        {
            "id": 6,
            "kind": "answer",
            "node": "",
            "text": "here is the answer that is quite long " + ("blah " * 40),
        },
        {
            "id": 7,
            "kind": "error",
            "node": "",
            "text": "something failed\non a second line",
        },
    ],
}


def _skip(msg: str) -> int:
    print(f"SKIP: {msg}")
    return 0


def _load_write_frame():
    import importlib

    import jaclang  # noqa: F401 -- registers the .jac import hook

    if REPO_PKG_PARENT not in sys.path:
        sys.path.insert(0, REPO_PKG_PARENT)
    mod = importlib.import_module("jac_super.ai_agent.run_tui_session")
    return mod._write_frame


def main() -> int:
    if shutil.which("bun") is None:
        return _skip("bun not on PATH")
    if not os.path.exists(MAIN):
        return _skip(f"js sidecar not built ({MAIN}); run `python build.py`")
    try:
        write_frame = _load_write_frame()
    except Exception as exc:  # noqa: BLE001
        return _skip(f"could not import bridge _write_frame: {exc!r}")

    master_fd, slave_fd = pty.openpty()
    try:
        fcntl.ioctl(slave_fd, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))
    except Exception:
        pass

    stdin_r, stdin_w = os.pipe()
    stdout_r, stdout_w = os.pipe()

    def set_ctty() -> None:
        os.setsid()
        fcntl.ioctl(slave_fd, termios.TIOCSCTTY, 0)

    proc = subprocess.Popen(
        ["bun", MAIN, "seed-prompt"],
        stdin=stdin_r,
        stdout=stdout_w,
        stderr=subprocess.PIPE,
        preexec_fn=set_ctty,
        pass_fds=(slave_fd,),
        cwd=HERE,
    )
    os.close(stdin_r)
    os.close(stdout_w)
    os.close(slave_fd)

    # Wrap the write end in a text file object so the bridge serializer can
    # .write()/.flush() exactly as it does against a real subprocess stdin.
    stdin_pipe = os.fdopen(stdin_w, "w")

    cmds = b""
    deadline = time.time() + 6.0

    # The genuine control-plane serializer emits the frame onto the pipe.
    write_frame(stdin_pipe, FRAME)

    while time.time() < deadline:
        rl, _, _ = select.select([stdout_r, master_fd], [], [], 0.2)
        if master_fd in rl:
            try:
                os.read(master_fd, 65536)  # drain renderer paint; ignore content
            except OSError:
                pass
        if stdout_r in rl:
            chunk = os.read(stdout_r, 65536)
            if not chunk:
                break
            cmds += chunk
            if b"SEND:seed-prompt" in cmds:
                break
        if proc.poll() is not None:
            break

    # Clean teardown: closing stdin fires readline "close" -> do_quit().
    try:
        stdin_pipe.close()
    except OSError:
        pass

    end = time.time() + 4.0
    while time.time() < end and proc.poll() is None:
        rl, _, _ = select.select([master_fd, stdout_r], [], [], 0.2)
        for fd in rl:
            try:
                data = os.read(fd, 65536)
                if fd is stdout_r:
                    cmds += data
            except OSError:
                pass

    try:
        rc = proc.wait(timeout=4.0)
    except subprocess.TimeoutExpired:
        proc.kill()
        rc = proc.wait()

    err = proc.stderr.read().decode(errors="replace") if proc.stderr else ""
    os.close(master_fd)
    os.close(stdout_r)

    cmd_text = cmds.decode(errors="replace")
    print(f"exit={rc}")
    print(f"--- commands (stdout) ---\n{cmd_text.strip()!r}")
    if err.strip():
        print(f"--- stderr ---\n{err.strip()}")

    ok = True
    if rc != 0:
        print(f"FAIL: non-zero exit {rc}")
        ok = False
    if "SEND:seed-prompt" not in cmd_text:
        print("FAIL: seed SEND not observed on command pipe")
        ok = False
    low = err.lower()
    for bad in ("error", "throw", "exception", "undefined is not", "typeerror"):
        if bad in low:
            print(f"FAIL: stderr contains {bad!r}")
            ok = False
            break
    print("PASS" if ok else "SMOKE FAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
