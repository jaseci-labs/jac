import from .libc_tty {
    tty_write,
    tty_poll,
    tty_stdin_ready,
    tty_key_ready,
    tty_read_key,
    tty_read_line
}
import from .ipc_schema { IPC_LEN, IPC_SEP }

obj CmdQueue {
    has _items: list[str] = [],
        _cursor: int = 0;

    def send(fd: int, cmd: str) {
        if fd < 0 {
            self._items.append(cmd);
            return;
        }
        tty_write(fd, cmd + "\n");
    }

    def drain -> str {
        if self._cursor >= len(self._items) {
            self._items = [];
            self._cursor = 0;
            return "";
        }
        cmd = self._items[self._cursor];
        self._cursor = self._cursor + 1;
        return cmd;
    }

    def clear {
        self._items = [];
        self._cursor = 0;
    }
}

obj Transport {
    def poll(timeout_ms: int) { }
    def key_ready -> int {
        return 0;
    }

    def read_key -> str {
        return "";
    }

    def recv_blob -> str {
        return "";
    }

    def send_cmd(cmd: str) { }
    def flush_outbound_cmds { }
    def stdin_eof -> bool {
        return False;
    }
}

obj TtyFdTransport(Transport) {
    has stdin_eof: bool = False;

    def poll(timeout_ms: int) {
        tty_poll(timeout_ms);
    }

    def key_ready -> int {
        return tty_key_ready();
    }

    def read_key -> str {
        return tty_read_key();
    }

    def recv_blob -> str {
        if tty_stdin_ready() <= 0 {
            return "";
        }
        raw = tty_read_line();
        if len(raw) == 0 {
            self.stdin_eof = True;
            return "";
        }

        first = raw.strip();
        expected_lines: int = -1;
        colon_at = first.find(":");
        if colon_at >= 0 and first[:colon_at] == IPC_LEN {
            try {
                expected_lines = int(first[colon_at + 1:]);
            } except Exception { }
        }
        blob: str = "";
        if expected_lines >= 0 {
            n: int = 0;
            while n < expected_lines {
                raw2 = tty_read_line();
                if len(raw2) == 0 {
                    self.stdin_eof = True;
                    return "";
                }
                line = raw2.strip();
                if len(blob) > 0 {
                    blob = blob + "\n";
                }
                blob = blob + line;
                n = n + 1;
            }
            tty_read_line();
        } else {
            if first != IPC_SEP and len(first) > 0 {
                blob = first;
            }
            while True {
                raw2 = tty_read_line();
                if len(raw2) == 0 {
                    break;
                }
                line = raw2.strip();
                if line == IPC_SEP {
                    break;
                }
                if len(line) > 0 {
                    if len(blob) > 0 {
                        blob = blob + "\n";
                    }
                    blob = blob + line;
                }
            }
        }
        return blob;
    }

    def send_cmd(cmd: str) { }
}

obj ExternalDriverTransport(TtyFdTransport) {
    def recv_blob -> str {
        return "";
    }
}
