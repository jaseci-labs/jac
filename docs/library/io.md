---
description: The native io module, as CPython's io - open, the file classes (FileIO, BufferedReader, BufferedWriter, BufferedRandom, TextIOWrapper), the in-memory streams and the stream base classes.
keywords: io, io.open, io.open_code, io.text_encoding, io.StringIO, StringIO, io.BytesIO, BytesIO, io.IOBase, io.RawIOBase, io.TextIOBase, io.BufferedIOBase, io.FileIO, io.BufferedReader, io.BufferedWriter, io.BufferedRandom, io.BufferedRWPair, io.TextIOWrapper, TextIOWrapper, io.IncrementalNewlineDecoder, io.UnsupportedOperation, io.SEEK_SET, io.SEEK_CUR, io.SEEK_END, io.DEFAULT_BUFFER_SIZE, in-memory stream, file object
---
# io

`io` is CPython's `io`: the file classes, layered as CPython layers them (a raw `FileIO` under a
buffered reader or writer under a `TextIOWrapper`), the in-memory streams `StringIO` and
`BytesIO`, and the base classes a stream of a program's own inherits, with CPython's positions,
buffering, newline handling, exceptions and messages. The builtin `open` is `io.open` (see
[Builtin functions](builtins.md), `jac docs open`), and `sys.stdin`, `sys.stdout` and
`sys.stderr` are `TextIOWrapper`s. It is native (see [The library](index.md),
`jac docs library`).

```jac
import io;
import sys;

with entry {
    buf = io.StringIO();
    buf.write("first line\n");
    print("second", 2, file=buf);
    print(repr(buf.getvalue()), buf.tell());
    buf.seek(0);
    print(buf.readline().strip(), "|", buf.read().strip());
    b = io.BytesIO(b"hello");
    b.seek(0, io.SEEK_END);
    b.write(b" world");
    print(b.getvalue(), b.tell());
    saved = sys.stdout;
    captured = io.StringIO();
    sys.stdout = captured;
    print("captured");
    sys.stdout = saved;
    print(repr(captured.getvalue()));
}
```

```output
'first line\nsecond 2\n' 20
first line | second 2
b'hello world' 11
'captured\n'
```

## What is there

| Name | What it is |
|---|---|
| `open(file, mode="r", buffering=-1, encoding=None, errors=None, newline=None, closefd=True, opener=None)` | Opens a file, by path or by file descriptor; the builtin `open` |
| `FileIO(file, mode="r", closefd=True, opener=None)` | A file as raw bytes, read and written by the system's calls; `name`, `mode`, `closefd`, `readinto`, `readall` |
| `BufferedReader(raw, buffer_size=DEFAULT_BUFFER_SIZE)` | Reads a raw stream through a buffer: `read`, `read1`, `peek`, `readinto`, `readline`, `seek`, ... |
| `BufferedWriter(raw, buffer_size=...)`, `BufferedRandom(raw, buffer_size=...)` | Writes through a buffer; `BufferedRandom` reads and writes one seekable stream |
| `BufferedRWPair(reader, writer)` | A reader and a writer, two raw streams, as one stream |
| `TextIOWrapper(buffer, encoding=None, errors=None, newline=None, line_buffering=False, write_through=False)` | Text over a buffered stream, in any encoding of [`codecs`](codecs.md); `reconfigure`, `detach`, `encoding`, `errors`, `newlines`, `buffer` |
| `IncrementalNewlineDecoder(decoder, translate, errors="strict")` | Translates `\r\n` and `\r` to `\n` across chunks |
| `StringIO(initial_value="", newline="\n")` | A text stream in memory: `write`, `writelines`, `read`, `readline`, `readlines`, iteration, `seek`, `tell`, `truncate`, `getvalue`, `close`, `closed`, `newlines`, and `with` |
| `BytesIO(initial_bytes=b"")` | A binary stream in memory: the same, and `read1`, `readinto`, `getbuffer` (a writable view of the contents) |
| `IOBase`, `RawIOBase`, `BufferedIOBase`, `TextIOBase` | Base classes a program's class inherits to be a stream |
| `open_code(path)`, `text_encoding(encoding, stacklevel=2)` | A file opened to read as code (`"rb"`); the encoding `open` uses for `None` (`"utf-8"`) |
| `UnsupportedOperation` | Both an `OSError` and a `ValueError`, as in CPython |
| `BlockingIOError` | The builtin `BlockingIOError` |
| `SEEK_SET`, `SEEK_CUR`, `SEEK_END`, `DEFAULT_BUFFER_SIZE` | Constants; the buffer size is 128 KiB, as in CPython 3.15 |

