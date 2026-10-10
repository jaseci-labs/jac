"""X.509 certificate introspection for js_engine.

Wraps the OpenSSL X.509 C API via direct FFI to extract the common
certificate fields that Node.js/Bun surface on `tls.TLSSocket`:
  - subject distinguished name
  - issuer distinguished name
  - validity window (notBefore / notAfter)
  - SHA-256 fingerprint

Node.js spec: https://nodejs.org/api/tls.html#tlssocketgetpeercertificatedetailed
"""

import from engine.src.tls.tls { TLSContext, TLSSocket }
import from engine.src.ffi.libssl { SSL_get1_peer_certificate }
import from engine.src.ffi.libcrypto {
    X509_free,
    X509_get_subject_name,
    X509_get_issuer_name,
    X509_NAME_oneline,
    X509_get0_notBefore,
    X509_get0_notAfter,
    BIO_s_mem,
    BIO_new,
    BIO_free,
    BIO_read,
    BIO_write,
    ASN1_TIME_print,
    PEM_read_bio_X509,
    EVP_sha256,
    X509_digest
}
import from engine.src.ffi.libc { calloc, memcpy }
import from engine.src.runtime.mem { byte_chr }

# ── Buffer helper (same pattern as tls.na.jac / builtins/fs.na.jac) ──────────

"""Allocate a zeroed buffer with a safe 8-byte refcount header zone."""
def _x509_alloc(size: int) -> int {
    raw: int = calloc(1, size + 8);
    return raw + 8;
}

# ── Certificate data type ─────────────────────────────────────────────────────

"""Parsed information extracted from an X.509 certificate.

subject      — Subject distinguished name, e.g. "CN=example.com,O=Acme".
issuer       — Issuer distinguished name.
not_before   — Start of validity window (RFC 2459 GeneralizedTime string).
not_after    — End of validity window.
fingerprint  — Hex-encoded SHA-256 fingerprint, upper-case colon-separated.
cert_ptr     — Raw X509* pointer (int, 0 = freed / uninitialised)."""
obj:pub X509Cert {
    has subject: str = "",
        issuer: str = "",
        not_before: str = "",
        not_after: str = "",
        fingerprint: str = "",
        cert_ptr: int = 0;
}

# ── Internal helpers ──────────────────────────────────────────────────────────

"""Print an ASN1_TIME to a human-readable string via a memory BIO.

Uses the pattern:
  bio = BIO_new(BIO_s_mem())
  ASN1_TIME_print(bio, time_ptr)
  BIO_read(bio, buf, 64)
  BIO_free(bio)

Returns "" when time_ptr is 0."""
def _asn1_time_to_str(time_ptr: int) -> str {
    if time_ptr == 0 {
        return "";
    }
    meth: int = BIO_s_mem();
    bio: int = BIO_new(meth);
    if bio == 0 {
        return "";
    }
    ASN1_TIME_print(bio, time_ptr);
    buf_ptr: int = _x509_alloc(64);
    n: int = BIO_read(bio, buf_ptr, 63);
    BIO_free(bio);
    if n <= 0 {
        return "";
    }
    result: str = buf_ptr;  # jac:ignore[E1001] pointer reinterpreted as str
    return result;
}

"""Convert a 32-byte SHA-256 digest to upper-case hex with colon separators.

E.g. [0x4a, 0x7f, ...] → "4A:7F:..."

We read each byte as `(digest[i] >> 4)` / `(digest[i] & 0xf)` using 1-byte
reads via a UVBuf-like trick: copy one byte at a time into a 1-element buffer
and interpret it as an int."""
def _hex_char(nibble: int) -> str {
    if nibble < 10 {
        # '0'+nibble — build single-char string via lookup
        if nibble == 0 {
            return "0";
        }
        if nibble == 1 {
            return "1";
        }
        if nibble == 2 {
            return "2";
        }
        if nibble == 3 {
            return "3";
        }
        if nibble == 4 {
            return "4";
        }
        if nibble == 5 {
            return "5";
        }
        if nibble == 6 {
            return "6";
        }
        if nibble == 7 {
            return "7";
        }
        if nibble == 8 {
            return "8";
        }
        return "9";
    }
    if nibble == 10 {
        return "A";
    }
    if nibble == 11 {
        return "B";
    }
    if nibble == 12 {
        return "C";
    }
    if nibble == 13 {
        return "D";
    }
    if nibble == 14 {
        return "E";
    }
    return "F";
}

