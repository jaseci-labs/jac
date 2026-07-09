"""Transport layer: how the TUI loop reaches its agent host.

CmdQueue buffers outbound IPC commands until a transport can flush them.
Transport is the polymorphic surface tui_loop drives (poll / keys / blobs /
command flush) with deliberate no-op defaults; TtyFdTransport speaks the raw
tty + stdin path; EmbedPyTransport bridges to an in-process CPython agent
through raw PyObject* handles (plain ints, 0 = null) with explicit
refcounting.
"""
import from .libc_tty {
    tty_write,
    tty_poll,
    tty_stdin_ready,
    tty_key_ready,
    tty_read_key,
    tty_read_line
}
import from .blob_reader { read_blob }

import from jacpyembed {
    def jpy_PyEval_SaveThread -> int;  def jpy_PyEval_RestoreThread(s: int) -> None;  def jpy_PyObject_CallNoArgs(
        fn: int
    ) -> int;  def jpy_PyObject_CallOneArg(fn: int, arg: int) -> int;  def jpy_PyUnicode_FromString(
        s: str
    ) -> int;  def jpy_PyUnicode_AsUTF8(pyobj: int) -> str;  def jpy_Py_DecRef(
        pyobj: int
    ) -> None;
}

"""Outbound command buffer: commands go straight to the IPC fd when one is
open, otherwise they queue here until a transport flushes the backlog."""
obj CmdQueue {
    has _items: list[str] = [];

    """Send one command: newline-terminated fd write, or buffered when fd < 0."""
    def send(fd: int, cmd: str) {
        if fd < 0 {
            self._items.append(cmd);
            return;
        }
        tty_write(fd, cmd + "\n");
    }

    """Take ownership of every buffered command (in order), emptying the queue."""
    def drain_all -> list[str] {
        pending: list[str] = self._items;
        self._items = [];
        return pending;
    }

    """Drop any buffered commands."""
    def clear {
        self._items = [];
    }
}

"""Host surface driven by tui_loop. Defaults are deliberate no-ops (not
abstract) so subclasses override only the paths their host supports."""
obj Transport {
    def poll(timeout_ms: int) { }
    """GIL-aware poll; the base variant has no interpreter to release."""
    def poll_gil(timeout_ms: int) {
        self.poll(timeout_ms);
    }

    def key_ready -> bool {
        return False;
    }

    def read_key -> str {
        return "";
    }

    def recv_blob -> str {
        return "";
    }

    def send_cmd(cmd: str) { }
    def flush_outbound_cmds(cmd_queue: CmdQueue) { }
    # FROZEN na quirk: tui_loop invokes rt.transport.stdin_eof() as a method
    # while TtyFdTransport shadows this def with a bool has-field that
    # recv_blob writes. On na this def+field pairing is exactly what makes
    # both the call site and the field writes resolve; unifying to
    # field-only or method-only breaks EOF detection. Keep both as is.
    def stdin_eof -> bool {
        return False;
    }
}

"""Raw-terminal host: keys and agent blobs both arrive over tty/stdin fds."""
obj TtyFdTransport(Transport) {
    # Shadows base `def stdin_eof` on purpose — see the FROZEN note above.
    has stdin_eof: bool = False;

    def poll(timeout_ms: int) {
        tty_poll(timeout_ms);
    }

    def key_ready -> bool {
        return tty_key_ready();
    }

    def read_key -> str {
        return tty_read_key();
    }

    """Read one agent frame from stdin; latches stdin_eof on end-of-stream."""
    def recv_blob -> str {
        if not tty_stdin_ready() {
            return "";
        }
        raw = tty_read_line();
        if not raw {
            self.stdin_eof = True;
            return "";
        }

        line = raw.strip();
        result = read_blob(line);
        if result.eof {
            self.stdin_eof = True;
        }
        return result.text;
    }

    def send_cmd(cmd: str) { }
}

"""In-process CPython host: poll/send are agent callables held as raw
PyObject* int handles (0 = null). Handles adopted in bind_py are released
exactly once in close_py; per-call temporaries are DecRef'd at their call
site."""
obj EmbedPyTransport(TtyFdTransport) {
    has py_poll_fn: int = 0,
        py_send_fn: int = 0;

    """Adopt the agent's poll/send callables (ref ownership transfers here).

    dict_ptr is the host __main__ module dict — a borrowed reference kept
    alive by the interpreter itself, so it is accepted for call symmetry
    but not stored.
    """
    def bind_py(dict_ptr: int, poll_fn: int, send_fn: int) {
        self.py_poll_fn = poll_fn;
        self.py_send_fn = send_fn;
        self.stdin_eof = False;
    }

    """Release both retained callables; idempotent."""
    def close_py {
        self.py_poll_fn = self._released(self.py_poll_fn);
        self.py_send_fn = self._released(self.py_send_fn);
    }

    """DecRef a retained handle if non-null; returns the cleared handle (0)."""
    def _released(handle: int) -> int {
        if handle != 0 {
            jpy_Py_DecRef(handle);
        }
        return 0;
    }

    """Poll with the GIL released so embedded agent threads can make progress."""
    def poll_gil(timeout_ms: int) {
        ts: int = jpy_PyEval_SaveThread();
        try {
            self.poll(timeout_ms);
        } finally {
            jpy_PyEval_RestoreThread(ts);
        }
    }

    """Ask the agent's poll callable for the next frame ("" when idle)."""
    def recv_blob -> str {
        if self.py_poll_fn == 0 {
            return "";
        }
        pyobj: int = jpy_PyObject_CallNoArgs(self.py_poll_fn);
        if pyobj == 0 {
            return "";
        }
        out: str = jpy_PyUnicode_AsUTF8(pyobj);
        jpy_Py_DecRef(pyobj);
        return out;
    }

    """Hand every queued command to the agent's send callable, in order."""
    def flush_outbound_cmds(cmd_queue: CmdQueue) {
        if self.py_send_fn == 0 {
            cmd_queue.clear();
            return;
        }
        for cmd in cmd_queue.drain_all() {
            arg: int = jpy_PyUnicode_FromString(cmd);
            if arg != 0 {
                res: int = jpy_PyObject_CallOneArg(self.py_send_fn, arg);
                if res != 0 {
                    jpy_Py_DecRef(res);
                }
                jpy_Py_DecRef(arg);
            }
        }
    }
}
