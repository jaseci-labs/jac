"""Pointer reinterpret casts (`# jac:ignore[E1001]`) between an address and
a str, an obj, or a C struct, as js_engine and the CEF desktop shim use them.

Buffers come from `raw_alloc`, which zeroes a 32-byte header in front of the
address it hands out (like js_engine's io_alloc), so the refcount probes a
cast str makes stay inert."""

import from "libc.so.6" {
    def calloc(n: int, size: int) -> int;  def free(p: int) -> None;  def memcpy(
        dst: int, src: int, n: int
    ) -> int;  def strlen(s: str) -> int;  def write(
        fd: i32, buf: int, n: int
    ) -> int;  def writev(fd: i32, iov: int, count: i32) -> int;
}

import from "libc.so.6" {
    obj pair_t {
        has a: int = 0,
            b: int = 0;
    }  obj word_t {
        has lo: i32 = 0,
            hi: i32 = 0;
    }
}

"""Binary-compatible with struct iovec: { char* base, size_t len }."""
obj IoVec {
    has base: str = "",
        len: int = 0;
}

obj Holder {
    has data: str = "",
        size: int = 0;
}

def raw_alloc(n: int) -> int {
    return calloc(1, n + 32) + 32;
}

def raw_free(p: int) {
    free(p - 32);
}

"""Owned copy of the NUL-terminated bytes at `p` (js_engine's str_from_raw)."""
def copy_raw(p: int) -> str {
    tmp: str = p;  # jac:ignore[E1001] pointer reinterpret
    return "" + tmp;
}

"""The address of a str's bytes, used with an explicit length."""
def text_address(s: str) -> int {
    at: int = s;  # jac:ignore[E1001] pointer reinterpret
    return at;
}

def fill(text: str) -> int {
    buf: int = raw_alloc(64);
    memcpy(buf, text_address(text), strlen(text));
    return buf;
}

def holder_of(buf: int) -> Holder {
    made = Holder();
    made.data = buf;  # jac:ignore[E1001] pointer reinterpret
    made.size = 3;
    return made;
}

def read_pair(addr: int) -> int {
    view: pair_t = addr;
    return view.a * 10 + view.b;
}

def poke_pair(addr: int) {
    view: pair_t = addr;
    view.b = 9;
}

def pair_address(p: pair_t) -> int {
    return p;
}

def iov_count(addr: int) -> int {
    reader: IoVec = addr;  # jac:ignore[E1001] pointer reinterpret
    return reader.len;
}

with entry {
    buf = fill("hello");
    cast: str = buf;  # jac:ignore[E1001] pointer reinterpret
    print("cast", cast, len(cast));
    print("copy", copy_raw(buf));
    held = holder_of(buf);
    print("field", held.data, held.size);
    tail = "say " + "world"[1:];
    write(1, tail, len(tail));
    write(1, "\n", 1);
    print("slice", copy_raw(fill("abcdef"[2:])));
    raw_free(buf);

    vec = IoVec(base="iov ok\n", len=7);
    writev(1, vec, 1);
    print("iov len", iov_count(vec));  # jac:ignore[E1053] pointer reinterpret
    vec_at: int = vec;  # jac:ignore[E1001] pointer reinterpret
    back: IoVec = vec_at;  # jac:ignore[E1001] pointer reinterpret
    print("obj", back.base == "iov ok\n");

    p = pair_t();
    p.a = 3;
    p.b = 4;
    mem: int = raw_alloc(16);
    memcpy(mem, p, 16);
    print("pair", read_pair(mem));
    poke_pair(mem);
    print("poked", read_pair(mem), p.b);
    print("same", pair_address(p) != 0);
    r = pair_t();
    memcpy(r, mem, 16);
    print("filled", r.a, r.b);
    w = word_t();
    w.lo = 7;
    w.hi = 1;
    bits: int = w;
    print("word", bits == 4294967303);
    raw_free(mem);
}
