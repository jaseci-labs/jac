"""Raw byte buffers for the package manager.

Engine strings are NUL-terminated, so anything that may contain a 0x00 byte
(tarballs, HTTP bodies, file contents) lives in io_alloc'd C memory and is
handled as (pointer, length) pairs. ByteBuf is a growable such buffer.

Also here: base64 encoding and Subresource-Integrity checks ("sha512-<b64>"),
both needed to verify registry tarballs against bun.lock / packument integrity.
"""

import from engine.src.runtime.mem { io_alloc, io_free, read_byte, write_byte }
import from engine.src.ffi.libc { memcpy }
import from engine.src.ffi.libcrypto {
    EVP_get_digestbyname,
    EVP_MD_CTX_new,
    EVP_MD_CTX_free,
    EVP_DigestInit_ex,
    EVP_DigestUpdate,
    EVP_DigestFinal_ex
}

"""A growable byte buffer. `ptr` is io_alloc'd (32-byte zeroed header in
front, so a `str` cast of it is inert for the refcounter); `cap` excludes the
extra NUL byte every allocation carries so `ptr[0..len]` can be cast to str."""
obj:pub ByteBuf {
    has ptr: int = 0,
        len: int = 0,
        cap: int = 0;
}

def:pub bytebuf_new(cap: int) -> ByteBuf {
    c: int = cap;
    if c < 64 {
        c = 64;
    }
    return ByteBuf(ptr=io_alloc(c + 1), len=0, cap=c);
}

"""Wrap an existing io_alloc'd region (takes ownership)."""
def:pub bytebuf_from(ptr: int, n: int) -> ByteBuf {
    return ByteBuf(ptr=ptr, len=n, cap=n);
}

def:pub bytebuf_free(b: ByteBuf) {
    if b.ptr != 0 {
        io_free(b.ptr);
    }
    b.ptr = 0;
    b.len = 0;
    b.cap = 0;
}

def:pub bytebuf_reserve(b: ByteBuf, extra: int) -> None {
    need: int = b.len + extra;
    if need <= b.cap and b.ptr != 0 {
        return;
    }
    ncap: int = b.cap * 2;
    if ncap < need {
        ncap = need;
    }
    if ncap < 64 {
        ncap = 64;
    }
    np: int = io_alloc(ncap + 1);
    if b.len > 0 and b.ptr != 0 {
        memcpy(np, b.ptr, b.len);
    }
    if b.ptr != 0 {
        io_free(b.ptr);
    }
    b.ptr = np;
    b.cap = ncap;
}

def:pub bytebuf_append(b: ByteBuf, src: int, n: int) -> None {
    if n <= 0 {
        return;
    }
    bytebuf_reserve(b, n);
    memcpy(b.ptr + b.len, src, n);
    b.len = b.len + n;
    write_byte(b.ptr, b.len, 0);
}

def:pub bytebuf_append_byte(b: ByteBuf, v: int) {
    bytebuf_reserve(b, 1);
    write_byte(b.ptr, b.len, v & 255);
    b.len = b.len + 1;
    write_byte(b.ptr, b.len, 0);
}

"""Append the UTF-8 bytes of `s` (engine str indexing is byte-wise)."""
def:pub bytebuf_append_str(b: ByteBuf, s: str) -> None {
    n: int = len(s);
    if n == 0 {
        return;
    }
    bytebuf_reserve(b, n);
    i: int = 0;
    while i < n {
        write_byte(b.ptr, b.len + i, ord(s[i]));
        i = i + 1;
    }
    b.len = b.len + n;
    write_byte(b.ptr, b.len, 0);
}

"""Copy bytes [off, off+n) of `ptr` into a fresh NUL-terminated buffer and
return it as a str. An embedded 0x00 truncates the str (text only)."""
def:pub bytes_to_str(ptr: int, off: int, n: int) -> str {
    if n <= 0 or ptr == 0 {
        return "";
    }
    p: int = io_alloc(n + 1);
    memcpy(p, ptr + off, n);
    s: str = p;  # jac:ignore[E1001] pointer reinterpreted as str
    return s;
}