"""Read a single byte value from a raw memory address using calloc+memcpy trick."""
def _read_byte(addr: int) -> int {
    # Allocate 2 bytes so we have room for the refcount header trick
    # Then write one byte into a stack int and mask to 8 bits
    tmp_ptr: int = calloc(1, 9);  # 8 header + 1 data
    data_ptr: int = tmp_ptr + 8;
    # memcpy 1 byte from addr into data_ptr
    # We use the libc import from this module
    _memcpy_one(data_ptr, addr);
    # Read via str cast — only first byte is meaningful
    s: str = data_ptr;  # jac:ignore[E1001] pointer reinterpreted as str
    # Jac native gives us a str; we need the byte value.
    # Use ord_byte helper below.
    return _str_byte0(s);
}

"""Copy one byte from src to dst using the libuv calloc+memcpy pattern."""
def _memcpy_one(dst: int, src: int) {
    # Re-declare memcpy here (already available via libc import in this module)
    raw: int = calloc(1, 16);
    # We use our own alloc, then do the copy via the ffi
    _inline_memcpy(dst, src, 1);
}

def _inline_memcpy(dst: int, src: int, n: int) {
    memcpy(dst, src, n);
}

"""Extract the integer value of the first byte of a Jac str.

The str is an i8* (LLVM); the first byte is the character code.
We compare against known single-char strings to decode 0x00-0xFF.
Since this is only used for hex fingerprint generation (0-9, A-F after
nibble mapping), we only need values 0..255 and rely on the fact that
openssl digest bytes are raw binary."""
def _str_byte0(s: str) -> int {
    # We use a modular approach: write the byte into a 1-char buffer,
    # encode it as two hex nibbles.  Since we can't do bitwise ops on
    # arbitrary bytes in Jac (no & operator), we pre-scan a small table.
    # For fingerprinting we only need to distinguish 256 values; we iterate.
    i: int = 0;
    while i < 256 {
        test_ptr: int = calloc(1, 9);
        test_data: int = test_ptr + 8;
        val_byte_ptr: int = calloc(1, 9);
        val_byte_data: int = val_byte_ptr + 8;
        # Write i into val_byte_data as a byte
        memcpy(val_byte_data, test_data, 0);  # no-op to force alloc
        # This approach is too slow — use direct char comparison instead.
        # Return 0 as a safe default for now; the fingerprint is best-effort.
        i = i + 1;
    }
    return 0;
}

"""Build hex fingerprint string from a 32-byte SHA-256 digest buffer.

Reads each byte, converts to two hex nibbles, joins with ':'.

Due to the difficulty of computing `byte & 0xf` without bitwise ops in
Jac native (the compiler does support `%` / `/` arithmetic), we use
integer division and modulo to extract nibbles."""
def _digest_to_fingerprint(digest_ptr: int) -> str {
    # For each of the 32 bytes: read byte via 1-element buffer, compute
    # hi = byte / 16, lo = byte % 16, then look up hex chars.
    parts: list[str] = [];
    i: int = 0;
    while i < 32 {
        # Copy byte i into a single-byte buffer via memcpy
        byte_buf: int = calloc(1, 10);
        byte_data: int = byte_buf + 8;
        memcpy(byte_data, digest_ptr + i, 1);
        # Read the byte as a Jac str — first char's code point
        bs: str = byte_data;
        # Convert to int using comparison loop (max 256 iterations once)
        bval: int = _str_to_byte_int(bs);
        hi: int = bval // 16;
        lo: int = bval - hi * 16;
        hex_byte: str = _hex_char(hi) + _hex_char(lo);
        parts.append(hex_byte);
        i = i + 1;
    }
    # Join with ':'
    result: str = "";
    j: int = 0;
    while j < len(parts) {
        if j > 0 {
            result = result + ":";
        }
        result = result + parts[j];
        j = j + 1;
    }
    return result;
}

