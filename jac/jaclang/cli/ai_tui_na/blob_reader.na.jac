"""Reader for agent frame bodies arriving line-by-line over the tty stdin fd.

Two framings, chosen by the frame's first line (vocabulary in ipc_schema):
- Counted: a header line "L:<n>" announces exactly n body lines, followed by
  one trailing separator line that is consumed but excluded from the body.
- Separator-terminated: the first line is already body text (unless blank or
  the separator itself); body lines follow until a lone FRAME_SEP.

Body lines are stripped. Counted framing keeps interior blank lines but not
leading ones; separator framing drops blank lines entirely. An empty raw
read means EOF on the fd (a blank body line still carries its newline) and
ends the frame early with whatever text accumulated so far.
"""
import from .ipc_schema { FIELD_LEN, FRAME_SEP }
import from .libc_tty { tty_read_line }
import from .util { parse_int_or, split_kv }


"""Body text of one frame, with eof=True when the stream ended mid-frame."""
obj BlobResult {
    has text: str = "",
        eof: bool = False;
}


"""Read one frame body given its already-consumed (stripped) first line.

Dispatches on framing: an "L:<n>" header selects counted reads; anything
else is separator-terminated with first_line as the first candidate body
line. eof=True in the result means the fd ended mid-frame.
"""
def read_blob(first_line: str) -> BlobResult {
    count = _counted_body_lines(first_line);
    if count is not None {
        return _read_counted(count);
    }
    return _read_terminated(first_line);
}


"""Parse a counted-framing header into its body line count.

Returns None unless first_line is FIELD_LEN, a colon, and a non-negative
int; anything else (e.g. "L:-2", "L:x", or another field) falls back to
separator-terminated framing.
"""
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


"""Join accumulated body lines into a BlobResult."""
def _blob(parts: list[str], eof: bool) -> BlobResult {
    return BlobResult(text="\n".join(parts), eof=eof);
}


"""Read a counted body: exactly count stripped lines, then the trailing
separator line. Blank lines add nothing while the body is still empty but
are kept as empty body lines afterwards.
"""
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


"""Read a separator-terminated body: stripped non-blank lines up to a lone
FRAME_SEP. first_line seeds the body unless it is blank or the separator.
"""
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
