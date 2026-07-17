import from jaclang.compiler.rust_bridge._blob {
    BridgeMeta,
    FnDesc,
    ParamDesc,
    FN_CTOR,
    FN_METHOD,
    FN_STATIC,
    KIND_ERROR,
    KIND_OPAQUE,
    TAG_BOOL,
    TAG_FN,
    TAG_INT,
    TAG_UINT,
    TAG_F64,
    TAG_STR,
    TAG_WIDE,
    TAG_VOID,
    tag_base,
    tag_is_opt,
    tag_is_ref,
    tag_ref_index,
    tag_is_borrowed,
    tag_is_shared,
    tag_is_map,
    tag_is_list,
    tag_map_value,
    tag_list_value,
    tag_is_wide,
    TAG_WIDE_REC_MASK,
    RecordDesc,
    FieldDesc
}
import from jaclang.compiler.rust_bridge._finder { _libc_soname }
import from jaclang.compiler.rust_bridge._marshal {
    SlotKind,
    Slot,
    classify,
    classify_scalar,
    STATUS_OK,
    STATUS_ERR,
    STATUS_PANIC,
    STATUS_CB_ERR
}


glob _JAC_RESERVED: set[str] = {
         "str",
         "int",
         "float",
         "list",
         "tuple",
         "set",
         "dict",
         "bool",
         "bytes",
         "any",
         "type",
         "i8",
         "u8",
         "i16",
         "u16",
         "i32",
         "u32",
         "i64",
         "u64",
         "f32",
         "f64",
         "abs",
         "obj",
         "class",
         "enum",
         "node",
         "edge",
         "walker",
         "has",
         "can",
         "def",
         "static",
         "override",
         "impl",
         "getter",
         "setter",
         "deleter",
         "sem",
         "test",
         "glob",
         "global",
         "nonlocal",
         "import",
         "include",
         "from",
         "as",
         "if",
         "elif",
         "else",
         "for",
         "to",
         "by",
         "while",
         "match",
         "switch",
         "case",
         "default",
         "try",
         "except",
         "finally",
         "awaiting",
         "with",
         "return",
         "yield",
         "break",
         "continue",
         "raise",
         "del",
         "assert",
         "skip",
         "report",
         "visit",
         "spawn",
         "entry",
         "exit",
         "disengage",
         "here",
         "visitor",
         "root",
         "async",
         "await",
         "flow",
         "wait",
         "and",
         "or",
         "not",
         "in",
         "is",
         "lambda",
         "pub",
         "priv",
         "protect",
         "cl",
         "sv",
         "na",
         "self",
         "props",
         "init",
         "super",
         "postinit",
         "True",
         "False",
         "None",
         "handle",
         "strlen",
         "struct",
         "out_buf",
         "out_bool",
         "out_handle",
         "out_int",
         "out_err",
         "out_h",
         "out_e",
         "out_b",
         "st",
         "err_h",
         "emsg",
         "mbuf",
         "mben",
         "mst",
         "mb",
         "rb",
         "rs",
         "iv",
         "base",
         "off",
         "count",
         "ci",
         "klen",
         "key",
         "val",
         "result",
         "raw"
     };


def _mangle(name: str) -> str {
    new = name;
    while new in _JAC_RESERVED {
        new = new + "_";
    }
    return new;
}


class Skip {
    def init(self: Skip, item: str, reason: str) {
        self.item = item;
        self.reason = reason;
    }
}


class NaModule {
    def init(
        self: NaModule, source: str, skips: list[Skip] | None = None, bridged: int = 0
    ) {
        self.source = source;
        self.skips = skips if skips is not None else [];

        self.bridged = bridged;
    }
}


def _drop_sym_for(meta: BridgeMeta, kind: int) -> str | None {
    for td in meta.types {
        if td.kind == kind and td.drop_sym {
            return td.drop_sym;
        }
    }
    return None;
}


def _retain_sym_for(drop_sym: str) -> str {
    return drop_sym[:-len("_drop")] + "_retain";
}


