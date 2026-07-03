"""
ctypes reference implementation for jac-bridge-regex (M0 baseline).

Parallel to jac/regex.jac: same public surface, same ABI conventions, no Jac
dependency.  The M3 compiler-generated loader (jac-bridge-loader) now handles
production use; this module is kept as a CPython-only conformance reference and
is still the easiest way to call the bridge directly from Python.

ABI conventions (mirrors src/lib.rs):
  - i32 status: 0=ok 1=err 2=panic
  - strings as (c_char_p, c_uint32) — never NUL-terminated
  - opaque handles are Box<T> cast to u64; 0 is always invalid
  - JacBuf owns heap memory; free exclusively via jac_regex_free_buf
"""

import ctypes
import pathlib

# --------------------------------------------------------------------------- #
# Status codes
# --------------------------------------------------------------------------- #

_STATUS_OK = 0
_STATUS_ERR = 1
_STATUS_PANIC = 2


# --------------------------------------------------------------------------- #
# JacBuf — mirrors #[repr(C)] struct JacBuf { ptr: *mut u8, len: u32, cap: u32 }
# 64-bit layout: ptr=8B, len=4B, cap=4B → 16 bytes total
# --------------------------------------------------------------------------- #


class _JacBuf(ctypes.Structure):
    _fields_ = [
        ("ptr", ctypes.c_uint64),  # kept as int to avoid ctypes None-ifying null void_p
        ("len", ctypes.c_uint32),
        ("cap", ctypes.c_uint32),
    ]


# --------------------------------------------------------------------------- #
# Locate the shared library
# --------------------------------------------------------------------------- #


def _find_lib() -> pathlib.Path:
    # Cargo workspace root is two levels up: python/ → jac-bridge-regex/ → bridges/
    # The workspace target/ lives at bridges/target/, not inside the member package.
    pkg = pathlib.Path(__file__).resolve().parent.parent  # jac-bridge-regex/
    ws = pkg.parent  # bridges/ (workspace root)
    for root in (ws, pkg):
        for build in ("release", "debug"):
            for stem in (
                "libjac_bridge_regex.so",
                "libjac_bridge_regex.dylib",
                "jac_bridge_regex.dll",
            ):
                p = root / "target" / build / stem
                if p.exists():
                    return p
    raise FileNotFoundError(
        "libjac_bridge_regex not found — run: cargo build --release\n"
        f"(searched under {ws / 'target'} and {pkg / 'target'})"
    )


# --------------------------------------------------------------------------- #
# Library loader (module-level singleton)
# --------------------------------------------------------------------------- #

_lib: ctypes.CDLL | None = None


def _load() -> ctypes.CDLL:
    global _lib
    if _lib is not None:
        return _lib

    lib = ctypes.CDLL(str(_find_lib()))

    lib.jac_bridge_init_regex.argtypes = []
    lib.jac_bridge_init_regex.restype = ctypes.c_uint64

    lib.jac_regex_Regex_new.argtypes = [
        ctypes.c_char_p,
        ctypes.c_uint32,
        ctypes.POINTER(ctypes.c_uint64),
        ctypes.POINTER(ctypes.c_uint64),
    ]
    lib.jac_regex_Regex_new.restype = ctypes.c_int

    lib.jac_regex_Regex_is_match.argtypes = [
        ctypes.c_uint64,
        ctypes.c_char_p,
        ctypes.c_uint32,
        ctypes.POINTER(ctypes.c_uint8),
        ctypes.POINTER(ctypes.c_uint64),
    ]
    lib.jac_regex_Regex_is_match.restype = ctypes.c_int

    lib.jac_regex_Regex_drop.argtypes = [ctypes.c_uint64]
    lib.jac_regex_Regex_drop.restype = None

    lib.jac_regex_error_message.argtypes = [
        ctypes.c_uint64,
        ctypes.POINTER(_JacBuf),
        ctypes.POINTER(ctypes.c_uint64),
    ]
    lib.jac_regex_error_message.restype = ctypes.c_int

    lib.jac_regex_error_drop.argtypes = [ctypes.c_uint64]
    lib.jac_regex_error_drop.restype = None

    lib.jac_regex_free_buf.argtypes = [_JacBuf]
    lib.jac_regex_free_buf.restype = None

    _lib = lib
    return lib


