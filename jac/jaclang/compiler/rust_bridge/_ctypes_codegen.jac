import weakref;
import types as pytypes;
import from ctypes {
    Structure,
    CDLL,
    CFUNCTYPE,
    POINTER,
    byref,
    string_at,
    c_uint64,
    c_uint32,
    c_uint8,
    c_char_p,
    c_int,
    c_void_p
}
import from jaclang.compiler.rust_bridge._blob {
    TAG_VOID,
    TAG_BOOL,
    TAG_STR,
    TAG_FN,
    TAG_REF_BIT,
    TAG_OPT_BIT,
    KIND_OPAQUE,
    KIND_ERROR,
    FN_CTOR,
    FN_METHOD
}


class _JacBuf(Structure) {
    with entry {
        _fields_ = [('ptr', c_uint64), ('len', c_uint32), ('cap', c_uint32)];
    }
}


glob _CB_TYPE = CFUNCTYPE(
         c_int, c_void_p, c_uint32, POINTER(_JacBuf), POINTER(c_uint64)
     );


def _encode(val: object) -> tuple {
    enc = val.encode("utf-8") if isinstance(val, str) else val;
    return (enc, len(enc));
}


class _Runtime {
    def init(self: _Runtime, lib: object, meta: object) {
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

    def drain_err(self: _Runtime, err_h: int, throws_idx: object = None) -> str {
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

    def err_cls(self: _Runtime, throws_idx: int) -> type {
        return self._err_cls.get(throws_idx, Exception);
    }
}


def _wire(lib: object, fd: object) -> object {
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
            args.append(_CB_TYPE);
        } else {
            args.append(c_uint64);
        }
    }

    base_ret = fd.ret & ~TAG_OPT_BIT;
    if base_ret == TAG_BOOL {
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


def _make_trampoline(fn: object, rt: object) -> object {
    make_buf = rt.make_buf;
    if make_buf is None {
        raise RuntimeError("bridge has a callback param but exports no make_buf");
    }

    def _trampoline(ptr: int, n: int, out_buf: object, _out_err: object) -> int {
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


def _call(
    c_fn: object, fd: object, rt: object, self_h: object, py_args: object, classes: dict
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
        } elif p.tag == TAG_FN {
            cb = _make_trampoline(v, rt);
            keepalive.append(cb);
            c_args.append(cb);
        } else {
            c_args.append(c_uint64(int(v)));
        }
    }

    out_h = c_uint64(0);
    out_b = c_uint8(0);
    out_buf = _JacBuf();
    out_e = c_uint64(0);

    opt = bool(fd.ret & TAG_OPT_BIT);
    base_ret = fd.ret & ~TAG_OPT_BIT;

    if base_ret == TAG_BOOL {
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
        msg = rt.drain_err(out_e.value);
        raise rt.PanicError(msg);
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

    h = out_h.value;
    if opt and h == 0 {
        return None;
    }
    ret_idx = base_ret & ~TAG_REF_BIT;
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
    type_name: str, fd_: object, c_fn_: object, rt: object, classes: dict
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
    td: object, meta: object, lib: object, rt: object, classes: dict
) -> type {
    drop_fn = getattr(lib, td.drop_sym);
    drop_fn.argtypes = [c_uint64];
    drop_fn.restype = None;

    ctor_fd = None;
    method_fds = [];
    for fd in meta.fns {
        if fd.kind == FN_CTOR and fd.ret == (TAG_REF_BIT | td.index) {
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


def build_module(so_path: str, meta: object) -> object {
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
