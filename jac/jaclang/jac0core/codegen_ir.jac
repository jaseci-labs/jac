import struct;
import from jaclang.jac0core.jcir_facts { jcir_python_version }

glob CIR_MAGIC: bytes = b"JCIR",
     CIR_FORMAT_VERSION: int = 1,
     CIR_TERMINATOR: int = 254,
     OP_NONE: int = 1,
     OP_TRUE: int = 2,
     OP_FALSE: int = 3,
     OP_ELLIPSIS: int = 4,
     OP_INT: int = 5,
     OP_INT_BIG: int = 6,
     OP_FLOAT: int = 7,
     OP_STR: int = 8,
     OP_BYTES: int = 9,
     OP_LIST: int = 10,
     OP_TUPLE: int = 11,
     OP_NODE: int = 12,
     OP_LOC: int = 13,
     OP_PARSE_SPLICE: int = 14,
     OP_END: int = 15,
     DIAG_WARNING: int = 0,
     DIAG_ERROR: int = 1,
     _I64_MIN: int = -9223372036854775808,
     _I64_MAX: int = 9223372036854775807;

class CodegenIrError(RuntimeError) {}

class CodegenIrVersionError(CodegenIrError) {}

class CodegenIrFormatError(CodegenIrError) {}

def cir_python_version -> int {
    return jcir_python_version();
}

obj CirDiag {
    has message: str,
        code_str: str = "",
        mod_path: str = "",
        severity: int = DIAG_ERROR,
        help: str = "",
        first_line: int = 0,
        col_start: int = 0,
        last_line: int = 0,
        col_end: int = 0;
}

obj CirModule {
    has mod_path: str,
        code: bytes;
}

obj CirContainer {
    has format_version: int = CIR_FORMAT_VERSION,
        python_version: int = 0,
        class_names: list[str] = [],
        key_names: list[str] = [],
        strings: list[str] = [],
        modules: list[CirModule] = [],
        diags: list[CirDiag] = [];
}

def _w_varint(buf: bytearray, v: int) -> None {
    if v < 0 {
        raise CodegenIrFormatError(f"varint cannot encode negative value {v}");
    }
    while True {
        b = v & 127;
        v >>= 7;
        if v {
            buf.append(b | 128);
        } else {
            buf.append(b);
            return;
        }
    }
}

def _w_svarint(buf: bytearray, v: int) {
    u = (v << 1) if v >= 0 else (((-v) << 1) - 1);
    _w_varint(buf, u);
}

def _r_varint(data: bytes, pos: int, what: str) -> tuple[int, int] {
    value = 0;
    shift = 0;
    while True {
        if pos >= len(data) {
            raise CodegenIrFormatError(
                f"truncated container: varint for {what} runs past the end"
            );
        }
        b = data[pos];
        pos += 1;
        value |= (b & 127) << shift;
        if not (b & 128) {
            return (value, pos);
        }
        shift += 7;
    }
}

def _r_svarint(data: bytes, pos: int, what: str) -> tuple[int, int] {
    (u, pos) = _r_varint(data, pos, what);
    v = (u >> 1) if not (u & 1) else -((u + 1) >> 1);
    return (v, pos);
}

def _w_str_entry(buf: bytearray, s: str) {
    raw = s.encode("utf-8");
    _w_varint(buf, len(raw));
    buf.extend(raw);
}

def _r_str_entry(data: bytes, pos: int, what: str) -> tuple[str, int] {
    (n, pos) = _r_varint(data, pos, what);
    if pos + n > len(data) {
        raise CodegenIrFormatError(
            f"truncated container: {what} string body runs past the end"
        );
    }
    s = data[pos:pos + n].decode("utf-8");
    return (s, pos + n);
}

