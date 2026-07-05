import weakref;
import struct;
import types as pytypes;
import from ctypes {
    Structure,
    CDLL,
    CFUNCTYPE,
    POINTER,
    byref,
    cast,
    addressof,
    string_at,
    c_uint64,
    c_uint32,
    c_uint8,
    c_char_p,
    c_int,
    c_void_p
}
import from jaclang.compiler.rust_bridge._blob {
    BridgeMeta,
    FnDesc,
    TypeDesc,
    TAG_VOID,
    TAG_BOOL,
    TAG_INT,
    TAG_UINT,
    TAG_STR,
    TAG_FN,
    KIND_OPAQUE,
    KIND_ERROR,
    FN_CTOR,
    FN_METHOD,
    tag_base,
    tag_is_opt,
    tag_is_ref,
    tag_ref_index,
    tag_is_map,
    tag_map_value
}


class _JacBuf(Structure) {
    with entry {
        _fields_ = [('ptr', c_uint64), ('len', c_uint32), ('cap', c_uint32)];
    }
}


glob _CB_TYPE = CFUNCTYPE(
         c_int, c_void_p, c_void_p, c_uint32, POINTER(_JacBuf), POINTER(c_uint64)
     );


class _JacCallback(Structure) {
    with entry {
        _fields_ = [('call', c_void_p), ('ctx', c_void_p)];
    }
}


def _encode(val: str | bytes) -> tuple {
    enc = val.encode("utf-8") if isinstance(val, str) else val;
    return (enc, len(enc));
}


class _Runtime {
    def init(self: _Runtime, lib: CDLL, meta: BridgeMeta) {
        self.lib = lib;
        self.meta = meta;

        fb = getattr(lib, f"jac_{meta.module_name}_free_buf");
        fb.argtypes = [_JacBuf];
        fb.restype = None;
        self.free_buf = fb;

        mb = getattr(lib, f"jac_{meta.module_name}_make_buf", None);
        if mb is not None {
            mb.argtypes = [c_char_p, c_uint32, POINTER(_JacBuf)];
            mb.restype = None;
        }
        self.make_buf = mb;

        pm = getattr(lib, f"jac_{meta.module_name}_panic_message", None);
        if pm is not None {
            pm.argtypes = [c_uint64, POINTER(_JacBuf), POINTER(c_uint64)];
            pm.restype = c_int;
        }
        self.panic_msg = pm;
        pd = getattr(lib, f"jac_{meta.module_name}_panic_drop", None);
        if pd is not None {
            pd.argtypes = [c_uint64];
            pd.restype = None;
        }
        self.panic_drop = pd;

        self._err_drops = {};
        self._err_msgs = {};
        self._err_cls = {};
        self.PanicError = type("PanicError", (Exception, ), {});

        for td in meta.types {
            if td.kind != KIND_ERROR {
                continue;
            }
            drop = getattr(lib, td.drop_sym);
            drop.argtypes = [c_uint64];
            drop.restype = None;
            self._err_drops[td.index] = drop;
            self._err_cls[td.index] = type(td.name, (Exception, ), {});
        }

        for fd in meta.fns {
            if fd.name != "message" or fd.self_type == TAG_VOID {
                continue;
            }
            td = meta.types[fd.self_type];
            if td.kind != KIND_ERROR {
                continue;
            }
            fn = getattr(lib, fd.sym);
            fn.argtypes = [c_uint64, POINTER(_JacBuf), POINTER(c_uint64)];
            fn.restype = c_int;
            self._err_msgs[fd.self_type] = fn;
        }
    }

    def drain_err(self: _Runtime, err_h: int, throws_idx: int | None = None) -> str {
        idx = throws_idx
            if throws_idx is not None
            else next(iter(self._err_msgs), None);
        fn = self._err_msgs.get(idx);
        if fn is None {
            return "<no error-message function in bridge>";
        }
        buf = _JacBuf();
        out_e = c_uint64(0);
        st = fn(err_h, byref(buf), byref(out_e));
        if st != 0 {
            drop = self._err_drops.get(idx);
            if drop {
                drop(err_h);
            }
            return f"<panic reading error message: status={st}>";
        }
        raw = string_at(buf.ptr, buf.len);
        self.free_buf(buf);
        drop = self._err_drops.get(idx);
        if drop {
            drop(err_h);
        }
        return raw.decode("utf-8", errors="replace");
    }

    def drain_panic(self: _Runtime, err_h: int) -> str {
        if self.panic_msg is None {
            return self.drain_err(err_h);
        }
        buf = _JacBuf();
        out_e = c_uint64(0);
        st = self.panic_msg(err_h, byref(buf), byref(out_e));
        if st != 0 {
            self.panic_drop(err_h);
            return f"<panic reading panic message: status={st}>";
        }
        raw = string_at(buf.ptr, buf.len);
        self.free_buf(buf);
        self.panic_drop(err_h);
        return raw.decode("utf-8", errors="replace");
    }

    def err_cls(self: _Runtime, throws_idx: int) -> type {
        return self._err_cls.get(throws_idx, Exception);
    }
}