class _Synth {
    def init(self: _Synth, meta: BridgeMeta, so_basename: str) {
        self.meta = meta;
        self.so = so_basename;
        self.skips = [];

        self._renamed = {};
        self.opaque = {};
        _taken_types = set();
        for td in meta.types {
            if td.kind == KIND_OPAQUE {
                nm = _mangle(td.name);

                while nm in _taken_types {
                    nm = nm + "_";
                }
                _taken_types.add(nm);
                if nm != td.name {
                    self._renamed[td.name] = nm;
                }
                self.opaque[td.index] = nm;
            }
        }
        ctor_targets = {
            tag_ref_index(fd.ret)
            for fd in meta.fns
            if fd.kind == FN_CTOR
            and tag_is_ref(fd.ret)
            and tag_ref_index(fd.ret) in self.opaque
        };
        self.adoptable = {
            tag_ref_index(fd.ret)
            for fd in meta.fns
            if fd.kind == FN_METHOD
            and tag_is_ref(fd.ret)
            and tag_ref_index(fd.ret) in self.opaque
            and tag_ref_index(fd.ret) not in ctor_targets
        };

        self.adopt_via_static = {
            tag_ref_index(fd.ret)
            for fd in meta.fns
            if fd.kind == FN_METHOD
            and tag_is_ref(fd.ret)
            and tag_ref_index(fd.ret) in self.opaque
            and tag_ref_index(fd.ret) in ctor_targets
        };

        self.borrowed_owner = {};
        _borrowed_multi = set();
        for fd in meta.fns {
            if fd.kind == FN_METHOD
            and tag_is_ref(fd.ret)
            and tag_is_borrowed(fd.ret)
            and tag_ref_index(fd.ret) in self.opaque
            and fd.self_type != TAG_VOID
            and fd.self_type in self.opaque {
                vti = tag_ref_index(fd.ret);
                if vti in self.borrowed_owner
                and self.borrowed_owner[vti] != fd.self_type {
                    _borrowed_multi.add(vti);
                } else {
                    self.borrowed_owner[vti] = fd.self_type;
                }
            }
        }
        for vti in _borrowed_multi {
            del self.borrowed_owner[vti];
        }

        self._retain_targets = set();
        for fd in meta.fns {
            if fd.kind == FN_METHOD
            and tag_is_ref(fd.ret)
            and tag_ref_index(fd.ret) in self.opaque {
                rti = tag_ref_index(fd.ret);
                if tag_is_shared(fd.ret) {
                    self._retain_targets.add(rti);
                } elif fd.self_type != TAG_VOID and rti == fd.self_type {
                    self._retain_targets.add(rti);
                }
            }
        }
        self.error_drop = _drop_sym_for(meta, KIND_ERROR);
        self.error_msg_sym = None;
        for fd in meta.fns {
            if fd.name == "message"
            and fd.ret == TAG_STR
            and fd.self_type != TAG_VOID
            and fd.self_type < len(meta.types)
            and meta.types[fd.self_type].kind == KIND_ERROR {
                self.error_msg_sym = fd.sym;
                break;
            }
        }
        self.free_buf = f"jac_{meta.module_name}_free_buf";
        self.make_buf_sym = f"jac_{meta.module_name}_make_buf";

        self.panic_msg_sym = f"jac_{meta.module_name}_panic_message";
        self.panic_drop_sym = f"jac_{meta.module_name}_panic_drop";
        self._needs_panic_syms = False;
        self._bridged_str_method = False;
        self._bridged_callback = False;
        self._needs_codec = False;

        self._typed_recs = [];
        self._rec_names = {};
        _seen_rec = set();
        for fd in meta.fns {
            _slots = [classify(fd.ret)];
            for p in fd.params {
                _slots.append(classify(p.tag));
            }
            for s in _slots {
                rec = self._typed_record(s);
                if rec is not None and rec.index not in _seen_rec {
                    _seen_rec.add(rec.index);
                    nm = _mangle(rec.name);
                    while nm in _taken_types or nm in self._rec_names.values() {
                        nm = nm + "_";
                    }
                    self._rec_names[rec.index] = nm;
                    self._typed_recs.append(rec);
                }
            }
        }
        if self._typed_recs {
            self._needs_codec = True;
        }
    }

    def _na_scalar_field(self: _Synth, tag: int) -> bool {
        base = tag_base(tag);
        return base == TAG_INT
        or base == TAG_UINT
        or base == TAG_BOOL
        or base == TAG_STR;
    }

    def _typed_record(self: _Synth, slot: Slot) -> RecordDesc | None {
        if slot.kind != SlotKind.Wide or slot.record <= 0 or slot.is_opt {
            return None;
        }
        idx = slot.record - 1;
        if idx >= len(self.meta.records) {
            return None;
        }
        rec = self.meta.records[idx];
        for f in rec.fields {
            if not self._na_scalar_field(f.tag) {
                return None;
            }
        }
        return rec;
    }

    def _wide_typed_name(self: _Synth, tag: int) -> str | None {
        rec = self._typed_record(classify(tag));
        if rec is None {
            return None;
        }
        return self._rec_names.get(rec.index);
    }

