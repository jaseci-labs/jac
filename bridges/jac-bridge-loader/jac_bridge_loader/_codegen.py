"""Dynamically build a Python module from parsed bridge metadata + a dlopen'd .so."""

import ctypes
import types as pytypes
import weakref
from collections.abc import Callable
from typing import Any

from ._blob import (
    FN_CTOR,
    FN_METHOD,
    KIND_ERROR,
    KIND_OPAQUE,
    TAG_BOOL,
    TAG_OPT_BIT,
    TAG_REF_BIT,
    TAG_STR,
    TAG_VOID,
    BridgeMeta,
    FnDesc,
    TypeDesc,
)


class _JacBuf(ctypes.Structure):
    _fields_ = [
        ("ptr", ctypes.c_uint64),
        ("len", ctypes.c_uint32),
        ("cap", ctypes.c_uint32),
    ]


def _encode(val: str | bytes) -> tuple[bytes, int]:
    enc = val.encode("utf-8") if isinstance(val, str) else val
    return enc, len(enc)


# ---------------------------------------------------------------------------
# Runtime: holds all ctypes handles for one bridge.
# ---------------------------------------------------------------------------


class _Runtime:
    def __init__(self, lib: ctypes.CDLL, meta: BridgeMeta) -> None:
        self.lib = lib
        self.meta = meta

        fb = getattr(lib, f"jac_{meta.module_name}_free_buf")
        fb.argtypes = [_JacBuf]
        fb.restype = None
        self.free_buf = fb

        self._err_drops: dict[int, Any] = {}  # type_idx -> drop fn
        self._err_msgs: dict[int, Any] = {}  # type_idx -> message fn
        self._err_cls: dict[int, type] = {}  # type_idx -> exception class
        self.PanicError = type("PanicError", (Exception,), {})

        for td in meta.types:
            if td.kind != KIND_ERROR:
                continue
            drop = getattr(lib, td.drop_sym)
            drop.argtypes = [ctypes.c_uint64]
            drop.restype = None
            self._err_drops[td.index] = drop
            self._err_cls[td.index] = type(td.name, (Exception,), {})

        for fd in meta.fns:
            if fd.name != "message" or fd.self_type == TAG_VOID:
                continue
            td = meta.types[fd.self_type]
            if td.kind != KIND_ERROR:
                continue
            fn = getattr(lib, fd.sym)
            fn.argtypes = [
                ctypes.c_uint64,
                ctypes.POINTER(_JacBuf),
                ctypes.POINTER(ctypes.c_uint64),
            ]
            fn.restype = ctypes.c_int
            self._err_msgs[fd.self_type] = fn

    # Any error handle (user error or panic) is Box<String>; either message fn
    # can decode it.  Pass throws_idx=None to use the first available one.
    def drain_err(self, err_h: int, throws_idx: int | None = None) -> str:
        idx = throws_idx if throws_idx is not None else next(iter(self._err_msgs), None)
        fn = self._err_msgs.get(idx)  # type: ignore[arg-type]
        if fn is None:
            return "<no error-message function in bridge>"
        buf = _JacBuf()
        out_e = ctypes.c_uint64(0)
        st = fn(err_h, ctypes.byref(buf), ctypes.byref(out_e))
        if st != 0:
            drop = self._err_drops.get(idx)
            if drop:
                drop(err_h)
            return f"<panic reading error message: status={st}>"
        raw = ctypes.string_at(buf.ptr, buf.len)
        self.free_buf(buf)
        drop = self._err_drops.get(idx)  # type: ignore[arg-type]
        if drop:
            drop(err_h)
        return raw.decode("utf-8", errors="replace")

    def err_cls(self, throws_idx: int) -> type:
        return self._err_cls.get(throws_idx, Exception)


# ---------------------------------------------------------------------------
# Wire up a single C function.
# ---------------------------------------------------------------------------