```jac
import io;

with entry {
    raw = io.FileIO("data.bin", "w");
    print(raw.write(b"0123456789"), raw.mode, raw.name);
    raw.close();
    with io.open("data.bin", "rb") as reader {
        print(type(reader).__name__, reader.read(4), reader.peek(2)[:2], reader.tell());
    }
    with open("data.bin", "r+b") as both {
        both.seek(2);
        both.write(b"ab");
        both.seek(0);
        print(both.read());
    }
    text = io.TextIOWrapper(io.BytesIO(b"caf\xc3\xa9\r\nline two\n"), encoding="utf-8");
    print(text.readlines(), text.encoding);
    dec = io.IncrementalNewlineDecoder(None, translate=True);
    print(repr(dec.decode("a\r")), repr(dec.decode("\nb", final=True)));
    print(io.text_encoding(None), io.DEFAULT_BUFFER_SIZE);
    try {
        io.StringIO("x").fileno();
    } except io.UnsupportedOperation as e {
        print("UnsupportedOperation:", e);
    }
}
```

```output
10 wb data.bin
BufferedReader b'0123' b'45' 4
b'01ab456789'
['café\n', 'line two\n'] utf-8
'a' '\nb'
utf-8 131072
UnsupportedOperation: fileno
```

As in CPython:

- A `StringIO`'s positions count characters, for any text. Writing after a seek past the end
  pads with `"\x00"`. `truncate(n)` does not move the position. `seek` of a text stream relative
  to the current position or the end takes only an offset of 0
  (`OSError: Can't do nonzero cur-relative seeks`).
- `newline=None` reads `"\r\n"` and `"\r"` as `"\n"` and records them in `newlines`;
  `newline=""` keeps them and splits lines at each; `newline="\r\n"` writes `"\n"` as `"\r\n"`.
- Every operation on a closed stream raises `ValueError: I/O operation on closed file`; closing
  twice is allowed. A stream that has no descriptor raises `UnsupportedOperation` from
  `fileno()`.
- Standard output is written out at each line when it is a terminal, and as its buffer fills
  otherwise (a pipe, a file); standard error at each line. Both are written out as the program
  ends. Call `sys.stdout.flush()`, or `print(..., flush=True)`, where another process must see
  the output at once.
- Building output with `StringIO` and calling `getvalue()` once is linear in the text written.

## Writing a stream of your own

A class that inherits `io.TextIOBase` and defines `write` (and `writable`) can be passed as
`print(..., file=...)` and assigned to `sys.stdout`, and gets `writelines` from the base. One that
inherits `io.BufferedIOBase` and defines `read` and `read1` gets `readline`, `readlines`,
`readinto` and iteration. A base method the class does not define raises `UnsupportedOperation`.

```jac
import io;

obj Upper(io.TextIOBase) {
    has parts: list[str] = [];

    override def writable -> bool {
        return True;
    }

    override def write(s: str) -> int {
        self.parts.append(s.upper());
        return len(s);
    }
}

with entry {
    u = Upper();
    print("shout", "this", file=u);
    u.writelines(["a", "b"]);
    print(repr("".join(u.parts)));
}
```

```output
'SHOUT THIS\nAB'
```

## Differences from CPython

- **`open` with a mode known only as the program runs gives an `any`**, and an `any` is not a
  context manager: close it with `close()`. With a literal mode it is the class that mode opens,
  statically typed.
- **What `io` leaves out on purpose** is refused with E5142, with what to write instead:
  `Reader` and `Writer` (Protocols: a Jac class has the types it inherits, so annotate with
  `io.BufferedIOBase`, `io.TextIOBase` or `io.RawIOBase`), and `StringIO.name` and
  `BytesIO.name` (CPython's have none; the stub declares them for subclasses).