    def _shim_decl(self: _Synth, fd: FnDesc) -> str | None {
        params = [];
        if fd.kind == FN_METHOD and fd.self_type != TAG_VOID {
            params.append("handle: int");
        }
        for p in fd.params {
            pn = self._pname(p);
            ps = classify(p.tag).kind;
            if ps == SlotKind.Str {
                params.append(f"{pn}: str");
                params.append(f"{pn}_len: int");
            } elif ps == SlotKind.Wide {
                params.append(f"{pn}: bytes");
                params.append(f"{pn}_len: int");
            } elif ps == SlotKind.Bool
            or ps == SlotKind.Int
            or ps == SlotKind.Uint
            or ps == SlotKind.F64
            or ps == SlotKind.OpaqueRef
            or ps == SlotKind.Callback {
                params.append(f"{pn}: int");
            } else {
                return None;
            }
        }
        rs = classify(fd.ret);
        if rs.kind == SlotKind.Map or rs.kind == SlotKind.List {
            params.append("out_buf: bytes");
        } elif rs.kind == SlotKind.Wide {
            params.append("out_buf: bytes");
        } elif rs.kind == SlotKind.Bool {
            params.append("out_bool: bytes");
        } elif rs.kind == SlotKind.OpaqueRef {
            params.append("out_handle: bytes");
        } elif rs.kind == SlotKind.Str {
            params.append("out_buf: bytes");
        } elif rs.kind == SlotKind.Int or rs.kind == SlotKind.Uint {
            params.append("out_int: bytes");
        } elif rs.kind == SlotKind.F64 {
            params.append("out_f64: bytes");
        } elif rs.kind != SlotKind.Void {
            return None;
        }
        params.append("out_err: bytes");
        args = ",\n        ".join(params);
        return f"    def {fd.sym}(\n        {args}\n    ) -> i32;";
    }

    def _read_msg_block(
        self: _Synth, msg_sym: str, drop_sym: str, fname: str, ind: str
    ) -> list[str] {
        lines = [];
        lines.append(f'{ind}emsg = "{fname} failed with status " + str(st);');
        lines.append(f'{ind}mbuf = struct.pack("<QII", 0, 0, 0);');
        lines.append(f'{ind}mben = struct.pack("<Q", 0);');
        lines.append(f"{ind}mst = {msg_sym}(err_h, mbuf, mben);");
        lines.append(f"{ind}if mst == {STATUS_OK} {{");
        lines.append(f'{ind}    mb = struct.unpack("<QII", mbuf);');
        lines.append(f"{ind}    if mb[0] != 0 {{");
        lines.append(f"{ind}        emsg = __jac_str_from_raw(mb[0], mb[1]);");
        lines.append(f"{ind}        {self.free_buf}(mb[0], mb[1] | (mb[2] << 32));");
        lines.append(f"{ind}    }}");
        lines.append(f"{ind}}}");
        lines.append(f"{ind}{drop_sym}(err_h);");
        return lines;
    }

    def _drain_and_raise(self: _Synth, fname: str) -> list[str] {
        self._needs_panic_syms = True;
        have_err = self.error_msg_sym is not None and self.error_drop is not None;
        err_msg = self.error_msg_sym if have_err else self.panic_msg_sym;
        err_drop = self.error_drop if have_err else self.panic_drop_sym;
        lines = [];
        lines.append(f"            if st == {STATUS_ERR} {{");
        lines.extend(
            self._read_msg_block(err_msg, err_drop, fname, "                ")
        );
        lines.append("                raise ValueError(emsg);");
        lines.append("            } else {");
        lines.extend(
            self._read_msg_block(
                self.panic_msg_sym, self.panic_drop_sym, fname, "                "
            )
        );
        lines.append("                raise RuntimeError(emsg);");
        lines.append("            }");
        return lines;
    }

    def _na_read_value(self: _Synth, vtag: int, ind: str) -> list[str] {
        lines = [];
        vk = classify_scalar(vtag).kind;
        if vk == SlotKind.Str {
            lines.append(
                f'{ind}_vlen = struct.unpack("<I", __jac_bytes_from_raw(base + off, 4))[0];'
            );
            lines.append(f"{ind}off += 4;");
            lines.append(f"{ind}val = __jac_str_from_raw(base + off, _vlen);");
            lines.append(f"{ind}off += _vlen;");
        } elif vk == SlotKind.Bool {
            lines.append(
                f'{ind}val = struct.unpack("<B", __jac_bytes_from_raw(base + off, 1))[0] != 0;'
            );
            lines.append(f"{ind}off += 1;");
        } elif vk == SlotKind.Int {
            lines.append(
                f'{ind}val = struct.unpack("<q", __jac_bytes_from_raw(base + off, 8))[0];'
            );
            lines.append(f"{ind}off += 8;");
        } else {
            lines.append(
                f'{ind}val = struct.unpack("<Q", __jac_bytes_from_raw(base + off, 8))[0];'
            );
            lines.append(f"{ind}off += 8;");
        }
        return lines;
    }