def _wire(lib: ctypes.CDLL, fd: FnDesc) -> Callable[..., object]:
    """Set argtypes/restype on the ctypes function and return it."""
    c_fn = getattr(lib, fd.sym)
    args: list[Any] = []

    if fd.kind == FN_METHOD and fd.self_type != TAG_VOID:
        args.append(ctypes.c_uint64)

    for p in fd.params:
        if p.tag == TAG_STR:
            args.extend([ctypes.c_char_p, ctypes.c_uint32])
        elif p.tag == TAG_BOOL:
            args.append(ctypes.c_uint8)
        else:
            args.append(ctypes.c_uint64)

    # Every bridge function has out_err and returns i32 — even void-return ones.
    # Tag::Void just means no *extra* out-param; the status/panic path is always present.
    # A nullable Option<T> return (TAG_OPT_BIT) uses the SAME out-slot as its inner
    # tag — None just arrives as a null handle / null JacBuf.ptr — so strip it here.
    base_ret = fd.ret & ~TAG_OPT_BIT
    if base_ret == TAG_BOOL:
        args.append(ctypes.POINTER(ctypes.c_uint8))
    elif base_ret == TAG_STR:
        args.append(ctypes.POINTER(_JacBuf))
    elif base_ret != TAG_VOID:  # type ref
        args.append(ctypes.POINTER(ctypes.c_uint64))

    args.append(ctypes.POINTER(ctypes.c_uint64))  # out_err — always present

    c_fn.argtypes = args
    c_fn.restype = ctypes.c_int
    return c_fn


# ---------------------------------------------------------------------------
# Invoke a wired C function with Python-level args.
# Returns the Python value (or a partially-initialised handle object for refs).
# ---------------------------------------------------------------------------


def _call(
    c_fn: Callable[..., object],
    fd: FnDesc,
    rt: _Runtime,
    self_h: int | None,
    py_args: tuple,
    classes: dict[int, type],
) -> object:
    c_args: list[Any] = []

    if fd.kind == FN_METHOD and self_h is not None:
        c_args.append(self_h)

    for i, p in enumerate(fd.params):
        v = py_args[i]
        if p.tag == TAG_STR:
            enc, n = _encode(v)
            c_args.extend([enc, ctypes.c_uint32(n)])
        elif p.tag == TAG_BOOL:
            c_args.append(ctypes.c_uint8(int(bool(v))))
        else:
            c_args.append(ctypes.c_uint64(int(v)))

    out_h = ctypes.c_uint64(0)
    out_b = ctypes.c_uint8(0)
    out_buf = _JacBuf()
    out_e = ctypes.c_uint64(0)

    # An Option<T> return shares its inner tag's out-slot; None arrives in-band as
    # a null handle / null JacBuf.ptr on an OK status.
    opt = bool(fd.ret & TAG_OPT_BIT)
    base_ret = fd.ret & ~TAG_OPT_BIT

    if base_ret == TAG_BOOL:
        c_args.append(ctypes.byref(out_b))
    elif base_ret == TAG_STR:
        c_args.append(ctypes.byref(out_buf))
    elif base_ret != TAG_VOID:
        c_args.append(ctypes.byref(out_h))

    c_args.append(ctypes.byref(out_e))  # out_err — always present

    st = c_fn(*c_args)

    if st == 1:
        msg = rt.drain_err(out_e.value, fd.throws if fd.throws != TAG_VOID else None)
        raise rt.err_cls(fd.throws)(msg)
    if st != 0:
        msg = rt.drain_err(out_e.value)
        raise rt.PanicError(msg)

    if base_ret == TAG_VOID:
        return None
    if base_ret == TAG_BOOL:
        return bool(out_b.value)
    if base_ret == TAG_STR:
        # Option<Str> None: null buffer pointer, nothing to free or decode.
        if opt and out_buf.ptr == 0:
            return None
        raw = ctypes.string_at(out_buf.ptr, out_buf.len)
        rt.free_buf(out_buf)
        return raw.decode("utf-8", errors="replace")

    # Type-ref return: wrap the raw handle in a partially-init instance.
    # The caller (typically __init__) steals _handle and marks this obj closed.
    h = out_h.value
    # Option<Ref> None: a null (0) handle maps straight to Python None.
    if opt and h == 0:
        return None
    ret_idx = base_ret & ~TAG_REF_BIT
    cls = classes.get(ret_idx)
    if cls is None:
        return h
    stub = object.__new__(cls)
    stub._handle = h
    stub._closed = False
    stub._rt = rt
    return stub


# ---------------------------------------------------------------------------
# Build one opaque-type class.
# ---------------------------------------------------------------------------


