import ctypes;
import pathlib;

glob _JacBuf: type = type(
         "JacBuf",
         (ctypes.Structure, ),
         {
             "_fields_": [
                 ("ptr", ctypes.c_uint64),
                 ("len", ctypes.c_uint32),
                 ("cap", ctypes.c_uint32),

             ]
         },
     ),
     _lib_box: list = [None];

def _find_lib_path -> str {
    pkg = pathlib.Path(__file__).resolve().parent.parent;
    ws = pkg.parent;
    for _sr in [ws, pkg] {
        for build in ["release", "debug"] {
            for stem in [
                "libjac_bridge_regex.so",
                "libjac_bridge_regex.dylib",
                "jac_bridge_regex.dll"
            ] {
                p = _sr / "target" / build / stem;
                if p.exists() {
                    return str(p);
                }
            }
        }
    }
    raise FileNotFoundError(
        "libjac_bridge_regex not found -- run: cargo build --release"
    );
}

def _load_lib -> object {
    if _lib_box[0] is not None {
        return _lib_box[0];
    }
    lib = ctypes.CDLL(_find_lib_path());
    lib.jac_bridge_init_regex.argtypes = [];
    lib.jac_bridge_init_regex.restype = ctypes.c_uint64;
    lib.jac_regex_Regex_new.argtypes = [
        ctypes.c_char_p,
        ctypes.c_uint32,
        ctypes.POINTER(ctypes.c_uint64),
        ctypes.POINTER(ctypes.c_uint64),

    ];
    lib.jac_regex_Regex_new.restype = ctypes.c_int;
    lib.jac_regex_Regex_is_match.argtypes = [
        ctypes.c_uint64,
        ctypes.c_char_p,
        ctypes.c_uint32,
        ctypes.POINTER(ctypes.c_uint8),
        ctypes.POINTER(ctypes.c_uint64),

    ];
    lib.jac_regex_Regex_is_match.restype = ctypes.c_int;
    lib.jac_regex_Regex_drop.argtypes = [ctypes.c_uint64];
    lib.jac_regex_Regex_drop.restype = None;
    lib.jac_regex_error_message.argtypes = [
        ctypes.c_uint64,
        ctypes.POINTER(_JacBuf),
        ctypes.POINTER(ctypes.c_uint64),

    ];
    lib.jac_regex_error_message.restype = ctypes.c_int;
    lib.jac_regex_error_drop.argtypes = [ctypes.c_uint64];
    lib.jac_regex_error_drop.restype = None;
    lib.jac_regex_free_buf.argtypes = [_JacBuf];
    lib.jac_regex_free_buf.restype = None;
    _lib_box[0] = lib;
    return lib;
}

glob _ST_OK: int = 0,
     _ST_ERR: int = 1,
     RegexError: type = type("RegexError", (Exception, ), {}),
     PanicError: type = type("PanicError", (Exception, ), {});

def _drain_err(lib: object, err_h: int) -> str {
    buf = _JacBuf();
    out_e = ctypes.c_uint64(0);
    st = lib.jac_regex_error_message(err_h, ctypes.byref(buf), ctypes.byref(out_e));
    if st != 0 {
        lib.jac_regex_error_drop(err_h);
        return f"<panic reading error: status={st}>";
    }
    msg = ctypes.string_at(buf.ptr, buf.len).decode("utf-8", errors="replace");
    lib.jac_regex_free_buf(buf);
    lib.jac_regex_error_drop(err_h);
    return msg;
}

obj Regex {
    has _handle: int = 0,
        _closed: bool = True,
        _lib: object = None;

    def init(pattern: str) {
        lib = _load_lib();
        enc = pattern.encode("utf-8");
        out_h = ctypes.c_uint64(0);
        out_e = ctypes.c_uint64(0);
        st = lib.jac_regex_Regex_new(
            enc, len(enc), ctypes.byref(out_h), ctypes.byref(out_e)
        );
        if st == _ST_OK {
            self._handle = out_h.value;
            self._lib = lib;
            self._closed = False;
        } elif st == _ST_ERR {
            raise RegexError(_drain_err(lib, out_e.value));
        } else {
            raise PanicError(
                f"Rust panic in Regex::new: {_drain_err(lib, out_e.value)}"
            );
        }
    }

    def is_match(text: str) -> bool {
        if self._closed {
            raise RuntimeError("Regex.is_match called after close()");
        }
        enc = text.encode("utf-8");
        out_b = ctypes.c_uint8(0);
        out_e = ctypes.c_uint64(0);
        st = self._lib.jac_regex_Regex_is_match(
            self._handle, enc, len(enc), ctypes.byref(out_b), ctypes.byref(out_e),
        );
        if st == _ST_OK {
            return bool(out_b.value);
        }
        msg = _drain_err(self._lib, out_e.value);
        if st == _ST_ERR {
            raise RegexError(msg);
        }
        raise PanicError(f"Rust panic in is_match: {msg}");
    }

    def close {
        if not self._closed {
            self._lib.jac_regex_Regex_drop(self._handle);
            self._handle = 0;
            self._closed = True;
        }
    }

    def __del__ {
        self.close();
    }

    def __enter__ -> Regex {
        return self;
    }

    def __exit__(exc_type: object, exc: object, tb: object) -> object {
        self.close();
        return None;
    }
}