    def _na_decode_container(self: _Synth, fd: FnDesc) -> list[str] {
        self._bridged_str_method = True;
        is_map = tag_is_map(fd.ret);
        vtag = tag_map_value(fd.ret) if is_map else tag_list_value(fd.ret);
        vt = self._na_val_type(vtag);
        lines = [];
        lines.append('        rb = struct.unpack("<QII", out_buf);');
        if is_map {
            lines.append(f"        result: dict[str, {vt}] = " + "{};");
        } else {
            lines.append(f"        result: list[{vt}] = [];");
        }
        lines.append("        if rb[0] != 0 {");
        lines.append("            base = rb[0];");
        lines.append(
            '            count = struct.unpack("<I", __jac_bytes_from_raw(base, 4))[0];'
        );
        lines.append("            off = 4;");
        lines.append("            ci = 0;");
        lines.append("            while ci < count {");
        if is_map {
            lines.append(
                '                klen = struct.unpack("<I", __jac_bytes_from_raw(base + off, 4))[0];'
            );
            lines.append("                off += 4;");
            lines.append("                key = __jac_str_from_raw(base + off, klen);");
            lines.append("                off += klen;");
        }
        lines.extend(self._na_read_value(vtag, "                "));
        if is_map {
            lines.append("                result[key] = val;");
        } else {
            lines.append("                result.append(val);");
        }
        lines.append("                ci += 1;");
        lines.append("            }");
        lines.append(f"            {self.free_buf}(rb[0], rb[1] | (rb[2] << 32));");
        lines.append("        }");
        lines.append("        return result;");
        return lines;
    }

    def _method_body(self: _Synth, fd: FnDesc) -> list[str] | None {
        body_lines = [];
        call = ["self.__handle"];
        if self._call_args(fd, call) is None {
            return None;
        }
        body_lines.append("        if self.__closed {");
        body_lines.append(
            f'            raise RuntimeError("{fd.name} called after close()");'
        );
        body_lines.append("        }");
        body_lines.extend(self._wide_prelude(fd));
        rs = classify(fd.ret);
        if rs.kind == SlotKind.Map or rs.kind == SlotKind.List {
            body_lines.append('        out_buf = struct.pack("<QII", 0, 0, 0);');
            call.append("out_buf");
        } elif rs.kind == SlotKind.Wide {
            body_lines.append('        out_buf = struct.pack("<QII", 0, 0, 0);');
            call.append("out_buf");
            self._needs_codec = True;
            self._bridged_str_method = True;
        } elif rs.kind == SlotKind.OpaqueRef {
            if rs.ref_index not in self.opaque {
                return None;
            }
            body_lines.append('        out_h = struct.pack("<Q", 0);');
            call.append("out_h");
        } elif rs.kind == SlotKind.Bool and not rs.is_opt {
            body_lines.append('        out_b = struct.pack("<B", 0);');
            call.append("out_b");
        } elif rs.kind == SlotKind.Str {
            body_lines.append('        out_buf = struct.pack("<QII", 0, 0, 0);');
            call.append("out_buf");
            self._bridged_str_method = True;
        } elif (rs.kind == SlotKind.Int or rs.kind == SlotKind.Uint)
        and not rs.is_opt {
            body_lines.append('        out_int = struct.pack("<Q", 0);');
            call.append("out_int");
        } elif rs.kind == SlotKind.F64 and not rs.is_opt {
            body_lines.append('        out_f64 = struct.pack("<Q", 0);');
            call.append("out_f64");
        } elif rs.is_opt {
            return None;
        } elif rs.kind != SlotKind.Void {
            return None;
        }
        body_lines.append('        out_e = struct.pack("<Q", 0);');
        call.append("out_e");
        args = ", ".join(call);
        body_lines.append(f"        st = {fd.sym}({args});");
        body_lines.append(f"        if st != {STATUS_OK} {{");
        body_lines.append('            err_h = struct.unpack("<Q", out_e)[0];');
        body_lines.extend(self._drain_and_raise(fd.name));
        body_lines.append("        }");
        if rs.kind == SlotKind.Map or rs.kind == SlotKind.List {
            body_lines.extend(self._na_decode_container(fd));
        } elif rs.kind == SlotKind.Wide {
            _rrec = self._typed_record(rs);
            body_lines.append('        rb = struct.unpack("<QII", out_buf);');
            body_lines.append("        if rb[0] == 0 {");
            if _rrec is not None {
                body_lines.append(
                    f"            return {self._rec_names[_rrec.index]}();"
                );
            } else {
                body_lines.append("            return jv_nil();");
            }
            body_lines.append("        }");
            body_lines.append("        _wv = msgpack_decode(rb[0], rb[1]);");
            body_lines.append(
                f"        {self.free_buf}(rb[0], rb[1] | (rb[2] << 32));"
            );
            if _rrec is not None {
                body_lines.append(
                    f"        return _jv_to_{self._rec_names[_rrec.index]}(_wv);"
                );
            } else {
                body_lines.append("        return _wv;");
            }
        } elif rs.kind == SlotKind.OpaqueRef {
            target = self.opaque[rs.ref_index];
            body_lines.append('        rh = struct.unpack("<Q", out_h)[0];');
            if rs.is_opt {
                body_lines.append("        if rh == 0 {");
                body_lines.append("            return None;");
                body_lines.append("        }");
            }
            if rs.is_borrowed and rs.ref_index in self.borrowed_owner {
                body_lines.append(f"        return {target}(rh, self.__handle);");
            } else {
                tdrop = self.meta.types[rs.ref_index].drop_sym;
                if tdrop and rs.ref_index in self._retain_targets {
                    tretain = _retain_sym_for(tdrop);
                    if rs.is_shared {
                        body_lines.append(f"        {tretain}(rh);");
                    } elif rs.ref_index == fd.self_type {
                        body_lines.append("        if rh == self.__handle {");
                        body_lines.append(f"            {tretain}(rh);");
                        body_lines.append("        }");
                    }
                }
                if rs.ref_index in self.adopt_via_static {
                    body_lines.append(f"        return {target}._adopt(rh);");
                } else {
                    body_lines.append(f"        return {target}(rh);");
                }
            }
        } elif rs.kind == SlotKind.Bool {
            body_lines.append('        return struct.unpack("<B", out_b)[0] != 0;');
        } elif rs.kind == SlotKind.Str {
            body_lines.append('        rb = struct.unpack("<QII", out_buf);');
            body_lines.append("        if rb[0] == 0 {");
            if rs.is_opt {
                body_lines.append("            return None;");
            } else {
                body_lines.append('            return "";');
            }
            body_lines.append("        }");
            body_lines.append("        rs = __jac_str_from_raw(rb[0], rb[1]);");
            body_lines.append(
                f"        {self.free_buf}(rb[0], rb[1] | (rb[2] << 32));"
            );
            body_lines.append("        return rs;");
        } elif rs.kind == SlotKind.Int {
            body_lines.append('        iv = struct.unpack("<Q", out_int)[0];');
            body_lines.append("        if iv >= 0x8000000000000000 {");
            body_lines.append("            return iv - 0x10000000000000000;");
            body_lines.append("        }");
            body_lines.append("        return iv;");
        } elif rs.kind == SlotKind.Uint {
            body_lines.append('        return struct.unpack("<Q", out_int)[0];');
        } elif rs.kind == SlotKind.F64 {
            body_lines.append('        fb = struct.unpack("<Q", out_f64)[0];');
            body_lines.append(
                '        return struct.unpack("<d", struct.pack("<Q", fb))[0];'
            );
        }
        return body_lines;
    }

