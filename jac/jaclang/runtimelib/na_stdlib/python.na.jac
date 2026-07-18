import struct;

import from "libc.so.6" { def strlen(s: str) -> int;  }

import from jacpyembed {
    def jac_engine_boot -> i32;  def jac_py_import(
        name: str, out_handle: bytes, out_err: bytes
    ) -> i32;  def jac_py_getattr(
        target: int, name: str, out_handle: bytes, out_err: bytes
    ) -> i32;  def jac_py_call(
        fnh: int, args_ptr: bytes, args_len: int, out_val: bytes, out_err: bytes
    ) -> i32;  def jac_py_call_h(
        fnh: int, args_ptr: bytes, args_len: int, out_handle: bytes, out_err: bytes
    ) -> i32;  def jac_py_from_int(v: int) -> int;  def jac_py_from_float(
        v: float
    ) -> int;  def jac_py_from_bool(v: int) -> int;  def jac_py_from_str(
        ptr: str, n: int
    ) -> int;  def jac_py_from_bytes(ptr: bytes, n: int) -> int;  def jac_py_none -> int;  def jac_py_to_int(
        target: int, out_val: bytes, out_err: bytes
    ) -> i32;  def jac_py_to_float(
        target: int, out_val: bytes, out_err: bytes
    ) -> i32;  def jac_py_to_bool(target: int, out_val: bytes, out_err: bytes) -> i32;  def jac_py_to_str(
        target: int, out_val: bytes, out_err: bytes
    ) -> i32;  def jac_py_to_bytes(
        target: int, out_val: bytes, out_err: bytes
    ) -> i32;  def jac_py_incref(target: int) -> None;  def jac_py_decref(
        target: int
    ) -> None;  def jac_py_free_buf(ptr: int) -> None;
}


def:priv _fail(out_err: bytes, ctx: str, st: i32) {
    t = struct.unpack("<QII", out_err);
    ptr: int = t[0];
    ln: int = t[1];
    msg: str = ctx + " failed (status " + str(st) + ")";
    if ln > 0 {
        msg = msg + ": " + __jac_str_from_raw(ptr, ln);
    }
    if ptr != 0 {
        jac_py_free_buf(ptr);
    }
    raise RuntimeError(msg);
}


obj:pub Args {
    has _body: list[int] = [],
        _count: int = 0,
        _total: int = 0;

    def init {
        self._body = [];
        self._count = 0;
        self._total = 0;
    }

    def _emit_be(v: int, nbytes: int) {
        i: int = nbytes - 1;
        while i >= 0 {
            self._body.append((v >> (8 * i)) & 0xFF);
            i -= 1;
        }
    }

    def add_none {
        self._body.append(0xC0);
        self._count += 1;
    }

    def add_bool(v: bool) {
        if v {
            self._body.append(0xC3);
        } else {
            self._body.append(0xC2);
        }
        self._count += 1;
    }

    def add_int(v: int) {
        if v >= 0 and v <= 0x7F {
            self._body.append(v);
        } elif v < 0 and v >= -32 {
            self._body.append(0xE0 | (v & 0x1F));
        } else {
            self._body.append(0xD3);
            self._emit_be(v, 8);
        }
        self._count += 1;
    }

    def add_float(v: float) {
        bits: int = struct.unpack("<Q", struct.pack("<d", v))[0];
        self._body.append(0xCB);
        self._emit_be(bits, 8);
        self._count += 1;
    }

    def add_str(s: str) {
        n: int = strlen(s);
        if n <= 31 {
            self._body.append(0xA0 | n);
        } elif n <= 0xFF {
            self._body.append(0xD9);
            self._body.append(n);
        } elif n <= 0xFFFF {
            self._body.append(0xDA);
            self._emit_be(n, 2);
        } else {
            self._body.append(0xDB);
            self._emit_be(n, 4);
        }
        i: int = 0;
        while i < n {
            self._body.append(ord(s[i]) & 0xFF);
            i += 1;
        }
        self._count += 1;
    }

    def finish -> bytes {
        out: bytes = _pack_array(self._body, self._count);
        self._total = len(out);
        return out;
    }

    def size -> int {
        return self._total;
    }
}


def:priv _pack_array(body: list[int], count: int) -> bytes {
    full: list[int] = [];
    if count <= 15 {
        full.append(0x90 | count);
    } elif count <= 0xFFFF {
        full.append(0xDC);
        full.append((count >> 8) & 0xFF);
        full.append(count & 0xFF);
    } else {
        full.append(0xDD);
        full.append((count >> 24) & 0xFF);
        full.append((count >> 16) & 0xFF);
        full.append((count >> 8) & 0xFF);
        full.append(count & 0xFF);
    }
    for x in body {
        full.append(x);
    }
    return bytes(full);
}