def _make_class(
    td: TypeDesc,
    meta: BridgeMeta,
    lib: ctypes.CDLL,
    rt: _Runtime,
    classes: dict[int, type],
) -> type:
    drop_fn = getattr(lib, td.drop_sym)
    drop_fn.argtypes = [ctypes.c_uint64]
    drop_fn.restype = None

    ctor_fd: FnDesc | None = None
    method_fds: list[FnDesc] = []
    for fd in meta.fns:
        if fd.kind == FN_CTOR and fd.ret == (TAG_REF_BIT | td.index):
            ctor_fd = fd
        elif fd.kind == FN_METHOD and fd.self_type == td.index and fd.name != "message":
            method_fds.append(fd)

    ctor_c = _wire(lib, ctor_fd) if ctor_fd else None
    method_c = [(fd, _wire(lib, fd)) for fd in method_fds]

    # ---- __init__ ----
    if ctor_fd is not None:
        _ctor_fd = ctor_fd  # capture for closure

        def _init(self: object, *args: object) -> None:
            self._handle = 0
            self._closed = True
            self._rt = rt
            self._finalizer = None
            stub = _call(ctor_c, _ctor_fd, rt, None, args, classes)
            self._handle = stub._handle
            self._closed = False
            stub._closed = True  # prevent the stub from dropping the stolen handle
            # D3 lifetime: weakref.finalize runs the drop at most once, at GC or
            # interpreter exit, without resurrecting the instance. It binds only
            # the raw handle + drop fn (never `self`), so it never keeps the
            # object alive. close() detaches it for deterministic release.
            self._finalizer = weakref.finalize(self, drop_fn, self._handle)
    else:

        def _init(self: object, *args: object) -> None:
            raise TypeError(f"{td.name} has no constructor")

    # ---- close / dtor ----
    def close(self: object) -> None:
        # Invoking the finalizer drops exactly once and marks it dead, so the
        # GC path becomes a no-op — the two never double-drop.
        fin = getattr(self, "_finalizer", None)
        if fin is not None:
            fin()
        elif not self._closed:
            drop_fn(self._handle)  # stub path: no finalizer registered
        self._handle = 0
        self._closed = True

    def _del(self: object) -> None:
        # Safety net; weakref.finalize already covers GC. Idempotent via close().
        self.close()

    def _enter(self: object) -> object:
        return self

    def _exit(self: object, *_: object) -> None:
        self.close()

    def _repr(self: object) -> str:
        state = "closed" if self._closed else f"handle={self._handle:#x}"
        return f"<{td.name} {state}>"

    cls_dict: dict[str, Any] = {
        "__init__": _init,
        "close": close,
        "__del__": _del,
        "__enter__": _enter,
        "__exit__": _exit,
        "__repr__": _repr,
    }

    for fd, c_fn in method_c:

        def _make(fd_: FnDesc, c_fn_: Callable[..., object]) -> Callable[..., object]:
            type_name = td.name

            def method(self: object, *args: object) -> object:
                if self._closed:
                    raise RuntimeError(f"{type_name}.{fd_.name} called after close()")
                return _call(c_fn_, fd_, rt, self._handle, args, classes)

            method.__name__ = fd_.name
            return method

        cls_dict[fd.name] = _make(fd, c_fn)

    return type(td.name, (), cls_dict)


# ---------------------------------------------------------------------------
# Public entry point.
# ---------------------------------------------------------------------------


def build_module(so_path: str, meta: BridgeMeta) -> pytypes.ModuleType:
    """Open *so_path*, wire up ctypes from *meta*, return a Python module."""
    lib = ctypes.CDLL(so_path)

    init_name = f"jac_bridge_init_{meta.module_name}"
    try:
        init_fn = getattr(lib, init_name)
        init_fn.argtypes = []
        init_fn.restype = ctypes.c_void_p
        init_fn()
    except AttributeError:
        pass

    rt = _Runtime(lib, meta)

    # Two-pass so forward type-refs in ctor return types resolve correctly.
    classes: dict[int, type] = {}
    for td in meta.types:
        if td.kind == KIND_OPAQUE:
            classes[td.index] = type(td.name, (), {})  # placeholder
    for td in meta.types:
        if td.kind == KIND_OPAQUE:
            classes[td.index] = _make_class(td, meta, lib, rt, classes)

    mod = pytypes.ModuleType(meta.module_name)
    mod.__file__ = so_path
    for td in meta.types:
        if td.kind == KIND_ERROR:
            setattr(mod, td.name, rt.err_cls(td.index))
        elif td.kind == KIND_OPAQUE:
            setattr(mod, td.name, classes[td.index])
    mod.PanicError = rt.PanicError
    mod._lib = lib
    mod._meta = meta
    mod._rt = rt
    return mod