    def _codec_source(self: _Synth) -> list[str] {
        import os;
        codec_path = os.path.join(os.path.dirname(__file__), "_msgpack.jac");
        with open(codec_path, "r") as f {
            raw = f.read();
        }
        lines = [];
        for ln in raw.split("\n") {
            if ln.strip() == "import struct;" {
                continue;
            }
            lines.append(ln);
        }
        return lines;
    }

    def _record_source(self: _Synth, rec: RecordDesc) -> list[str] {
        name = self._rec_names[rec.index];
        lines = [];
        lines.append(f"obj {name} {{");
        for f in rec.fields {
            fn = self._field_name(f.name);
            base = tag_base(f.tag);
            if base == TAG_STR {
                lines.append(f"    has {fn}: str = \"\";");
            } elif base == TAG_BOOL {
                lines.append(f"    has {fn}: bool = False;");
            } else {
                lines.append(f"    has {fn}: int = 0;");
            }
        }
        lines.append("}");
        lines.append("");

        lines.append(f"def _{name}_to_jv(_r: {name}) -> JacValue {{");
        lines.append(f"    r: {name} = _r;");
        lines.append("    m: dict[str, JacValue] = {};");
        for f in rec.fields {
            fn = self._field_name(f.name);
            base = tag_base(f.tag);
            if base == TAG_STR {
                lines.append(f"    m[{f.name!r}] = jv_str(r.{fn});");
            } elif base == TAG_BOOL {
                lines.append(f"    m[{f.name!r}] = jv_bool(r.{fn});");
            } elif base == TAG_UINT {
                lines.append(f"    m[{f.name!r}] = jv_uint(r.{fn});");
            } else {
                lines.append(f"    m[{f.name!r}] = jv_int(r.{fn});");
            }
        }
        lines.append("    return jv_map(m);");
        lines.append("}");
        lines.append("");

        lines.append(f"def _jv_to_{name}(_v: JacValue) -> {name} {{");
        lines.append(f"    v: JacValue = _v;");
        lines.append(f"    r = {name}();");
        lines.append("    e = v.entries;");
        _i = 0;
        for f in rec.fields {
            fn = self._field_name(f.name);
            base = tag_base(f.tag);
            lines.append(f"    _f{_i} = e[{f.name!r}];");
            if base == TAG_STR {
                lines.append(f"    r.{fn} = _f{_i}.s;");
            } elif base == TAG_BOOL {
                lines.append(f"    r.{fn} = _f{_i}.b;");
            } else {
                lines.append(f"    r.{fn} = _f{_i}.i;");
            }
            _i += 1;
        }
        lines.append("    return r;");
        lines.append("}");
        return lines;
    }

