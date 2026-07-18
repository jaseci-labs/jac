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
    RecordDesc,
    FieldDesc,
    TAG_VOID,
    TAG_BOOL,
    TAG_INT,
    TAG_STR,
    TAG_WIDE,
    RECORD_KIND_ENUM,
    KIND_OPAQUE,
    KIND_ERROR,
    FN_CTOR,
    FN_METHOD,
    FN_STATIC,
    tag_is_opt,
    tag_is_ref,
    tag_is_borrowed,
    tag_is_shared,
    tag_ref_index,
    tag_is_wide,
    tag_wide_record,
    tag_is_map,
    tag_is_list,
    tag_map_value,
    tag_list_value
}
import from jaclang.compiler.rust_bridge._marshal {
    Slot,
    SlotKind,
    classify,
    STATUS_OK,
    STATUS_ERR,
    STATUS_CB_ERR
}


class BridgeSkip(Exception) {}


def _ret_bridgeable(s: Slot) -> bool {
    if s.kind == SlotKind.Unbridgeable or s.kind == SlotKind.Callback {
        return False;
    }

    if s.is_opt
    and s.kind != SlotKind.Str
    and s.kind != SlotKind.Bytes
    and s.kind != SlotKind.Wide
    and s.kind != SlotKind.OpaqueRef
    and s.kind != SlotKind.Int
    and s.kind != SlotKind.Uint {
        return False;
    }
    return True;
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

        self._cb_keepalive = [];

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

        self.records = meta.records;
        self.record_classes = {};
        for rec in meta.records {
            self.record_classes[rec.index] = _make_enum_class(rec)
                if rec.kind == RECORD_KIND_ENUM
                else _make_record_class(rec);
        }

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

        self._opaque_drops = {};
        self._opaque_retains = {};
        for td in meta.types {
            if td.kind != KIND_OPAQUE {
                continue;
            }
            od = getattr(lib, td.drop_sym);
            od.argtypes = [c_uint64];
            od.restype = None;
            self._opaque_drops[td.index] = od;
            rsym = td.drop_sym[:-len("_drop")] + "_retain";
            orr = getattr(lib, rsym, None);
            if orr is not None {
                orr.argtypes = [c_uint64];
                orr.restype = None;
                self._opaque_retains[td.index] = orr;
            }
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
        if st != STATUS_OK {
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
        if st != STATUS_OK {
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
        s = classify(p.tag);
        if s.kind == SlotKind.Str
        or s.kind == SlotKind.Bytes
        or s.kind == SlotKind.Wide {
            args.extend([c_char_p, c_uint32]);
        } elif s.kind == SlotKind.Bool {
            args.append(c_uint8);
        } elif s.kind == SlotKind.Int
        or s.kind == SlotKind.Uint
        or s.kind == SlotKind.F64
        or s.kind == SlotKind.OpaqueRef
        or s.kind == SlotKind.Callback {
            args.append(c_uint64);
        } else {
            raise BridgeSkip(
                f"{fd.name}: unbridgeable param '{p.name}' (tag=0x{p.tag:08X})"
            );
        }
    }

    ret = classify(fd.ret);
    if not _ret_bridgeable(ret) {
        raise BridgeSkip(f"{fd.name}: unbridgeable return (tag=0x{fd.ret:08X})");
    }
    if ret.kind == SlotKind.Map or ret.kind == SlotKind.List {
        args.append(POINTER(_JacBuf));
    } elif ret.kind == SlotKind.Bool {
        args.append(POINTER(c_uint8));
    } elif ret.kind == SlotKind.Str
    or ret.kind == SlotKind.Bytes
    or ret.kind == SlotKind.Wide {
        args.append(POINTER(_JacBuf));
    } elif (ret.kind == SlotKind.Int or ret.kind == SlotKind.Uint) and ret.is_opt {
        args.append(POINTER(_JacBuf));
    } elif ret.kind != SlotKind.Void {
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
            return STATUS_OK;
        } except Exception {
            return STATUS_CB_ERR;
        }
    }

    return _CB_TYPE(_trampoline);
}


def _read_value(raw: bytes, off: int, vtag: int) -> tuple {
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
    return (val, off);
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
        (val, off) = _read_value(raw, off, vtag);
        out[key] = val;
    }
    return out;
}


