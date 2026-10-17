"""A `struct.unpack` result stored where its declared type lives.

Native `struct.unpack`/`unpack_from` build a fixed-arity tuple, but the
functions are typed `tuple[Any, ...]`, and an entry-block name or an
annotated local takes the declared, variadic shape: a boxed sequence. The
store used to bitcast the tuple into that sequence, so `len` read the first
float's bits as the length and slices came back empty.
"""
import struct;

with entry {
    r = struct.unpack_from("<2f", struct.pack("<2f", 1.5, 2.5), 0);
    zeros = struct.unpack_from("<2f", bytearray(8), 0);
    mixed = struct.unpack("<if", struct.pack("<if", 7, 2.5));
}

def entry_len -> int {
    return len(r);
}

def entry_second -> float {
    v: float = r[1];
    return v;
}

def entry_head_len -> int {
    return len(list(r[0:1]));
}

def entry_head -> float {
    head = list(r[0:1]);
    v: float = head[0];
    return v;
}

def zeros_head_len -> int {
    return len(list(zeros[0:1]));
}

def mixed_sum -> float {
    n: int = mixed[0];
    x: float = mixed[1];
    return n + x + len(mixed);
}

def local_tail_len -> int {
    t: tuple[any, ...] = struct.unpack("<3f", struct.pack("<3f", 1.0, 2.0, 3.0));
    return len(t[1:]);
}

obj Escape {
    has metadata: str | None = None;
}

def narrowed_str_tail -> int {
    tok = Escape(metadata="escape:abc");
    if tok.metadata is not None and tok.metadata.startswith("escape:") {
        rest = tok.metadata[7:];
        return len(rest) if rest == "abc" else -1;
    }
    return -2;
}

def narrowed_is_not_none -> int {
    tok = Escape(metadata="escape:abc");
    return 1 if tok.metadata is not None else 0;
}

def narrowed_startswith -> int {
    tok = Escape(metadata="escape:abc");
    if tok.metadata is None {
        return -2;
    }
    return 1 if tok.metadata.startswith("escape:") else 0;
}

def narrowed_slice_len -> int {
    tok = Escape(metadata="escape:abc");
    if tok.metadata is None {
        return -2;
    }
    rest = tok.metadata[7:];
    return len(rest);
}

def narrowed_slice_eq -> int {
    tok = Escape(metadata="escape:abc");
    if tok.metadata is None {
        return -2;
    }
    rest = tok.metadata[7:];
    return 1 if rest == "abc" else 0;
}