def _wire(lib: CDLL, fd: FnDesc) -> object {
    c_fn = getattr(lib, fd.sym);
    args = [];

    if fd.kind == FN_METHOD and fd.self_type != TAG_VOID {
        args.append(c_uint64);
    }

    for p in fd.params {
        if p.tag == TAG_STR {
            args.extend([c_char_p, c_uint32]);
        } elif p.tag == TAG_BOOL {
            args.append(c_uint8);
        } elif p.tag == TAG_FN {
            args.append(c_uint64);
        } else {
            args.append(c_uint64);
        }
    }

    base_ret = tag_base(fd.ret);
    if tag_is_map(fd.ret) {
        args.append(POINTER(_JacBuf));
    } elif base_ret == TAG_BOOL {
        args.append(POINTER(c_uint8));
    } elif base_ret == TAG_STR {
        args.append(POINTER(_JacBuf));
    } elif base_ret != TAG_VOID {
        args.append(POINTER(c_uint64));
    }

    args.append(POINTER(c_uint64));

    c_fn.argtypes = args;
    c_fn.restype = c_int;
    return c_fn;
}


def _make_trampoline(fn: object, rt: _Runtime) -> object {
    make_buf = rt.make_buf;
    if make_buf is None {
        raise RuntimeError("bridge has a callback param but exports no make_buf");
    }

    def _trampoline(
        _ctx: object, ptr: int, n: int, out_buf: object, _out_err: object
    ) -> int {
        try {
            matched = string_at(ptr, n).decode("utf-8", errors="replace");
            result = fn(matched);
            enc = result.encode("utf-8") if isinstance(result, str) else bytes(result);
            make_buf(enc, len(enc), out_buf);
            return 0;
        } except Exception {
            return 3;
        }
    }

    return _CB_TYPE(_trampoline);
}


def _decode_map(raw: bytes, vtag: int) -> dict {
    out = {};
    (count, ) = struct.unpack_from("<I", raw, 0);
    off = 4;
    for _ in range(count) {
        (klen, ) = struct.unpack_from("<I", raw, off);
        off += 4;
        key = raw[off:off + klen].decode("utf-8", errors="replace");
        off += klen;
        if vtag == TAG_STR {
            (vlen, ) = struct.unpack_from("<I", raw, off);
            off += 4;
            val = raw[off:off + vlen].decode("utf-8", errors="replace");
            off += vlen;
        } elif vtag == TAG_BOOL {
            (b, ) = struct.unpack_from("<B", raw, off);
            off += 1;
            val = bool(b);
        } else {
            (u, ) = struct.unpack_from("<Q", raw, off);
            off += 8;
            if vtag == TAG_INT {
                val = u - 0x10000000000000000 if u >= 0x8000000000000000 else u;
            } else {
                val = u;
            }
        }
        out[key] = val;
    }
    return out;
}


def _call(
    c_fn: object,
    fd: FnDesc,
    rt: _Runtime,
    self_h: object,
    py_args: object,
    classes: dict[int, type]
) -> object {
    c_args = [];
    keepalive = [];

    if fd.kind == FN_METHOD and self_h is not None {
        c_args.append(self_h);
    }

    for (i, p) in enumerate(fd.params) {
        v = py_args[i];
        if p.tag == TAG_STR {
            (enc, n) = _encode(v);
            c_args.extend([enc, c_uint32(n)]);
        } elif p.tag == TAG_BOOL {
            c_args.append(c_uint8(int(bool(v))));
        } elif p.tag == TAG_INT or p.tag == TAG_UINT {
            c_args.append(c_uint64(int(v) & 0xFFFFFFFFFFFFFFFF));
        } elif p.tag == TAG_FN {
            cb = _make_trampoline(v, rt);
            rec = _JacCallback(cast(cb, c_void_p), None);
            keepalive.append(cb);
            keepalive.append(rec);
            c_args.append(c_uint64(addressof(rec)));
        } else {
            c_args.append(c_uint64(int(v)));
        }
    }

    out_h = c_uint64(0);
    out_b = c_uint8(0);
    out_buf = _JacBuf();
    out_e = c_uint64(0);

    opt = tag_is_opt(fd.ret);
    is_map = tag_is_map(fd.ret);
    base_ret = tag_base(fd.ret);

    if is_map {
        c_args.append(byref(out_buf));
    } elif base_ret == TAG_BOOL {
        c_args.append(byref(out_b));
    } elif base_ret == TAG_STR {
        c_args.append(byref(out_buf));
    } elif base_ret != TAG_VOID {
        c_args.append(byref(out_h));
    }

    c_args.append(byref(out_e));

    st = c_fn(*c_args);

    if st == 1 {
        msg = rt.drain_err(out_e.value, fd.throws if fd.throws != TAG_VOID else None);
        raise rt.err_cls(fd.throws)(msg);
    }
    if st != 0 {
        msg = rt.drain_panic(out_e.value);
        raise rt.PanicError(msg);
    }

    if is_map {
        raw = string_at(out_buf.ptr, out_buf.len) if out_buf.ptr != 0 else b"";
        rt.free_buf(out_buf);
        return _decode_map(raw, tag_map_value(fd.ret));
    }
    if base_ret == TAG_VOID {
        return None;
    }
    if base_ret == TAG_BOOL {
        return bool(out_b.value);
    }
    if base_ret == TAG_STR {
        if opt and out_buf.ptr == 0 {
            return None;
        }
        raw = string_at(out_buf.ptr, out_buf.len);
        rt.free_buf(out_buf);
        return raw.decode("utf-8", errors="replace");
    }
    if base_ret == TAG_INT {
        v = out_h.value;
        return v - 0x10000000000000000 if v >= 0x8000000000000000 else v;
    }
    if base_ret == TAG_UINT {
        return out_h.value;
    }

    h = out_h.value;
    if opt and h == 0 {
        return None;
    }
    ret_idx = tag_ref_index(fd.ret);
    cls = classes.get(ret_idx);
    if cls is None {
        return h;
    }
    stub = object.__new__(cls);
    stub._handle = h;
    stub._closed = False;
    stub._rt = rt;
    return stub;
}


