import from .libc_tty {
    tty_write,
    tty_poll,
    tty_stdin_ready,
    tty_key_ready,
    tty_read_key,
    tty_read_line
}
import from .blob_reader { read_blob }
import from .ipc_schema { FRAME_SEP, FIELD_LEN }
import from .util { parse_int_or, split_kv }
import from .state { TuiState }

# Phase 4: CPython/GIL ownership moved to embed_runtime.na.jac. This module is
# tty I/O + command buffering only.


def split_frames(payload: str) -> list[str] {
    # Legacy L:<n> re-segmentation retained for development fallback only.
    frames: list[str] = [];
    lines = payload.split("\n");
    total = len(lines);
    i: int = 0;
    while i < total {
        header = lines[i].strip();
        i += 1;
        if not header {
            continue;
        }
        (key, val) = split_kv(header, ":");
        if key != FIELD_LEN {
            continue;
        }
        count = parse_int_or(val, -1);
        if count < 0 {
            continue;
        }
        body: list[str] = [];
        taken: int = 0;
        while taken < count and i < total {
            body.append(lines[i]);
            i += 1;
            taken += 1;
        }
        if i < total and lines[i].strip() == FRAME_SEP {
            i += 1;
        }
        frames.append("\n".join(body));
    }
    return frames;
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
    def poll_gil(timeout_ms: int) { }

    def key_ready -> bool {
        return False;
    }

    def read_key -> str {
        return "";
    }

    def recv_blob -> str {
        return "";
    }

    def recv_frames(cap: int) -> list[str] {
        out: list[str] = [];
        for _ in range(cap) {
            blob = self.recv_blob();
            if self.stdin_eof() {
                break;
            }
            if not blob {
                break;
            }
            out.append(blob);
        }
        return out;
    }

    def flush_outbound_cmds(cmd_queue: CmdQueue, state: TuiState) { }
    def stdin_eof -> bool {
        return False;
    }

    def backend_dead -> bool {
        return False;
    }
}

obj TtyFdTransport(Transport) {
    has stdin_eof: bool = False;

    def poll(timeout_ms: int) {
        tty_poll(timeout_ms);
    }

    def poll_gil(timeout_ms: int) {
        # Call tty_poll directly — avoid Transport.poll_gil -> self.poll virtual
        # dispatch (segfault on some native builds right after alt-screen enter).
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
    # Concrete TUI transport type (tty keys + poll). Session poll/submit live on
    # EmbedSessionClient; this class no longer holds PyObject* or GIL state.
    has _backend_dead: bool = False;

    def backend_dead -> bool {
        return self._backend_dead;
    }

    def mark_backend_dead {
        self._backend_dead = True;
    }
}
