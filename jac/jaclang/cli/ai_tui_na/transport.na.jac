import from .libc_tty {
    tty_poll,
    tty_stdin_ready,
    tty_key_ready,
    tty_read_key,
    tty_read_line
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
        blob: str = "";
        line = raw.strip();
        if line == "---" {
            return "";
        }
        if len(line) > 0 {
            blob = line;
        }
        while True {
            raw = tty_read_line();
            if len(raw) == 0 {
                break;
            }
            line = raw.strip();
            if line == "---" {
                break;
            }
            if len(line) > 0 {
                if len(blob) > 0 {
                    blob = blob + "\n";
                }
                blob = blob + line;
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
