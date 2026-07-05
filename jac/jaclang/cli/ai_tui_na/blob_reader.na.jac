import from .ipc_schema { FIELD_LEN, FRAME_SEP }
import from .libc_tty { tty_read_line }

obj BlobResult {
    has text: str = "",
        eof: bool = False;
}

def read_blob(first_line: str) -> BlobResult {
    expected_lines: int = -1;
    colon_at = first_line.find(":");
    if colon_at >= 0 and first_line[:colon_at] == FIELD_LEN {
        try {
            expected_lines = int(first_line[colon_at + 1:]);
        } except Exception { }
    }

    blob: str = "";

    if expected_lines >= 0 {
        n: int = 0;
        while n < expected_lines {
            raw = tty_read_line();
            if len(raw) == 0 {
                return BlobResult(text=blob, eof=True);
            }
            line = raw.strip();
            if len(blob) > 0 {
                blob = blob + "\n";
            }
            blob = blob + line;
            n = n + 1;
        }

        sep = tty_read_line();
        if len(sep) == 0 {
            return BlobResult(text=blob, eof=True);
        }
    } else {
        if first_line != FRAME_SEP and len(first_line) > 0 {
            blob = first_line;
        }
        while True {
            raw = tty_read_line();
            if len(raw) == 0 {
                return BlobResult(text=blob, eof=True);
            }
            line = raw.strip();
            if line == FRAME_SEP {
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
    return BlobResult(text=blob, eof=False);
}