obj:pub PyObj {
    has __handle: int = 0,
        __closed: bool = True;

    def init(handle: int) {
        self.__handle = handle;
        self.__closed = handle == 0;
    }

    def handle -> int {
        return self.__handle;
    }

    def getattr(name: str) -> PyObj {
        oh = struct.pack("<Q", 0);
        oe = struct.pack("<QII", 0, 0, 0);
        st: i32 = jac_py_getattr(self.__handle, name, oh, oe);
        if st != 0 {
            _fail(oe, "getattr '" + name + "'", st);
        }
        return PyObj(struct.unpack("<Q", oh)[0]);
    }

    def call(args: Args) -> PyObj {
        blob = args.finish();
        n: int = args.size();
        oh = struct.pack("<Q", 0);
        oe = struct.pack("<QII", 0, 0, 0);
        st: i32 = jac_py_call_h(self.__handle, blob, n, oh, oe);
        if st != 0 {
            _fail(oe, "call", st);
        }
        return PyObj(struct.unpack("<Q", oh)[0]);
    }

    def call_raw(args: Args) -> bytes {
        blob = args.finish();
        n: int = args.size();
        ov = struct.pack("<QII", 0, 0, 0);
        oe = struct.pack("<QII", 0, 0, 0);
        st: i32 = jac_py_call(self.__handle, blob, n, ov, oe);
        if st != 0 {
            _fail(oe, "call_raw", st);
        }
        t = struct.unpack("<QII", ov);
        ptr: int = t[0];
        ln: int = t[1];
        out: bytes = __jac_bytes_from_raw(ptr, ln);
        if ptr != 0 {
            jac_py_free_buf(ptr);
        }
        return out;
    }

    def to_int -> int {
        ov = struct.pack("<q", 0);
        oe = struct.pack("<QII", 0, 0, 0);
        st: i32 = jac_py_to_int(self.__handle, ov, oe);
        if st != 0 {
            _fail(oe, "to_int", st);
        }
        return struct.unpack("<q", ov)[0];
    }

    def to_float -> float {
        ov = struct.pack("<d", 0.0);
        oe = struct.pack("<QII", 0, 0, 0);
        st: i32 = jac_py_to_float(self.__handle, ov, oe);
        if st != 0 {
            _fail(oe, "to_float", st);
        }
        return struct.unpack("<d", ov)[0];
    }

    def to_bool -> bool {
        ov = struct.pack("<i", 0);
        oe = struct.pack("<QII", 0, 0, 0);
        st: i32 = jac_py_to_bool(self.__handle, ov, oe);
        if st != 0 {
            _fail(oe, "to_bool", st);
        }
        return struct.unpack("<i", ov)[0] != 0;
    }

    def to_str -> str {
        ov = struct.pack("<QII", 0, 0, 0);
        oe = struct.pack("<QII", 0, 0, 0);
        st: i32 = jac_py_to_str(self.__handle, ov, oe);
        if st != 0 {
            _fail(oe, "to_str", st);
        }
        t = struct.unpack("<QII", ov);
        ptr: int = t[0];
        ln: int = t[1];
        out: str = __jac_str_from_raw(ptr, ln);
        if ptr != 0 {
            jac_py_free_buf(ptr);
        }
        return out;
    }

    def to_bytes -> bytes {
        ov = struct.pack("<QII", 0, 0, 0);
        oe = struct.pack("<QII", 0, 0, 0);
        st: i32 = jac_py_to_bytes(self.__handle, ov, oe);
        if st != 0 {
            _fail(oe, "to_bytes", st);
        }
        t = struct.unpack("<QII", ov);
        ptr: int = t[0];
        ln: int = t[1];
        out: bytes = __jac_bytes_from_raw(ptr, ln);
        if ptr != 0 {
            jac_py_free_buf(ptr);
        }
        return out;
    }

    def close {
        if not self.__closed {
            jac_py_decref(self.__handle);
            self.__handle = 0;
            self.__closed = True;
        }
    }

    def __del__ {
        self.close();
    }
}


def:pub py_boot -> i32 {
    return jac_engine_boot();
}


def:pub py_import(name: str) -> PyObj {
    oh = struct.pack("<Q", 0);
    oe = struct.pack("<QII", 0, 0, 0);
    st: i32 = jac_py_import(name, oh, oe);
    if st != 0 {
        _fail(oe, "import '" + name + "'", st);
    }
    return PyObj(struct.unpack("<Q", oh)[0]);
}


def:pub py_none -> PyObj {
    return PyObj(jac_py_none());
}


def:pub py_int(v: int) -> PyObj {
    h: int = jac_py_from_int(v);
    if h == 0 {
        raise RuntimeError("py_int: object creation failed");
    }
    return PyObj(h);
}


def:pub py_float(v: float) -> PyObj {
    h: int = jac_py_from_float(v);
    if h == 0 {
        raise RuntimeError("py_float: object creation failed");
    }
    return PyObj(h);
}


def:pub py_bool(v: bool) -> PyObj {
    iv: int = 0;
    if v {
        iv = 1;
    }
    h: int = jac_py_from_bool(iv);
    if h == 0 {
        raise RuntimeError("py_bool: object creation failed");
    }
    return PyObj(h);
}


def:pub py_str(s: str) -> PyObj {
    h: int = jac_py_from_str(s, strlen(s));
    if h == 0 {
        raise RuntimeError("py_str: object creation failed");
    }
    return PyObj(h);
}


def:pub py_bytes(data: bytes) -> PyObj {
    h: int = jac_py_from_bytes(data, len(data));
    if h == 0 {
        raise RuntimeError("py_bytes: object creation failed");
    }
    return PyObj(h);
}