# --------------------------------------------------------------------------- #
# Internal: drain an error handle into a Python str, then drop the handle
# --------------------------------------------------------------------------- #


def _drain_err(lib: ctypes.CDLL, err_h: int) -> str:
    buf = _JacBuf()
    out_e = ctypes.c_uint64(0)
    st = lib.jac_regex_error_message(err_h, ctypes.byref(buf), ctypes.byref(out_e))
    if st != _STATUS_OK:
        lib.jac_regex_error_drop(err_h)
        return f"<panic reading error message: status={st}>"
    msg = ctypes.string_at(buf.ptr, buf.len).decode("utf-8", errors="replace")
    lib.jac_regex_free_buf(buf)
    lib.jac_regex_error_drop(err_h)
    return msg


# --------------------------------------------------------------------------- #
# Public exceptions
# --------------------------------------------------------------------------- #


class RegexError(Exception):
    """Raised when the Rust regex engine rejects a pattern or encounters bad UTF-8."""


class PanicError(Exception):
    """Raised when the Rust bridge catches a panic (STATUS_PANIC=2)."""


# --------------------------------------------------------------------------- #
# Public Regex class
# --------------------------------------------------------------------------- #


class Regex:
    """
    Wrapper for Rust's regex::Regex type.

    Lifetime contract:
      - The compiled regex lives on the Rust heap until drop() is called.
      - Call close() for deterministic cleanup; __del__ is the GC safety net.
      - After close(), any method call raises RuntimeError.
      - Use as a context manager for automatic cleanup:

          with Regex(r"foo\\d+") as re:
              print(re.is_match("foo42"))
    """

    __slots__ = ("_handle", "_lib", "_closed")

    def __init__(self, pattern: str) -> None:
        # Initialise slots eagerly so __del__ is always safe to call,
        # even if we raise before the handle is allocated.
        self._handle = 0
        self._closed = True
        self._lib = None

        lib = _load()
        enc = pattern.encode("utf-8")
        out_h = ctypes.c_uint64(0)
        out_e = ctypes.c_uint64(0)
        st = lib.jac_regex_Regex_new(
            enc, len(enc), ctypes.byref(out_h), ctypes.byref(out_e)
        )
        if st == _STATUS_OK:
            self._handle = out_h.value
            self._lib = lib
            self._closed = False
        elif st == _STATUS_ERR:
            raise RegexError(_drain_err(lib, out_e.value))
        else:
            raise PanicError(
                f"Rust panic in Regex::new: {_drain_err(lib, out_e.value)}"
            )

    def is_match(self, text: str) -> bool:
        self._assert_open()
        enc = text.encode("utf-8")
        out_b = ctypes.c_uint8(0)
        out_e = ctypes.c_uint64(0)
        st = self._lib.jac_regex_Regex_is_match(
            self._handle,
            enc,
            len(enc),
            ctypes.byref(out_b),
            ctypes.byref(out_e),
        )
        if st == _STATUS_OK:
            return bool(out_b.value)
        msg = _drain_err(self._lib, out_e.value)
        if st == _STATUS_ERR:
            raise RegexError(msg)
        raise PanicError(f"Rust panic in is_match: {msg}")

    def close(self) -> None:
        if not self._closed:
            self._lib.jac_regex_Regex_drop(self._handle)
            self._handle = 0
            self._closed = True

    def _assert_open(self) -> None:
        if self._closed:
            raise RuntimeError("Regex used after close()")

    def __del__(self) -> None:
        self.close()

    def __enter__(self) -> "Regex":
        return self

    def __exit__(self, *_: object) -> None:
        self.close()

    def __repr__(self) -> str:
        state = "closed" if self._closed else f"handle={self._handle:#x}"
        return f"<Regex {state}>"
