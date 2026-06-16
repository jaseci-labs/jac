#!/usr/bin/env python
# ruff: noqa: T201, SIM105
"""Phase 3 smoke test: boot the JS sidecar with a real controlling tty (so
`/dev/tty` resolves) while stdin/stdout stay the protocol pipes, push a frame
that exercises every transcript kind, then close stdin to trigger clean teardown.

Asserts: exit 0, the seed `SEND:` lands on the command pipe (stdout), and no
exception text leaks to stderr (i.e. render_full ran against the live
OptimizedBuffer without throwing).
"""

import fcntl
import os
import pty
import select
import subprocess
import sys
import termios
import time

HERE = os.path.dirname(os.path.abspath(__file__))
MAIN = os.path.join(HERE, "dist", "main.js")

FRAME = (
    "TYPE:full\n"
    "STATUS:running\n"
    "ACTIVE:Build\n"
    "MODEL:claude-opus-4-8\n"
    "NEEDS_KEY:1\n"
    "KEY_ENV:ANTHROPIC_API_KEY\n"
    "EV:1:user:: hello there\n"
    "EV:2:reasoning:: thinking about it\n"
    "EV:3:phase:Build:Build phase\n"
    "EV:4:call:: read_file(path=x)\n"
    "EV:5:tool_result:: ok 42 lines\n"
    "EV:6:answer:: here is the answer that is quite long " + ("blah " * 40) + "\n"
    "EV:7:error:: something failed\n"
    "---\n"
)


def main() -> int:
    master_fd, slave_fd = pty.openpty()
    # Give the pty a sane size so the renderer lays out a full screen.
    try:
        fcntl.ioctl(
            slave_fd,
            termios.TIOCSWINSZ,
            __import__("struct").pack("HHHH", 40, 120, 0, 0),
        )
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

    cmds = b""
    deadline = time.time() + 6.0

    # Push the frame, then read commands while draining the pty (render output).
    os.write(stdin_w, FRAME.encode())

    # Read the seed SEND + any frame-driven commands for a moment.
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
    os.close(stdin_w)

    # Keep draining the pty so destroy()'s ANSI writes don't block on a full pipe.
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