    def _field_name(self: _Synth, raw: str) -> str {
        m = _mangle(raw);
        return m;
    }

    def _wide_prelude(self: _Synth, fd: FnDesc) -> list[str] {
        lines = [];
        for p in fd.params {
            slot = classify(p.tag);
            if slot.kind == SlotKind.Wide {
                pn = self._pname(p);
                rec = self._typed_record(slot);
                if rec is not None {
                    conv = f"_{self._rec_names[rec.index]}_to_jv";
                    lines.append(f"        _enc_{pn} = msgpack_encode({conv}({pn}));");
                } else {
                    lines.append(f"        _enc_{pn} = msgpack_encode({pn});");
                }
            }
        }
        return lines;
    }

    def _call_args(self: _Synth, fd: FnDesc, call: list[str]) -> list[str] | None {
        for p in fd.params {
            pn = self._pname(p);
            pk = classify(p.tag).kind;
            if pk == SlotKind.Str {
                call.append(pn);
                call.append(f"strlen({pn})");
            } elif pk == SlotKind.Wide {
                self._needs_codec = True;
                call.append(f"_enc_{pn}");
                call.append(f"len(_enc_{pn})");
            } elif pk == SlotKind.Bool {
                call.append(f"({pn} and 1 or 0)");
            } elif pk == SlotKind.Int or pk == SlotKind.Uint {
                call.append(pn);
            } elif pk == SlotKind.F64 {
                return None;
            } elif pk == SlotKind.OpaqueRef {
                call.append(f"{pn}.__handle");
            } elif pk == SlotKind.Callback {
                call.append(pn);
                self._bridged_callback = True;
            } else {
                return None;
            }
        }
        return call;
    }

    def _ctor_body(self: _Synth, fd: FnDesc) -> list[str] | None {
        body_lines = [];
        call = [];
        if self._call_args(fd, call) is None {
            return None;
        }
        body_lines.extend(self._wide_prelude(fd));
        body_lines.append('        out_h = struct.pack("<Q", 0);');
        body_lines.append('        out_e = struct.pack("<Q", 0);');
        call.append("out_h");
        call.append("out_e");
        args = ", ".join(call);
        body_lines.append(f"        st = {fd.sym}({args});");
        body_lines.append(f"        if st == {STATUS_OK} {{");
        body_lines.append('            self.__handle = struct.unpack("<Q", out_h)[0];');
        body_lines.append("            self.__closed = False;");
        body_lines.append("        } else {");
        body_lines.append('            err_h = struct.unpack("<Q", out_e)[0];');
        body_lines.extend(self._drain_and_raise(fd.name));
        body_lines.append("        }");
        return body_lines;
    }

    def _visit(
        self: _Synth,
        ti: int,
        produces: dict[int, set[int]],
        visited: set[int],
        emit_order: list[int]
    ) {
        if ti in visited {
            return;
        }
        visited.add(ti);
        for p in sorted(produces[ti]) {
            self._visit(p, produces, visited, emit_order);
        }
        emit_order.append(ti);
    }