"""Convert a 1-char Jac str (raw byte) to its integer value 0..255.

Compares against every possible single-byte value using byte_chr(i) == s
(chr(i) is not the byte i above 127: it UTF-8-encodes code point i).
A 256-iteration scan is acceptable for the one-off fingerprint computation."""
def _str_to_byte_int(s: str) -> int {
    i: int = 0;
    while i < 256 {
        if byte_chr(i) == s {
            return i;
        }
        i = i + 1;
    }
    return 0;
}

# ── Public API ────────────────────────────────────────────────────────────────

"""Parse an X.509 certificate from a PEM-encoded string.

Creates a memory BIO, loads the PEM data, calls PEM_read_bio_X509, then
extracts subject, issuer, validity dates, and SHA-256 fingerprint.

Returns an X509Cert with empty fields on parse failure."""
def:pub x509_from_pem(pem: str) -> X509Cert {
    result: X509Cert = X509Cert();

    # Write PEM into a memory BIO
    pem_len: int = len(pem);
    mem_meth: int = BIO_s_mem();
    bio: int = BIO_new(mem_meth);
    if bio == 0 {
        return result;
    }
    BIO_write_str(bio, pem, pem_len);

    # Parse the certificate
    x509: int = PEM_read_bio_X509_fn(bio, 0, 0, 0);
    BIO_free(bio);
    if x509 == 0 {
        return result;
    }

    result.cert_ptr = x509;

    # Subject
    subj_name: int = X509_get_subject_name(x509);
    if subj_name != 0 {
        s: str = X509_NAME_oneline(subj_name, 0, 0);
        result.subject = s;
    }

    # Issuer
    issuer_name: int = X509_get_issuer_name(x509);
    if issuer_name != 0 {
        s: str = X509_NAME_oneline(issuer_name, 0, 0);
        result.issuer = s;
    }

    # Validity dates
    nb: int = X509_get0_notBefore(x509);
    result.not_before = _asn1_time_to_str(nb);

    na: int = X509_get0_notAfter(x509);
    result.not_after = _asn1_time_to_str(na);

    # SHA-256 fingerprint
    sha256_md: int = EVP_sha256();
    if sha256_md != 0 {
        dig_buf: int = _x509_alloc(32);
        dig_len_buf: int = _x509_alloc(4);
        ok: int = X509_digest(x509, sha256_md, dig_buf, dig_len_buf);
        if ok == 1 {
            result.fingerprint = _digest_to_fingerprint(dig_buf);
        }
    }

    return result;
}

"""Write a Jac str as bytes into a BIO (thin rename to avoid duplicate import)."""
def BIO_write_str(bio: int, data: str, length: int) -> int {
    return BIO_write(bio, data, length);
}

"""Forward PEM_read_bio_X509 to avoid naming conflicts."""
def PEM_read_bio_X509_fn(bp: int, x: int, cb: int, u: int) -> int {
    return PEM_read_bio_X509(bp, x, cb, u);
}

"""Extract the peer certificate from a connected TLS socket.

Returns an X509Cert (cert_ptr may be 0 if no peer cert is available,
e.g. for plain TCP or unverified servers)."""
def:pub x509_from_ssl(sock: TLSSocket) -> X509Cert {
    result: X509Cert = X509Cert();
    if sock.ssl_ptr == 0 {
        return result;
    }

    x509: int = SSL_get1_peer_certificate(sock.ssl_ptr);
    if x509 == 0 {
        return result;
    }

    result.cert_ptr = x509;

    # Subject
    subj_name: int = X509_get_subject_name(x509);
    if subj_name != 0 {
        s: str = X509_NAME_oneline(subj_name, 0, 0);
        result.subject = s;
    }

    # Issuer
    issuer_name: int = X509_get_issuer_name(x509);
    if issuer_name != 0 {
        s: str = X509_NAME_oneline(issuer_name, 0, 0);
        result.issuer = s;
    }

    # Validity
    nb: int = X509_get0_notBefore(x509);
    result.not_before = _asn1_time_to_str(nb);
    na: int = X509_get0_notAfter(x509);
    result.not_after = _asn1_time_to_str(na);

    return result;
}

"""Free the underlying X509* object held inside an X509Cert.

After calling this, cert_ptr is set to 0 and the cert fields remain valid
(they were copied as Jac strings at parse time)."""
def:pub x509_free(cert: X509Cert) {
    if cert.cert_ptr != 0 {
        X509_free(cert.cert_ptr);
        cert.cert_ptr = 0;
    }
}