def _decode_list(raw: bytes, vtag: int) -> list {
    out = [];
    (count, ) = struct.unpack_from("<I", raw, 0);
    off = 4;
    for _ in range(count) {
        (val, off) = _read_value(raw, off, vtag);
        out.append(val);
    }
    return out;
}


def _mp_read(raw: bytes, off: int, depth: int) -> tuple {
    if depth > 64 {
        raise ValueError("msgpack decode: recursion depth exceeded");
    }
    (lead, ) = struct.unpack_from(">B", raw, off);
    off += 1;

    if lead < 0x80 {
        return (lead, off);
    }
    if lead >= 0xe0 {
        return (lead - 256, off);
    }
    if lead >= 0xa0 and lead < 0xc0 {
        n = lead - 0xa0;
        return (raw[off:off + n].decode("utf-8", errors="replace"), off + n);
    }
    if lead >= 0x80 and lead < 0x90 {
        return _mp_read_map(raw, off, lead - 0x80, depth);
    }
    if lead >= 0x90 and lead < 0xa0 {
        return _mp_read_array(raw, off, lead - 0x90, depth);
    }

    if lead == 0xc0 {
        return (None, off);
    }
    if lead == 0xc2 {
        return (False, off);
    }
    if lead == 0xc3 {
        return (True, off);
    }

    if lead == 0xcc {
        return (struct.unpack_from(">B", raw, off)[0], off + 1);
    }
    if lead == 0xcd {
        return (struct.unpack_from(">H", raw, off)[0], off + 2);
    }
    if lead == 0xce {
        return (struct.unpack_from(">I", raw, off)[0], off + 4);
    }
    if lead == 0xcf {
        return (struct.unpack_from(">Q", raw, off)[0], off + 8);
    }
    if lead == 0xd0 {
        return (struct.unpack_from(">b", raw, off)[0], off + 1);
    }
    if lead == 0xd1 {
        return (struct.unpack_from(">h", raw, off)[0], off + 2);
    }
    if lead == 0xd2 {
        return (struct.unpack_from(">i", raw, off)[0], off + 4);
    }
    if lead == 0xd3 {
        return (struct.unpack_from(">q", raw, off)[0], off + 8);
    }
    if lead == 0xca {
        return (struct.unpack_from(">f", raw, off)[0], off + 4);
    }
    if lead == 0xcb {
        return (struct.unpack_from(">d", raw, off)[0], off + 8);
    }

    if lead == 0xd9 {
        n = struct.unpack_from(">B", raw, off)[0];
        off += 1;
        return (raw[off:off + n].decode("utf-8", errors="replace"), off + n);
    }
    if lead == 0xda {
        n = struct.unpack_from(">H", raw, off)[0];
        off += 2;
        return (raw[off:off + n].decode("utf-8", errors="replace"), off + n);
    }
    if lead == 0xdb {
        n = struct.unpack_from(">I", raw, off)[0];
        off += 4;
        return (raw[off:off + n].decode("utf-8", errors="replace"), off + n);
    }

    if lead == 0xdc {
        n = struct.unpack_from(">H", raw, off)[0];
        return _mp_read_array(raw, off + 2, n, depth);
    }
    if lead == 0xdd {
        n = struct.unpack_from(">I", raw, off)[0];
        return _mp_read_array(raw, off + 4, n, depth);
    }
    if lead == 0xde {
        n = struct.unpack_from(">H", raw, off)[0];
        return _mp_read_map(raw, off + 2, n, depth);
    }
    if lead == 0xdf {
        n = struct.unpack_from(">I", raw, off)[0];
        return _mp_read_map(raw, off + 4, n, depth);
    }
    raise ValueError(f"msgpack decode: unsupported lead byte 0x{lead:02x}");
}


def _mp_read_array(raw: bytes, off: int, count: int, depth: int) -> tuple {
    out = [];
    for _ in range(count) {
        (val, off) = _mp_read(raw, off, depth + 1);
        out.append(val);
    }
    return (out, off);
}


def _mp_read_map(raw: bytes, off: int, count: int, depth: int) -> tuple {
    out = {};
    for _ in range(count) {
        (key, off) = _mp_read(raw, off, depth + 1);
        if not isinstance(key, str) {
            raise ValueError("msgpack decode: non-string map key");
        }
        (val, off) = _mp_read(raw, off, depth + 1);
        out[key] = val;
    }
    return (out, off);
}