def:pub bytebuf_to_str(b: ByteBuf) -> str {
    return bytes_to_str(b.ptr, 0, b.len);
}

"""NUL-terminated C copy of `s` (io_alloc'd; caller frees with io_free)."""
def:pub str_to_cbuf(s: str) -> int {
    n: int = len(s);
    p: int = io_alloc(n + 1);
    i: int = 0;
    while i < n {
        write_byte(p, i, ord(s[i]));
        i = i + 1;
    }
    write_byte(p, n, 0);
    return p;
}

"""True when bytes [off, off+len(s)) of `ptr` equal `s` (and fit in `n`)."""
def:pub bytes_eq_str(ptr: int, off: int, n: int, s: str) -> bool {
    m: int = len(s);
    if off + m > n {
        return False;
    }
    i: int = 0;
    while i < m {
        if read_byte(ptr, off + i) != ord(s[i]) {
            return False;
        }
        i = i + 1;
    }
    return True;
}

"""Index of the first occurrence of `needle` in ptr[start..n), or -1."""
def:pub bytes_find(ptr: int, n: int, start: int, needle: str) -> int {
    m: int = len(needle);
    if m == 0 {
        return start;
    }
    first: int = ord(needle[0]);
    i: int = start;
    last: int = n - m;
    while i <= last {
        if read_byte(ptr, i) == first {
            if bytes_eq_str(ptr, i, n, needle) {
                return i;
            }
        }
        i = i + 1;
    }
    return -1;
}

# ── base64 ────────────────────────────────────────────────────────────────────

glob:priv _B64: str = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

def:pub b64_encode(ptr: int, n: int) -> str {
    out: list[str] = [];
    i: int = 0;
    while i + 2 < n {
        b0: int = read_byte(ptr, i);
        b1: int = read_byte(ptr, i + 1);
        b2: int = read_byte(ptr, i + 2);
        out.append(_B64[b0 >> 2]);
        out.append(_B64[((b0 & 3) << 4) | (b1 >> 4)]);
        out.append(_B64[((b1 & 15) << 2) | (b2 >> 6)]);
        out.append(_B64[b2 & 63]);
        i = i + 3;
    }
    rem: int = n - i;
    if rem == 1 {
        b0: int = read_byte(ptr, i);
        out.append(_B64[b0 >> 2]);
        out.append(_B64[(b0 & 3) << 4]);
        out.append("=");
        out.append("=");
    } elif rem == 2 {
        b0: int = read_byte(ptr, i);
        b1: int = read_byte(ptr, i + 1);
        out.append(_B64[b0 >> 2]);
        out.append(_B64[((b0 & 3) << 4) | (b1 >> 4)]);
        out.append(_B64[(b1 & 15) << 2]);
        out.append("=");
    }
    return "".join(out);
}

def _b64_val(c: int) -> int {
    if c >= 65 and c <= 90 {
        return c - 65;
    }
    if c >= 97 and c <= 122 {
        return c - 97 + 26;
    }
    if c >= 48 and c <= 57 {
        return c - 48 + 52;
    }
    if c == 43 or c == 45 {
        return 62;
    }  # '+' or '-' (url-safe)
    if c == 47 or c == 95 {
        return 63;
    }  # '/' or '_'
    return -1;
}