obj CodegenIrWriter {
    has class_names: list[str] = [],
        class_idx: dict[str, int] = {},
        key_names: list[str] = [],
        key_idx: dict[str, int] = {},
        strings: list[str] = [],
        string_idx: dict[str, int] = {},
        modules: list[CirModule] = [],
        diags: list[CirDiag] = [],
        _code: any = None,
        _mod_path: str = "",
        _depth: int = 0,
        _loc_set: bool = False,
        _loc_l1: int = 0,
        _loc_c1: int = 0,
        _loc_l2: int = 0,
        _loc_c2: int = 0;

    def class_ref(name: str) -> int {
        if name in self.class_idx {
            return self.class_idx[name];
        }
        idx = len(self.class_names);
        self.class_names.append(name);
        self.class_idx[name] = idx;
        return idx;
    }

    def key_ref(name: str) -> int {
        if name in self.key_idx {
            return self.key_idx[name];
        }
        idx = len(self.key_names);
        self.key_names.append(name);
        self.key_idx[name] = idx;
        return idx;
    }

    def str_ref(s: str) -> int {
        if s in self.string_idx {
            return self.string_idx[s];
        }
        idx = len(self.strings);
        self.strings.append(s);
        self.string_idx[s] = idx;
        return idx;
    }

    def _require_open {
        if self._code is None {
            raise CodegenIrFormatError(
                "no module is open: call begin_module before emitting"
            );
        }
    }

    def begin_module(mod_path: str) {
        if self._code is not None {
            raise CodegenIrFormatError(
                f"module {self._mod_path} is still open; call end_module first"
            );
        }
        self._code = bytearray();
        self._mod_path = mod_path;
        self._depth = 0;
        self._loc_set = False;
        self._loc_l1 = 0;
        self._loc_c1 = 0;
        self._loc_l2 = 0;
        self._loc_c2 = 0;
    }

    def emit_none {
        self._require_open();
        self._code.append(OP_NONE);
        self._depth += 1;
    }

    def emit_true {
        self._require_open();
        self._code.append(OP_TRUE);
        self._depth += 1;
    }

    def emit_false {
        self._require_open();
        self._code.append(OP_FALSE);
        self._depth += 1;
    }

    def emit_ellipsis {
        self._require_open();
        self._code.append(OP_ELLIPSIS);
        self._depth += 1;
    }

    def emit_int(v: int) {
        self._require_open();
        if v >= _I64_MIN and v <= _I64_MAX {
            self._code.append(OP_INT);
            _w_svarint(self._code, v);
        } else {
            self._code.append(OP_INT_BIG);
            mag = -v if v < 0 else v;
            nbytes = (mag.bit_length() + 7) // 8;
            self._code.append(1 if v < 0 else 0);
            _w_varint(self._code, nbytes);
            self._code.extend(mag.to_bytes(nbytes, "little"));
        }
        self._depth += 1;
    }

    def emit_float(v: float) {
        self._require_open();
        self._code.append(OP_FLOAT);
        self._code.extend(struct.pack("<d", v));
        self._depth += 1;
    }

    def emit_str(s: str) {
        self._require_open();
        self._code.append(OP_STR);
        _w_varint(self._code, self.str_ref(s));
        self._depth += 1;
    }

    def emit_bytes(b: bytes) {
        self._require_open();
        self._code.append(OP_BYTES);
        _w_varint(self._code, len(b));
        self._code.extend(b);
        self._depth += 1;
    }

    def emit_list(n: int) {
        self._require_open();
        if n > self._depth {
            raise CodegenIrFormatError(
                f"emit_list({n}) with only {self._depth} values on the stack"
            );
        }
        self._code.append(OP_LIST);
        _w_varint(self._code, n);
        self._depth -= n - 1;
    }

    def emit_tuple(n: int) {
        self._require_open();
        if n > self._depth {
            raise CodegenIrFormatError(
                f"emit_tuple({n}) with only {self._depth} values on the stack"
            );
        }
        self._code.append(OP_TUPLE);
        _w_varint(self._code, n);
        self._depth -= n - 1;
    }

    def emit_loc(first_line: int, col_start: int, last_line: int, col_end: int) {
        self._require_open();
        self._code.append(OP_LOC);
        _w_svarint(self._code, first_line - self._loc_l1);
        _w_svarint(self._code, col_start - self._loc_c1);
        _w_svarint(self._code, last_line - self._loc_l2);
        _w_svarint(self._code, col_end - self._loc_c2);
        self._loc_l1 = first_line;
        self._loc_c1 = col_start;
        self._loc_l2 = last_line;
        self._loc_c2 = col_end;
        self._loc_set = True;
    }

    def emit_loc_needed(first_line: int, col_start: int, last_line: int, col_end: int) {
        self._require_open();
        if (
            self._loc_set
            and self._loc_l1 == first_line
            and self._loc_c1 == col_start
            and self._loc_l2 == last_line
            and self._loc_c2 == col_end
        ) {
            return;
        }
        self.emit_loc(first_line, col_start, last_line, col_end);
    }

    def emit_node(class_name: str, field_names: list) {
        self._require_open();
        if not self._loc_set {
            raise CodegenIrFormatError(
                f"emit_node({class_name}) before any emit_loc in {self._mod_path}: "
                "every module stream must set the location register first"
            );
        }
        n = len(field_names);
        if n > self._depth {
            raise CodegenIrFormatError(
                f"emit_node({class_name}) pops {n} values but only {self._depth} are on the stack"
            );
        }
        self._code.append(OP_NODE);
        _w_varint(self._code, self.class_ref(class_name));
        _w_varint(self._code, n);
        for fname in field_names {
            _w_varint(self._code, self.key_ref(fname));
        }
        self._depth -= n - 1;
    }

    def emit_parse_splice(src: str, line_offset: int = 0) {
        self._require_open();
        self._code.append(OP_PARSE_SPLICE);
        _w_varint(self._code, self.str_ref(src));
        _w_varint(self._code, line_offset);
        self._depth += 1;
    }

    def end_module {
        self._require_open();
        if self._depth != 1 {
            raise CodegenIrFormatError(
                f"end_module on {self._mod_path} with stack depth {self._depth}; "
                "a module stream must leave exactly one root value"
            );
        }
        self._code.append(OP_END);
        frozen: bytearray = self._code;
        self.modules.append(CirModule(mod_path=self._mod_path, code=bytes(frozen)));
        self._code = None;
        self._mod_path = "";
    }

    def add_diag(diag: CirDiag) {
        self.diags.append(diag);
    }

    def to_bytes -> bytes {
        if self._code is not None {
            raise CodegenIrFormatError(
                f"module {self._mod_path} is still open; call end_module before to_bytes"
            );
        }
        for m in self.modules {
            self.str_ref(m.mod_path);
        }
        for d in self.diags {
            self.str_ref(d.code_str);
            self.str_ref(d.message);
            self.str_ref(d.help);
            self.str_ref(d.mod_path);
        }
        buf = bytearray();
        buf.extend(CIR_MAGIC);
        buf.extend(struct.pack("<H", CIR_FORMAT_VERSION));
        buf.extend(struct.pack("<H", cir_python_version()));
        _w_varint(buf, len(self.class_names));
        for cn in self.class_names {
            _w_str_entry(buf, cn);
        }
        _w_varint(buf, len(self.key_names));
        for kn in self.key_names {
            _w_str_entry(buf, kn);
        }
        _w_varint(buf, len(self.strings));
        for s in self.strings {
            _w_str_entry(buf, s);
        }
        _w_varint(buf, len(self.modules));
        for m in self.modules {
            _w_varint(buf, self.str_ref(m.mod_path));
            _w_varint(buf, len(m.code));
            buf.extend(m.code);
        }
        _w_varint(buf, len(self.diags));
        for d in self.diags {
            buf.append(int(d.severity) & 255);
            _w_varint(buf, self.str_ref(d.code_str));
            _w_varint(buf, self.str_ref(d.message));
            _w_varint(buf, self.str_ref(d.help));
            _w_varint(buf, self.str_ref(d.mod_path));
            _w_varint(buf, d.first_line);
            _w_varint(buf, d.col_start);
            _w_varint(buf, d.last_line);
            _w_varint(buf, d.col_end);
        }
        buf.append(CIR_TERMINATOR);
        return bytes(buf);
    }
}

