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

obj CmdQueue {
    has _items: list[str] = [];

    def send(fd: int, cmd: str) {
        if fd < 0 {
            self._items.append(cmd);
            return;
        }
        tty_write(fd, cmd + "\n");
    }

    def drain_all -> list[str] {
        pending: list[str] = self._items;
        self._items = [];
        return pending;
    }

    def clear {
        self._items = [];
    }
}

obj Transport {
    def poll(timeout_ms: int) { }
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

    def flush_outbound_cmds(cmd_queue: CmdQueue) { }
    def stdin_eof -> bool {
        return False;
    }
}

obj TtyFdTransport(Transport) {
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
}

obj EmbedPyTransport(TtyFdTransport) {
    has py_poll_fn: int = 0,
        py_send_fn: int = 0;

    def bind_py(dict_ptr: int, poll_fn: int, send_fn: int) {
        self.py_poll_fn = poll_fn;
        self.py_send_fn = send_fn;
        self.stdin_eof = False;
    }

    def close_py {
        self.py_poll_fn = self._released(self.py_poll_fn);
        self.py_send_fn = self._released(self.py_send_fn);
    }

    def _released(handle: int) -> int {
        if handle != 0 {
            jpy_Py_DecRef(handle);
        }
        return 0;
    }

    def poll_gil(timeout_ms: int) {
        ts: int = jpy_PyEval_SaveThread();
        try {
            self.poll(timeout_ms);
        } finally {
            jpy_PyEval_RestoreThread(ts);
        }
    }

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