"""Decode base64 (standard or url-safe, padding optional). Returns an empty
buffer (len 0) for invalid input."""
def:pub b64_decode(s: str) -> ByteBuf {
    out: ByteBuf = bytebuf_new((len(s) * 3) // 4 + 3);
    acc: int = 0;
    nbits: int = 0;
    i: int = 0;
    n: int = len(s);
    while i < n {
        c: int = ord(s[i]);
        i = i + 1;
        if c == 61 {
            break;
        }  # '='
        if c == 10 or c == 13 or c == 32 {
            continue;
        }
        v: int = _b64_val(c);
        if v < 0 {
            out.len = 0;
            return out;
        }
        acc = ((acc << 6) | v) & 16777215;
        nbits = nbits + 6;
        if nbits >= 8 {
            nbits = nbits - 8;
            bytebuf_append_byte(out, (acc >> nbits) & 255);
        }
    }
    return out;
}

# ── digests / integrity ───────────────────────────────────────────────────────

"""Raw digest of ptr[0..n) with the given OpenSSL algorithm name
("sha512", "sha1", ...). Returns (digest ptr, digest length); ptr 0 on error."""
def:pub digest_raw(algo: str, ptr: int, n: int) -> tuple[int, int] {
    md: int = EVP_get_digestbyname(algo);
    if md == 0 {
        return (0, 0);
    }
    ctx: int = EVP_MD_CTX_new();
    if ctx == 0 {
        return (0, 0);
    }
    if EVP_DigestInit_ex(ctx, md, 0) != 1 {
        EVP_MD_CTX_free(ctx);
        return (0, 0);
    }
    if n > 0 {
        if EVP_DigestUpdate(ctx, ptr, n) != 1 {
            EVP_MD_CTX_free(ctx);
            return (0, 0);
        }
    }
    out: int = io_alloc(72);
    out_len: int = io_alloc(8);
    if EVP_DigestFinal_ex(ctx, out, out_len) != 1 {
        EVP_MD_CTX_free(ctx);
        return (0, 0);
    }
    EVP_MD_CTX_free(ctx);
    dlen: int = read_byte(out_len, 0) | (read_byte(out_len, 1) << 8);
    io_free(out_len);
    return (out, dlen);
}

"""Base64 digest of ptr[0..n) — "" on error."""
def:pub digest_b64(algo: str, ptr: int, n: int) -> str {
    d: tuple[int, int] = digest_raw(algo, ptr, n);
    if d[0] == 0 {
        return "";
    }
    s: str = b64_encode(d[0], d[1]);
    io_free(d[0]);
    return s;
}

"""SRI string for ptr[0..n): "sha512-<base64>"."""
def:pub sri_sha512(ptr: int, n: int) -> str {
    return "sha512-" + digest_b64("sha512", ptr, n);
}

"""Check bytes against an SRI string ("sha512-…", "sha1-…", …). Unsupported
algorithms count as a pass (bun ignores integrity tags it does not know)."""
def:pub sri_matches(integrity: str, ptr: int, n: int) -> bool {
    dash: int = integrity.find("-");
    if dash <= 0 {
        return True;
    }
    algo: str = integrity[0:dash].lower();
    if algo != "sha512" and algo != "sha384" and algo != "sha256" and algo != "sha1" {
        return True;
    }
    want: str = integrity[dash + 1:];
    got: str = digest_b64(algo, ptr, n);
    if got == "" {
        return False;
    }
    # Compare decoded bytes so url-safe/padding variants of the same digest agree.
    a: ByteBuf = b64_decode(want);
    b: ByteBuf = b64_decode(got);
    same: bool = a.len == b.len and a.len > 0;
    if same {
        i: int = 0;
        while i < a.len {
            if read_byte(a.ptr, i) != read_byte(b.ptr, i) {
                same = False;
                break;
            }
            i = i + 1;
        }
    }
    bytebuf_free(a);
    bytebuf_free(b);
    return same;
}

"""Lower-case hex of ptr[0..n)."""
def:pub bytes_hex(ptr: int, n: int) -> str {
    digits: str = "0123456789abcdef";
    out: list[str] = [];
    i: int = 0;
    while i < n {
        v: int = read_byte(ptr, i);
        out.append(digits[v >> 4]);
        out.append(digits[v & 15]);
        i = i + 1;
    }
    return "".join(out);
}
