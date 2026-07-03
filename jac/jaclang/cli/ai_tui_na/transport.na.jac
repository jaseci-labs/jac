import from .libc_tty {
    tty_write,
    tty_poll,
    tty_stdin_ready,
    tty_key_ready,
    tty_read_key,
    tty_read_line
}
import from .blob_reader { read_blob }

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
        result = read_blob(first);
        if result.eof {
            self.stdin_eof = True;
        }
        return result.text;
    }

    def send_cmd(cmd: str) { }
}