def _mp_decode(raw: bytes) -> object {
    (val, _off) = _mp_read(raw, 0, 0);
    return val;
}


def _mp_encode_str(s: str) -> bytes {
    eb = s.encode("utf-8");
    el = len(eb);
    if el < 32 {
        return struct.pack(">B", 0xa0 + el) + eb;
    }
    if el < 256 {
        return struct.pack(">BB", 0xd9, el) + eb;
    }
    if el < 65536 {
        return struct.pack(">BH", 0xda, el) + eb;
    }
    return struct.pack(">BI", 0xdb, el) + eb;
}


def _mp_encode_int(n: int) -> bytes {
    if n >= 0 {
        if n < 0x80 {
            return struct.pack(">B", n);
        }
        if n < 0x10000000000000000 {
            return struct.pack(">B", 0xcf) + struct.pack(">Q", n);
        }
        raise OverflowError("msgpack encode: int exceeds u64");
    }
    if n >= -32 {
        return struct.pack(">B", n + 256);
    }
    if n >= -0x8000000000000000 {
        return struct.pack(">B", 0xd3) + struct.pack(">q", n);
    }
    raise OverflowError("msgpack encode: int below i64");
}


def _mp_encode(val: object) -> bytes {
    if val is None {
        return struct.pack(">B", 0xc0);
    }
    if isinstance(val, bool) {
        return struct.pack(">B", 0xc3 if val else 0xc2);
    }
    if isinstance(val, int) {
        return _mp_encode_int(val);
    }
    if isinstance(val, float) {
        return struct.pack(">B", 0xcb) + struct.pack(">d", val);
    }
    if isinstance(val, str) {
        return _mp_encode_str(val);
    }
    if isinstance(val, list) or isinstance(val, tuple) {
        if len(val) < 16 {
            out = struct.pack(">B", 0x90 + len(val));
        } elif len(val) < 65536 {
            out = struct.pack(">BH", 0xdc, len(val));
        } else {
            out = struct.pack(">BI", 0xdd, len(val));
        }
        for child in val {
            out += _mp_encode(child);
        }
        return out;
    }
    if isinstance(val, dict) {
        if len(val) < 16 {
            out = struct.pack(">B", 0x80 + len(val));
        } elif len(val) < 65536 {
            out = struct.pack(">BH", 0xde, len(val));
        } else {
            out = struct.pack(">BI", 0xdf, len(val));
        }
        for (k, v) in val.items() {
            if not isinstance(k, str) {
                raise TypeError("msgpack encode: map keys must be str");
            }
            out += _mp_encode_str(k) + _mp_encode(v);
        }
        return out;
    }
    raise TypeError(f"msgpack encode: unsupported type {type(val).__name__}");
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

    if fd.kind == FN_METHOD and self_h is not None {
        c_args.append(self_h);
    }

    for (i, p) in enumerate(fd.params) {
        v = py_args[i];
        s = classify(p.tag);
        if s.kind == SlotKind.Str or s.kind == SlotKind.Bytes {
            (enc, n) = _encode(v);
            c_args.extend([enc, c_uint32(n)]);
        } elif s.kind == SlotKind.Wide {
            payload = _rec_to_msg(v, rt.records[s.record - 1], rt)
                if s.record > 0
                else v;
            enc = _mp_encode(payload);
            c_args.extend([enc, c_uint32(len(enc))]);
        } elif s.kind == SlotKind.Bool {
            c_args.append(c_uint8(int(bool(v))));
        } elif s.kind == SlotKind.Int or s.kind == SlotKind.Uint {
            c_args.append(c_uint64(int(v) & 0xFFFFFFFFFFFFFFFF));
        } elif s.kind == SlotKind.F64 {
            (bits, ) = struct.unpack("<Q", struct.pack("<d", float(v)));
            c_args.append(c_uint64(bits));
        } elif s.kind == SlotKind.Callback {
            cb = _make_trampoline(v, rt);
            rec = _JacCallback(cast(cb, c_void_p), None);
            rt._cb_keepalive.append(cb);
            rt._cb_keepalive.append(rec);
            c_args.append(c_uint64(addressof(rec)));
        } elif s.kind == SlotKind.OpaqueRef {
            c_args.append(c_uint64(v._handle));
        } else {
            raise BridgeSkip(f"{fd.name}: unbridgeable param '{p.name}'");
        }
    }

    out_h = c_uint64(0);
    out_b = c_uint8(0);
    out_buf = _JacBuf();
    out_e = c_uint64(0);

    ret = classify(fd.ret);

    if ret.kind == SlotKind.Map or ret.kind == SlotKind.List {
        c_args.append(byref(out_buf));
    } elif ret.kind == SlotKind.Bool {
        c_args.append(byref(out_b));
    } elif ret.kind == SlotKind.Str
    or ret.kind == SlotKind.Bytes
    or ret.kind == SlotKind.Wide {
        c_args.append(byref(out_buf));
    } elif (ret.kind == SlotKind.Int or ret.kind == SlotKind.Uint) and ret.is_opt {
        c_args.append(byref(out_buf));
    } elif ret.kind != SlotKind.Void {
        c_args.append(byref(out_h));
    }

    c_args.append(byref(out_e));

    st = c_fn(*c_args);

    if st == STATUS_ERR {
        msg = rt.drain_err(out_e.value, fd.throws if fd.throws != TAG_VOID else None);
        raise rt.err_cls(fd.throws)(msg);
    }
    if st != STATUS_OK {
        msg = rt.drain_panic(out_e.value);
        raise rt.PanicError(msg);
    }

    if ret.kind == SlotKind.Map {
        if ret.is_opt and out_buf.ptr == 0 {
            return None;
        }
        raw = string_at(out_buf.ptr, out_buf.len) if out_buf.ptr != 0 else b"";
        rt.free_buf(out_buf);
        return _decode_map(raw, tag_map_value(fd.ret));
    }
    if ret.kind == SlotKind.List {
        if ret.is_opt and out_buf.ptr == 0 {
            return None;
        }
        raw = string_at(out_buf.ptr, out_buf.len) if out_buf.ptr != 0 else b"";
        rt.free_buf(out_buf);
        return _decode_list(raw, tag_list_value(fd.ret));
    }
    if ret.kind == SlotKind.Void {
        return None;
    }
    if ret.kind == SlotKind.Bool {
        return bool(out_b.value);
    }
    if ret.kind == SlotKind.Str {
        if ret.is_opt and out_buf.ptr == 0 {
            return None;
        }
        raw = string_at(out_buf.ptr, out_buf.len);
        rt.free_buf(out_buf);
        return raw.decode("utf-8", errors="replace");
    }
    if ret.kind == SlotKind.Bytes {
        if ret.is_opt and out_buf.ptr == 0 {
            return None;
        }

        raw = string_at(out_buf.ptr, out_buf.len);
        rt.free_buf(out_buf);
        return raw;
    }
    if ret.kind == SlotKind.Wide {
        if ret.is_opt and out_buf.ptr == 0 {
            return None;
        }
        raw = string_at(out_buf.ptr, out_buf.len) if out_buf.ptr != 0 else b"";
        rt.free_buf(out_buf);
        decoded = _mp_decode(raw);
        if ret.record > 0 {
            return _rec_from_msg(decoded, rt.records[ret.record - 1], rt);
        }
        return decoded;
    }
    if (ret.kind == SlotKind.Int or ret.kind == SlotKind.Uint) and ret.is_opt {
        if out_buf.ptr == 0 {
            return None;
        }
        raw = string_at(out_buf.ptr, out_buf.len);
        rt.free_buf(out_buf);
        (v, ) = struct.unpack("<Q", raw[:8]);
        if ret.kind == SlotKind.Int and v >= 0x8000000000000000 {
            return v - 0x10000000000000000;
        }
        return v;
    }
    if ret.kind == SlotKind.Int {
        v = out_h.value;
        return v - 0x10000000000000000 if v >= 0x8000000000000000 else v;
    }
    if ret.kind == SlotKind.Uint {
        return out_h.value;
    }
    if ret.kind == SlotKind.F64 {
        (d, ) = struct.unpack("<d", struct.pack("<Q", out_h.value));
        return d;
    }

    h = out_h.value;
    if ret.is_opt and h == 0 {
        return None;
    }
    cls = classes.get(ret.ref_index);
    if cls is None {
        return h;
    }
    stub = object.__new__(cls);
    stub._handle = h;
    stub._closed = False;
    stub._rt = rt;
    stub._finalizer = None;

    own_retain = rt._opaque_retains.get(ret.ref_index);
    if own_retain is not None {
        if tag_is_shared(fd.ret) {
            own_retain(h);
        } elif self_h is not None and h == self_h {
            own_retain(h);
        }
    }

    if tag_is_borrowed(fd.ret) and fd.self_type != TAG_VOID and self_h is not None {
        owner_retain = rt._opaque_retains.get(fd.self_type);
        owner_drop = rt._opaque_drops.get(fd.self_type);
        if owner_retain is not None and owner_drop is not None {
            owner_retain(self_h);
            stub._owner_handle = self_h;
            stub._owner_drop = owner_drop;
        }
    }
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


def _bind_static(
    type_name: str, fd_: FnDesc, c_fn_: object, rt: _Runtime, classes: dict[int, type]
) -> object {
    def static_method(*args: object) -> object {
        return _call(c_fn_, fd_, rt, None, args, classes);
    }
    static_method.__name__ = fd_.name;
    return staticmethod(static_method);
}


def _make_record_class(rec: RecordDesc) -> type {
    field_names = [f.name for f in rec.fields];

    def __init__(self: object, *args: object, **kw: object) {
        if len(args) > len(field_names) {
            raise TypeError(
                f"{rec.name}() takes at most {len(field_names)} positional args"
            );
        }
        for (i, fn) in enumerate(field_names) {
            if i < len(args) {
                setattr(self, fn, args[i]);
            } elif fn in kw {
                setattr(self, fn, kw[fn]);
            } else {
                setattr(self, fn, None);
            }
        }
    }

    def __repr__(self: object) -> str {
        inner = ", ".join([f"{fn}={getattr(self, fn)!r}" for fn in field_names]);
        return f"{rec.name}({inner})";
    }

    def __eq__(self: object, other: object) -> bool {
        if not isinstance(other, type(self)) {
            return NotImplemented;
        }
        return all([getattr(self, fn) == getattr(other, fn) for fn in field_names]);
    }

    return type(
        rec.name,
        (),
        {
            "__init__": __init__,
            "__repr__": __repr__,
            "__eq__": __eq__,
            "__hash__": None,
            "_jac_fields": field_names
        }
    );
}


def _rec_to_dict(v: object, rec: RecordDesc) -> dict {
    if isinstance(v, dict) {
        return v;
    }
    return {f.name: getattr(v, f.name) for f in rec.fields};
}


def _make_enum_class(rec: RecordDesc) -> type {
    variant_names = [f.name for f in rec.fields];

    def __init__(self: object, variant: str, value: object = None) {
        if variant not in variant_names {
            raise ValueError(f"{rec.name}: unknown variant {variant!r}");
        }
        self.variant = variant;
        self.value = value;
    }

    def __repr__(self: object) -> str {
        if self.value is None {
            return f"{rec.name}.{self.variant}";
        }
        return f"{rec.name}.{self.variant}({self.value!r})";
    }

    def __eq__(self: object, other: object) -> bool {
        if not isinstance(other, type(self)) {
            return NotImplemented;
        }
        return self.variant == other.variant and self.value == other.value;
    }

    return type(
        rec.name,
        (),
        {
            "__init__": __init__,
            "__repr__": __repr__,
            "__eq__": __eq__,
            "__hash__": None,
            "_jac_variants": variant_names
        }
    );
}


def _variant_tag(rec: RecordDesc, vname: str) -> int {
    for f in rec.fields {
        if f.name == vname {
            return f.tag;
        }
    }
    raise ValueError(f"{rec.name}: unknown variant {vname!r}");
}


def _field_from_msg(val: object, tag: int, rt: _Runtime) -> object {
    if val is None {
        return None;
    }
    if tag_is_list(tag) {
        et = tag_list_value(tag);
        return [_field_from_msg(x, et, rt) for x in val];
    }
    if tag_is_map(tag) {
        vt = tag_map_value(tag);
        return {k: _field_from_msg(x, vt, rt) for (k, x) in val.items()};
    }
    if tag_is_wide(tag) and tag_wide_record(tag) > 0 {
        return _rec_from_msg(val, rt.records[tag_wide_record(tag) - 1], rt);
    }
    return val;
}


def _field_to_msg(val: object, tag: int, rt: _Runtime) -> object {
    if val is None {
        return None;
    }
    if tag_is_list(tag) {
        et = tag_list_value(tag);
        return [_field_to_msg(x, et, rt) for x in val];
    }
    if tag_is_map(tag) {
        vt = tag_map_value(tag);
        return {k: _field_to_msg(x, vt, rt) for (k, x) in val.items()};
    }
    if tag_is_wide(tag) and tag_wide_record(tag) > 0 {
        return _rec_to_msg(val, rt.records[tag_wide_record(tag) - 1], rt);
    }
    return val;
}


def _rec_from_msg(decoded: object, rec: RecordDesc, rt: _Runtime) -> object {
    cls = rt.record_classes[rec.index];
    if rec.kind == RECORD_KIND_ENUM {
        if isinstance(decoded, str) {
            return cls(variant=decoded, value=None);
        }
        if isinstance(decoded, dict) and len(decoded) == 1 {
            (vname, payload) = next(iter(decoded.items()));
            return cls(
                variant=vname,
                value=_field_from_msg(payload, _variant_tag(rec, vname), rt)
            );
        }
        return decoded;
    }
    if not isinstance(decoded, dict) {
        return decoded;
    }
    kw = {};
    for f in rec.fields {
        if f.name in decoded {
            kw[f.name] = _field_from_msg(decoded[f.name], f.tag, rt);
        }
    }
    return cls(**kw);
}


def _rec_to_msg(v: object, rec: RecordDesc, rt: _Runtime) -> object {
    if rec.kind == RECORD_KIND_ENUM {
        if isinstance(v, str) {
            return v;
        }
        if isinstance(v, dict) {
            return v;
        }
        variant = getattr(v, "variant");
        value = getattr(v, "value");
        vtag = _variant_tag(rec, variant);
        if value is None and vtag == TAG_VOID {
            return variant;
        }
        return {variant: _field_to_msg(value, vtag, rt)};
    }
    if isinstance(v, dict) {
        return {
            f.name: _field_to_msg(v[f.name], f.tag, rt)
            for f in rec.fields
            if f.name in v
        };
    }
    return {f.name: _field_to_msg(getattr(v, f.name), f.tag, rt) for f in rec.fields};
}


def _make_class(
    td: TypeDesc, meta: BridgeMeta, lib: CDLL, rt: _Runtime, classes: dict[int, type]
) -> type {
    drop_fn = getattr(lib, td.drop_sym);
    drop_fn.argtypes = [c_uint64];
    drop_fn.restype = None;

    ctor_fd = None;
    method_fds = [];
    static_fds = [];
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
        } elif fd.kind == FN_STATIC and fd.self_type == td.index {
            static_fds.append(fd);
        }
    }

    ctor_c = None;
    if ctor_fd is not None {
        try {
            ctor_c = _wire(lib, ctor_fd);
        } except BridgeSkip {
            ctor_fd = None;
        }
    }
    method_c = [];
    for fd in method_fds {
        try {
            method_c.append((fd, _wire(lib, fd)));
        } except BridgeSkip {
            continue;
        }
    }
    static_c = [];
    for fd in static_fds {
        try {
            static_c.append((fd, _wire(lib, fd)));
        } except BridgeSkip {
            continue;
        }
    }

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

        if not self._closed {
            od = self?._owner_drop;
            if od is not None {
                od(self._owner_handle);
                self._owner_handle = 0;
                self._owner_drop = None;
            }
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

    for (fd, c_fn) in static_c {
        if fd.name not in cls_dict {
            cls_dict[fd.name] = _bind_static(td.name, fd, c_fn, rt, classes);
        }
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
    } except AttributeError { }

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

    for rec in meta.records {
        setattr(mod, rec.name, rt.record_classes[rec.index]);
    }
    mod.PanicError = rt.PanicError;
    mod._lib = lib;
    mod._meta = meta;
    mod._rt = rt;
    return mod;
}