    def render(self: _Synth) -> NaModule {
        m = self.meta;
        ctor_of = {};
        methods_of = {ti: [] for ti in self.opaque};
        shim_fds = [];

        for fd in m.fns {
            if fd.kind == FN_CTOR
            and tag_is_ref(fd.ret)
            and tag_ref_index(fd.ret) in self.opaque {
                ti = tag_ref_index(fd.ret);
                if self._shim_decl(fd) is None or self._ctor_body(fd) is None {
                    self.skips.append(
                        Skip(
                            item=fd.name,
                            reason="constructor has unbridgeable param/return"
                        )
                    );
                    continue;
                }
                ctor_of[ti] = fd;
                shim_fds.append(fd);
            } elif fd.kind == FN_METHOD and fd.self_type in self.opaque {
                if self._shim_decl(fd) is None or self._method_body(fd) is None {
                    if tag_is_ref(fd.ret)
                    and tag_ref_index(fd.ret) not in self.opaque {
                        reason = "returns an opaque handle to a type not emitted by this bridge";
                    } else {
                        reason = "unbridgeable param/return";
                    }
                    self.skips.append(
                        Skip(
                            item=f"{self.opaque[fd.self_type]}.{fd.name}", reason=reason
                        )
                    );
                    continue;
                }
                methods_of[fd.self_type].append(fd);
                shim_fds.append(fd);
            } elif fd.kind == FN_STATIC {
                owner = self.opaque[fd.self_type]
                    if fd.self_type in self.opaque
                    else "?";
                self.skips.append(
                    Skip(
                        item=f"{owner}.{fd.name}",
                        reason="static associated fn not bridged on na (FN_STATIC; CPython-only)"
                    )
                );
            } elif fd.self_type != TAG_VOID
            and fd.self_type < len(m.types)
            and m.types[fd.self_type].kind == KIND_ERROR {
                if fd.sym != self.error_msg_sym {
                    self.skips.append(
                        Skip(
                            item=f"{m.types[fd.self_type].name}.{fd.name}",
                            reason="error-type method not bridged on na"
                        )
                    );
                }
            }
        }

        out = [];
        out.append(
            f"# AUTO-SYNTHESIZED from {self.so} (.jac_bridge metadata). Do not edit."
        );
        out.append(f"# module: {m.module_name}   abi: {m.abi_version}");
        out.append("import struct;");
        out.append(f'import from "{_libc_soname()}" {{');
        out.append("    def strlen(s: str) -> int;");
        out.append("}");
        out.append("");
        out.append(f'import from "{self.so}" {{');
        for fd in shim_fds {
            out.append(self._shim_decl(fd));
        }
        for ti in self.opaque {
            td = m.types[ti];
            if td.drop_sym {
                out.append(f"    def {td.drop_sym}(handle: int) -> None;");
            }
        }

        _retain_syms = set();
        for owner_ti in self.borrowed_owner.values() {
            _retain_syms.add(owner_ti);
        }
        for rti in self._retain_targets {
            _retain_syms.add(rti);
        }
        for rti in sorted(_retain_syms) {
            odrop = m.types[rti].drop_sym;
            if odrop {
                out.append(f"    def {_retain_sym_for(odrop)}(handle: int) -> None;");
            }
        }
        if self.error_drop {
            out.append(f"    def {self.error_drop}(err_handle: int) -> None;");
        }
        if self.error_msg_sym {
            out.append(
                f"    def {self.error_msg_sym}" + "(err_handle: int, out_buf: bytes, out_err: bytes) -> i32;"
            );
        }
        if self._needs_panic_syms {
            out.append(
                f"    def {self.panic_msg_sym}" + "(err_handle: int, out_buf: bytes, out_err: bytes) -> i32;"
            );
            out.append(f"    def {self.panic_drop_sym}(err_handle: int) -> None;");
        }
        if self.error_msg_sym or self._bridged_str_method or self._needs_panic_syms {
            out.append(
                f"    def {self.free_buf}(buf_ptr: int, buf_lencap: int) -> None;"
            );
        }
        if self._bridged_callback {
            out.append(
                f"    def {self.make_buf_sym}(s: str, s_len: int, out_buf: int) -> None;"
            );
        }
        out.append("}");
        out.append("");

        if self._needs_codec {
            out.extend(self._codec_source());
            out.append("");
        }

        for rec in self._typed_recs {
            out.extend(self._record_source(rec));
            out.append("");
        }

        produces = {ti: set() for ti in self.opaque};
        for ti in self.opaque {
            for fd in methods_of.get(ti, []) {
                if tag_is_ref(fd.ret) {
                    p = tag_ref_index(fd.ret);
                    if p in self.opaque and p != ti {
                        produces[ti].add(p);
                    }
                }
            }
        }
        emit_order = [];
        visited = set();
        seed = sorted(
            [
                t
                for t in self.opaque
                if t in self.adoptable
            ]
        ) + sorted(
            [
                t
                for t in self.opaque
                if t not in self.adoptable
            ]
        );
        for ti in seed {
            self._visit(ti, produces, visited, emit_order);
        }

        for ti in emit_order {
            name = self.opaque[ti];
            drop_sym = m.types[ti].drop_sym;
            is_borrowed_view = ti in self.borrowed_owner;
            out.append(f"obj {name} {{");
            out.append("    has __handle: int = 0;");
            out.append("    has __closed: bool = True;");
            if is_borrowed_view {
                out.append("    has __owner_handle: int = 0;");
            }
            out.append("");
            ctor = ctor_of.get(ti);
            if is_borrowed_view {
                owner_drop = m.types[self.borrowed_owner[ti]].drop_sym;
                owner_retain = _retain_sym_for(owner_drop);
                out.append("    def init(raw: int, owner: int) {");
                out.append(f"        {owner_retain}(owner);");
                out.append("        self.__handle = raw;");
                out.append("        self.__owner_handle = owner;");
                out.append("        self.__closed = False;");
                out.append("    }");
                out.append("");
            } elif ctor is not None {
                sig = self._ctor_params(ctor);
                out.append(f"    def init({sig}) {{");
                out.extend(self._ctor_body(ctor));
                out.append("    }");
                out.append("");
            } elif ti in self.adoptable {
                out.append("    def init(raw: int) {");
                out.append("        self.__handle = raw;");
                out.append("        self.__closed = False;");
                out.append("    }");
                out.append("");
            }
            if ti in self.adopt_via_static and not is_borrowed_view {
                out.append(f"    static def _adopt(raw: int) -> {name} {{");
                out.append(f"        adopted = {name}.__new__({name});");
                out.append("        adopted.__handle = raw;");
                out.append("        adopted.__closed = False;");
                out.append("        return adopted;");
                out.append("    }");
                out.append("");
            }
            for fd in methods_of.get(ti, []) {
                sig = self._method_params(fd);
                ret = self._ret_ann(fd);
                out.append(f"    def {self._mname(fd)}({sig}){ret} {{");
                out.extend(self._method_body(fd));
                out.append("    }");
                out.append("");
            }
            out.append("    def close() {");
            out.append("        if not self.__closed {");
            if drop_sym {
                out.append(f"            {drop_sym}(self.__handle);");
            }
            if is_borrowed_view {
                owner_drop = m.types[self.borrowed_owner[ti]].drop_sym;
                if owner_drop {
                    out.append(f"            {owner_drop}(self.__owner_handle);");
                }
                out.append("            self.__owner_handle = 0;");
            }
            out.append("            self.__handle = 0;");
            out.append("            self.__closed = True;");
            out.append("        }");
            out.append("    }");
            out.append("");
            out.append("    def __del__() {");
            out.append("        self.close();");
            out.append("    }");
            out.append("}");
            out.append("");
        }

        if self._renamed {
            hdr = ["# renamed (Jac-reserved word collision):"];
            for orig in sorted(self._renamed) {
                hdr.append(f"#   {orig} -> {self._renamed[orig]}");
            }
            out[2:2] = hdr;
        }

        bridged = len(ctor_of) + sum([len(v) for v in methods_of.values()]);
        return NaModule(source="\n".join(out), skips=self.skips, bridged=bridged);
    }

