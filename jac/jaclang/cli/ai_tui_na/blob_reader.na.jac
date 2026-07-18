import from .ipc_schema { FIELD_LEN, FRAME_SEP }
import from .libc_tty { tty_read_line }
import from .util { parse_int_or, split_kv }


obj BlobResult {
    has text: str = "",
        eof: bool = False;
}


def read_blob(first_line: str) -> BlobResult {
    count = _counted_body_lines(first_line);
    if count is not None {
        return _read_counted(count);
    }
    return _read_terminated(first_line);
}


def _counted_body_lines(first_line: str) -> (int | None) {
    (key, value) = split_kv(first_line, ":");
    if key != FIELD_LEN {
        return None;
    }
    count = parse_int_or(value, -1);
    if count < 0 {
        return None;
    }
    return count;
}


def _blob(parts: list[str], eof: bool) -> BlobResult {
    return BlobResult(text="\n".join(parts), eof=eof);
}


def _read_counted(count: int) -> BlobResult {
    parts: list[str] = [];
    for i in range(count) {
        raw = tty_read_line();
        if not raw {
            return _blob(parts, True);
        }
        line = raw.strip();
        if parts or line {
            parts.append(line);
        }
    }
    sep = tty_read_line();
    if not sep {
        return _blob(parts, True);
    }
    return _blob(parts, False);
}


def _read_terminated(first_line: str) -> BlobResult {
    parts: list[str] = [];
    if first_line and first_line != FRAME_SEP {
        parts.append(first_line);
    }
    while True {
        raw = tty_read_line();
        if not raw {
            return _blob(parts, True);
        }
        line = raw.strip();
        if line == FRAME_SEP {
            break;
        }
        if line {
            parts.append(line);
        }
    }
    return _blob(parts, False);
}