def _bind_method(
    type_name: str, fd_: FnDesc, c_fn_: object, rt: _Runtime, classes: dict[int, type]
) -> object {
    def method(self: object, *args: object) -> object {
        if self._closed {
            raise RuntimeError(f"{type_name}.{fd_.name} called after close()");
        }
        return _call(c_fn_, fd_, rt, self._handle, args, classes);
    }
    method.__name__ = fd_.name;
    return method;
}


def _make_class(
    td: TypeDesc, meta: BridgeMeta, lib: CDLL, rt: _Runtime, classes: dict[int, type]
) -> type {
    drop_fn = getattr(lib, td.drop_sym);
    drop_fn.argtypes = [c_uint64];
    drop_fn.restype = None;

    ctor_fd = None;
    method_fds = [];
    for fd in meta.fns {
        if fd.kind == FN_CTOR
        and tag_is_ref(fd.ret)
        and not tag_is_opt(fd.ret)
        and tag_ref_index(fd.ret) == td.index {
            ctor_fd = fd;
        } elif fd.kind == FN_METHOD
        and fd.self_type == td.index
        and fd.name != "message" {
            method_fds.append(fd);
        }
    }

    ctor_c = _wire(lib, ctor_fd) if ctor_fd else None;
    method_c = [(fd, _wire(lib, fd)) for fd in method_fds];

    if ctor_fd is not None {
        _ctor_fd = ctor_fd;

        def __init__(self: object, *args: object) {
            self._handle = 0;
            self._closed = True;
            self._rt = rt;
            self._finalizer = None;
            stub = _call(ctor_c, _ctor_fd, rt, None, args, classes);
            self._handle = stub._handle;
            self._closed = False;
            stub._closed = True;

            self._finalizer = weakref.finalize(self, drop_fn, self._handle);
        }
    } else {
        def __init__(self: object, *args: object) {
            raise TypeError(f"{td.name} has no constructor");
        }
    }

    def close(self: object) {
        fin = self?._finalizer;
        if fin is not None {
            fin();
        } elif not self._closed {
            drop_fn(self._handle);
        }
        self._handle = 0;
        self._closed = True;
    }

    def __del__(self: object) {
        self.close();
    }

    def __enter__(self: object) -> object {
        return self;
    }

    def __exit__(self: object, *args: object) {
        self.close();
    }

    def __repr__(self: object) -> str {
        state = "closed" if self._closed else f"handle={hex(self._handle)}";
        return f"<{td.name} {state}>";
    }

    cls_dict = {
        "__init__": __init__,
        "close": close,
        "__del__": __del__,
        "__enter__": __enter__,
        "__exit__": __exit__,
        "__repr__": __repr__
    };

    for (fd, c_fn) in method_c {
        cls_dict[fd.name] = _bind_method(td.name, fd, c_fn, rt, classes);
    }

    return type(td.name, (), cls_dict);
}


def build_module(so_path: str, meta: BridgeMeta) -> object {
    lib = CDLL(so_path);

    init_name = f"jac_bridge_init_{meta.module_name}";
    try {
        init_fn = getattr(lib, init_name);
        init_fn.argtypes = [];
        init_fn.restype = c_void_p;
        init_fn();
    } except AttributeError {
        pass;
    }

    rt = _Runtime(lib, meta);

    classes = {};
    for td in meta.types {
        if td.kind == KIND_OPAQUE {
            classes[td.index] = type(td.name, (), {});
        }
    }
    for td in meta.types {
        if td.kind == KIND_OPAQUE {
            classes[td.index] = _make_class(td, meta, lib, rt, classes);
        }
    }

    mod = pytypes.ModuleType(meta.module_name);
    mod.__file__ = so_path;
    for td in meta.types {
        if td.kind == KIND_ERROR {
            setattr(mod, td.name, rt.err_cls(td.index));
        } elif td.kind == KIND_OPAQUE {
            setattr(mod, td.name, classes[td.index]);
        }
    }
    mod.PanicError = rt.PanicError;
    mod._lib = lib;
    mod._meta = meta;
    mod._rt = rt;
    return mod;
}