    def _pname(self: _Synth, p: ParamDesc) -> str {
        new = _mangle(p.name);
        if new != p.name {
            self._renamed[p.name] = new;
        }
        return new;
    }

    def _mname(self: _Synth, fd: FnDesc) -> str {
        new = _mangle(fd.name);
        if new != fd.name {
            self._renamed[fd.name] = new;
        }
        return new;
    }

    def _jac_param(self: _Synth, p: ParamDesc) -> str {
        pn = self._pname(p);
        if p.tag == TAG_STR {
            return f"{pn}: str";
        }
        if p.tag == TAG_BOOL {
            return f"{pn}: bool";
        }
        if tag_base(p.tag) == TAG_F64 {
            return f"{pn}: float";
        }
        if tag_is_wide(p.tag) {
            tn = self._wide_typed_name(p.tag);
            return f"{pn}: {tn}" if tn is not None else f"{pn}: JacValue";
        }
        if tag_is_ref(p.tag) {
            return f"{pn}: {self.opaque.get(tag_ref_index(p.tag), 'object')}";
        }
        return f"{pn}: int";
    }

    def _ctor_params(self: _Synth, fd: FnDesc) -> str {
        return ", ".join([self._jac_param(p) for p in fd.params]);
    }

    def _method_params(self: _Synth, fd: FnDesc) -> str {
        return ", ".join([self._jac_param(p) for p in fd.params]);
    }

    def _na_val_type(self: _Synth, vtag: int) -> str {
        vk = classify_scalar(vtag).kind;
        if vk == SlotKind.Str {
            return "str";
        }
        if vk == SlotKind.Bool {
            return "bool";
        }
        return "int";
    }

    def _ret_ann(self: _Synth, fd: FnDesc) -> str {
        if fd.ret == TAG_VOID {
            return "";
        }
        if tag_is_map(fd.ret) {
            return f" -> dict[str, {self._na_val_type(tag_map_value(fd.ret))}]";
        }
        if tag_is_list(fd.ret) {
            return f" -> list[{self._na_val_type(tag_list_value(fd.ret))}]";
        }
        if tag_base(fd.ret) == TAG_BOOL {
            return " -> bool";
        }
        if fd.ret == TAG_INT or fd.ret == TAG_UINT {
            return " -> int";
        }
        if fd.ret == TAG_F64 {
            return " -> float";
        }
        if tag_base(fd.ret) == TAG_STR {
            return " -> str | None" if tag_is_opt(fd.ret) else " -> str";
        }
        if tag_is_wide(fd.ret) {
            tn = self._wide_typed_name(fd.ret);
            return f" -> {tn}" if tn is not None else " -> JacValue";
        }
        if tag_is_ref(fd.ret) {
            t = self.opaque.get(tag_ref_index(fd.ret), "object");
            return f" -> {t} | None" if tag_is_opt(fd.ret) else f" -> {t}";
        }
        return "";
    }
}


def render_na_source(meta: BridgeMeta, so_basename: str) -> NaModule {
    return _Synth(meta, so_basename).render();
}