def read_container(data: bytes) -> CirContainer {
    if len(data) < 8 {
        raise CodegenIrFormatError(
            f"container is {len(data)} bytes; a JCIR header needs 8"
        );
    }
    if data[0:4] != CIR_MAGIC {
        raise CodegenIrFormatError("not a JCIR container: bad magic");
    }
    (fmt_ver, py_ver) = struct.unpack("<HH", data[4:8]);
    if fmt_ver != CIR_FORMAT_VERSION {
        raise CodegenIrVersionError(
            f"JCIR format version {fmt_ver} does not match this runtime's "
            f"{CIR_FORMAT_VERSION}; refusing to read"
        );
    }
    if py_ver != cir_python_version() {
        want = cir_python_version();
        raise CodegenIrVersionError(
            f"JCIR container targets Python {py_ver >> 8}.{py_ver & 255} but this "
            f"build targets Python {want >> 8}.{want & 255}; refusing to read"
        );
    }
    pos = 8;
    (n_classes, pos) = _r_varint(data, pos, "class table size");
    class_names: list[str] = [];
    i = 0;
    while i < n_classes {
        (cn, pos) = _r_str_entry(data, pos, "class name");
        class_names.append(cn);
        i += 1;
    }
    (n_keys, pos) = _r_varint(data, pos, "key table size");
    key_names: list[str] = [];
    i = 0;
    while i < n_keys {
        (kn, pos) = _r_str_entry(data, pos, "key name");
        key_names.append(kn);
        i += 1;
    }
    (n_strings, pos) = _r_varint(data, pos, "string pool size");
    strings: list[str] = [];
    i = 0;
    while i < n_strings {
        (s, pos) = _r_str_entry(data, pos, "string pool entry");
        strings.append(s);
        i += 1;
    }
    (n_modules, pos) = _r_varint(data, pos, "module count");
    modules: list[CirModule] = [];
    i = 0;
    while i < n_modules {
        (path_ref, pos) = _r_varint(data, pos, "module path ref");
        if path_ref >= len(strings) {
            raise CodegenIrFormatError(
                f"module path ref {path_ref} is outside the string pool"
            );
        }
        (code_len, pos) = _r_varint(data, pos, "module code length");
        if pos + code_len > len(data) {
            raise CodegenIrFormatError(
                "truncated container: module code runs past the end"
            );
        }
        modules.append(
            CirModule(mod_path=strings[path_ref], code=data[pos:pos + code_len])
        );
        pos += code_len;
        i += 1;
    }
    (n_diags, pos) = _r_varint(data, pos, "diagnostic count");
    diags: list[CirDiag] = [];
    i = 0;
    while i < n_diags {
        if pos >= len(data) {
            raise CodegenIrFormatError(
                "truncated container: diagnostic severity runs past the end"
            );
        }
        severity = data[pos];
        pos += 1;
        refs: list[int] = [];
        j = 0;
        while j < 4 {
            (r, pos) = _r_varint(data, pos, "diagnostic string ref");
            if r >= len(strings) {
                raise CodegenIrFormatError(
                    f"diagnostic string ref {r} is outside the string pool"
                );
            }
            refs.append(r);
            j += 1;
        }
        (l1, pos) = _r_varint(data, pos, "diagnostic first_line");
        (c1, pos) = _r_varint(data, pos, "diagnostic col_start");
        (l2, pos) = _r_varint(data, pos, "diagnostic last_line");
        (c2, pos) = _r_varint(data, pos, "diagnostic col_end");
        diags.append(
            CirDiag(
                message=strings[refs[1]],
                code_str=strings[refs[0]],
                mod_path=strings[refs[3]],
                severity=severity,
                help=strings[refs[2]],
                first_line=l1,
                col_start=c1,
                last_line=l2,
                col_end=c2
            )
        );
        i += 1;
    }
    if pos >= len(data) or data[pos] != CIR_TERMINATOR {
        raise CodegenIrFormatError("truncated container: terminator byte is missing");
    }
    if pos + 1 != len(data) {
        raise CodegenIrFormatError(
            f"{len(data) - pos - 1} trailing bytes after the terminator"
        );
    }
    return CirContainer(
        format_version=fmt_ver,
        python_version=py_ver,
        class_names=class_names,
        key_names=key_names,
        strings=strings,
        modules=modules,
        diags=diags
    );
}
