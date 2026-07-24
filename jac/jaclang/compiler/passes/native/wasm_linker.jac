glob _PLACEHOLDER: set = {
         "__linear_memory",
         "__indirect_function_table",
         "__stack_pointer",
         "__memory_base",
         "__table_base"
     };

def _rd_uleb(b: bytes, o: int) -> tuple[int, int] {
    r = 0;
    s = 0;
    while True {
        x = b[o];
        o += 1;
        r |= (x & 0x7f) << s;
        s += 7;
        if not (x & 0x80) {
            return (r, o);
        }
    }
}

def _rd_sleb(b: bytes, o: int) -> tuple[int, int] {
    r = 0;
    s = 0;
    while True {
        x = b[o];
        o += 1;
        r |= (x & 0x7f) << s;
        s += 7;
        if not (x & 0x80) {
            if x & 0x40 {
                r |= -(1 << s);
            }
            return (r, o);
        }
    }
}

def _uleb(v: int) -> bytes {
    out = bytearray();
    while True {
        x = v & 0x7f;
        v >>= 7;
        if v {
            out.append(x | 0x80);
        } else {
            out.append(x);
            return bytes(out);
        }
    }
}

def _uleb5(v: int) -> bytes {
    out = bytearray();
    i = 0;
    while i < 5 {
        x = (v >> (7 * i)) & 0x7f;
        if i < 4 {
            out.append(x | 0x80);
        } else {
            out.append(x);
        }
        i += 1;
    }
    return bytes(out);
}

def _sleb_bytes(v: int) -> bytes {
    out = bytearray();
    while True {
        x = v & 0x7f;
        v >>= 7;
        if (v == 0 and not (x & 0x40)) or (v == -1 and (x & 0x40)) {
            out.append(x);
            return bytes(out);
        }
        out.append(x | 0x80);
    }
}

def _u32le(v: int) -> bytes {
    return (v & 0xffffffff).to_bytes(4, "little");
}

def _rd_name(b: bytes, o: int) -> tuple[str, int] {
    (n, o) = _rd_uleb(b, o);
    return (b[o:o + n].decode("latin1"), o + n);
}

def _nm_bytes(s: str) -> bytes {
    e = s.encode("utf-8");
    return _uleb(len(e)) + e;
}

def _section(sid: int, payload: bytes) -> bytes {
    return bytes([sid]) + _uleb(len(payload)) + payload;
}

def _vec(items: list) -> bytes {
    return _uleb(len(items)) + b"".join(items);
}

def _patch(buf: bytearray, off: int, data: bytes) {
    i = 0;
    while i < len(data) {
        buf[off + i] = data[i];
        i += 1;
    }
}

obj WasmObj {
    has b: bytes,
        types_raw: list[bytes] = [],
        imports: list[list[any]] = [],
        func_types: list[int] = [],
        code: bytes = b"",
        data_raw: bytes = b"",
        symtab: list[list[any]] = [],
        relocs: list[list[any]] = [],
        seg_info: list[tuple[str, int, int]] = [];

    def postinit {
        self.types_raw = [];
        self.imports = [];
        self.func_types = [];
        self.code = b"";
        self.data_raw = b"";
        self.symtab = [];
        self.relocs = [];
        self.seg_info = [];
        self.parse();
    }

    def parse -> None;
    def parse_linking(o: int, end: int) -> None;
    def parse_reloc(nm: str, o: int, end: int) -> None;
}

impl WasmObj.parse -> None {
    b = self.b;
    o = 8;
    while o < len(b) {
        sid = b[o];
        o += 1;
        (size, o) = _rd_uleb(b, o);
        end = o + size;
        if sid == 1 {
            (n, o) = _rd_uleb(b, o);
            ci = 0;
            while ci < n {
                st = o;
                o += 1;
                (np, o) = _rd_uleb(b, o);
                o += np;
                (nr, o) = _rd_uleb(b, o);
                o += nr;
                self.types_raw.append(b[st:o]);
                ci += 1;
            }
        } elif sid == 2 {
            (n, o) = _rd_uleb(b, o);
            ci = 0;
            while ci < n {
                (mod, o) = _rd_name(b, o);
                (fld, o) = _rd_name(b, o);
                k = b[o];
                o += 1;
                if k == 0 {
                    (ti, o) = _rd_uleb(b, o);
                    self.imports.append(["func", mod, fld, ti]);
                } elif k == 1 {
                    et = b[o];
                    o += 1;
                    fl = b[o];
                    o += 1;
                    (mn, o) = _rd_uleb(b, o);
                    if fl & 1 {
                        (mx, o) = _rd_uleb(b, o);
                    }
                    self.imports.append(["table", mod, fld, et]);
                } elif k == 2 {
                    fl = b[o];
                    o += 1;
                    (mn, o) = _rd_uleb(b, o);
                    if fl & 1 {
                        (mx, o) = _rd_uleb(b, o);
                    }
                    self.imports.append(["mem", mod, fld, mn]);
                } elif k == 3 {
                    vt = b[o];
                    o += 1;
                    is_mut = b[o];
                    o += 1;
                    self.imports.append(["global", mod, fld, (vt, is_mut)]);
                }
                ci += 1;
            }
        } elif sid == 3 {
            (n, o) = _rd_uleb(b, o);
            ci = 0;
            while ci < n {
                (t, o) = _rd_uleb(b, o);
                self.func_types.append(t);
                ci += 1;
            }
        } elif sid == 10 {
            self.code = b[o:end];
        } elif sid == 11 {
            self.data_raw = b[o:end];
        } elif sid == 0 {
            (nm, o2) = _rd_name(b, o);
            if nm == "linking" {
                self.parse_linking(o2, end);
            } elif nm.startswith("reloc.") {
                self.parse_reloc(nm, o2, end);
            }
        }
        o = end;
    }
}

impl WasmObj.parse_linking(o: int, end: int) -> None {
    b = self.b;
    (ver, o) = _rd_uleb(b, o);
    while o < end {
        sub = b[o];
        o += 1;
        (pl, o) = _rd_uleb(b, o);
        se = o + pl;
        if sub == 8 {
            (cnt, o) = _rd_uleb(b, o);
            ci = 0;
            while ci < cnt {
                kind = b[o];
                o += 1;
                (flags, o) = _rd_uleb(b, o);
                undef = flags & 0x10;
                if kind == 1 {
                    (nm, o) = _rd_name(b, o);
                    info = None;
                    if not undef {
                        (sg, o) = _rd_uleb(b, o);
                        (of, o) = _rd_uleb(b, o);
                        (sz, o) = _rd_uleb(b, o);
                        info = (sg, of, sz);
                    }
                    self.symtab.append([kind, flags, info, nm]);
                } elif kind == 3 {
                    (idx, o) = _rd_uleb(b, o);
                    self.symtab.append([kind, flags, idx, None]);
                } else {
                    (idx, o) = _rd_uleb(b, o);
                    nm = None;
                    if (not undef) or (flags & 0x40) {
                        (nm, o) = _rd_name(b, o);
                    }
                    self.symtab.append([kind, flags, idx, nm]);
                }
                ci += 1;
            }
        } elif sub == 5 {
            (cnt, o) = _rd_uleb(b, o);
            ci = 0;
            while ci < cnt {
                (nm, o) = _rd_name(b, o);
                (al, o) = _rd_uleb(b, o);
                (fl, o) = _rd_uleb(b, o);
                self.seg_info.append((nm, al, fl));
                ci += 1;
            }
        }
        o = se;
    }
}

impl WasmObj.parse_reloc(nm: str, o: int, end: int) -> None {
    if nm != "reloc.CODE" {
        return;
    }
    b = self.b;
    (sec, o) = _rd_uleb(b, o);
    (cnt, o) = _rd_uleb(b, o);
    ci = 0;
    while ci < cnt {
        rt = b[o];
        o += 1;
        (off, o) = _rd_uleb(b, o);
        (sym, o) = _rd_uleb(b, o);
        add = 0;
        if rt == 3 or rt == 4 or rt == 5 {
            (add, o) = _rd_sleb(b, o);
        }
        self.relocs.append([nm, rt, off, sym, add]);
        ci += 1;
    }
}

def _parse_data_segments(b: bytes) -> list {
    if not b {
        return [];
    }
    o = 0;
    (n, o) = _rd_uleb(b, o);
    segs = [];
    ci = 0;
    while ci < n {
        (flags, o) = _rd_uleb(b, o);
        if flags == 0 {
            o += 1;
            (_v, o) = _rd_sleb(b, o);
            o += 1;
            (sz, o) = _rd_uleb(b, o);
            segs.append(b[o:o + sz]);
            o += sz;
        } elif flags == 1 {
            (sz, o) = _rd_uleb(b, o);
            segs.append(b[o:o + sz]);
            o += sz;
        } else {
            raise ValueError(f"unsupported data segment flags {flags}");
        }
        ci += 1;
    }
    return segs;
}

def _sym_val(
    ob: WasmObj, si: int, old2new: dict, seg_base: list, heap_base: int = -1
) -> int {
    e = ob.symtab[si];
    k = e[0];
    idx = e[2];
    if k == 0 {
        return old2new[idx];
    }
    if k == 2 {
        return 0;
    }
    if k == 1 {
        if idx is None {
            if e[3] == "__heap_base" and heap_base >= 0 {
                return heap_base;
            }
            raise ValueError(f"undefined data symbol {e[3]}");
        }
        return seg_base[idx[0]] + idx[1];
    }
    raise ValueError(f"unsupported symbol kind {k}");
}

obj WasmLinker {
    static def link(
        obj_bytes: bytes,
        export_funcs: list = [],
        mem_pages: int = 256,
        host_abi: (set | None) = None,
        host_module: str = "jac_host1",
        app_imports: (set | None) = None,
    ) -> bytes;
}

impl WasmLinker.link(
    obj_bytes: bytes,
    export_funcs: list = [],
    mem_pages: int = 256,
    host_abi: (set | None) = None,
    host_module: str = "jac_host1",
    app_imports: (set | None) = None,
) -> bytes {
    ob = WasmObj(b=obj_bytes);
    segs = _parse_data_segments(ob.data_raw);

    base = 1024;
    seg_base = [];
    i = 0;
    while i < len(segs) {
        al = 0;
        if i < len(ob.seg_info) {
            al = ob.seg_info[i][1];
        }
        align = (1 << al) if al else 1;
        base = ((base + align - 1) // align) * align;
        seg_base.append(base);
        base += len(segs[i]);
        i += 1;
    }
    base = ((base + 15) // 16) * 16;
    stack_top = base + (1 << 18);
    heap_base = ((stack_top + 15) // 16) * 16;

    obj_func_imports = [
        im
        for im in ob.imports
        if im[0] == "func"
    ];
    kept = [];
    old2new = {};
    oi = 0;
    for im in obj_func_imports {
        if im[2] in _PLACEHOLDER { } else {
            fld = im[2];
            if host_abi is not None and fld in host_abi {
                im = [im[0], host_module, fld, im[3]];
            } elif app_imports is not None and fld not in app_imports {
                raise RuntimeError(
                    f"wasm import '{fld}' is neither part of the " + f"{host_module} host ABI nor declared by the app; " + "the native floor references a symbol missing from the " + "vendored wasm_rt libc (compiler drift) — add it to " + "wasm_rt or to wasm_host_abi.jac"
                );
            }
            old2new[oi] = len(kept);
            kept.append(im);
        }
        oi += 1;
    }
    n_obj_imp = len(obj_func_imports);
    n_imp = len(kept);
    di = 0;
    while di < len(ob.func_types) {
        old2new[n_obj_imp + di] = n_imp + di;
        di += 1;
    }

    slot_of = {};
    nslot = 1;
    needs_table = False;
    for r in ob.relocs {
        rt = r[1];
        if rt == 1 or rt == 2 or rt == 20 {
            needs_table = True;
        }
        if rt == 1 or rt == 2 {
            fi = _sym_val(ob, r[3], old2new, seg_base, heap_base);
            if fi in slot_of { } else {
                slot_of[fi] = nslot;
                nslot += 1;
            }
        }
    }

    code = bytearray(ob.code);
    for r in ob.relocs {
        rnm = r[0];
        rt = r[1];
        off = r[2];
        sym = r[3];
        add = r[4];
        if rnm != "reloc.CODE" {
            continue;
        }
        if rt == 0 {
            _patch(code, off, _uleb5(_sym_val(ob, sym, old2new, seg_base, heap_base)));
        } elif rt == 1 {
            _patch(
                code,
                off,
                _uleb5(slot_of[_sym_val(ob, sym, old2new, seg_base, heap_base)])
            );
        } elif rt == 2 {
            _patch(
                code,
                off,
                _u32le(slot_of[_sym_val(ob, sym, old2new, seg_base, heap_base)])
            );
        } elif rt == 3 or rt == 4 {
            _patch(
                code, off, _uleb5(_sym_val(ob, sym, old2new, seg_base, heap_base) + add)
            );
        } elif rt == 5 {
            _patch(
                code, off, _u32le(_sym_val(ob, sym, old2new, seg_base, heap_base) + add)
            );
        } elif rt == 6 { } elif rt == 7 {
            _patch(code, off, _uleb5(_sym_val(ob, sym, old2new, seg_base, heap_base)));
        } elif rt == 20 {
            _patch(code, off, _uleb5(0));
        } else {
            raise ValueError(f"unsupported reloc type {rt}");
        }
    }

    out = bytearray(b"\x00asm");
    out += _u32le(1);
    out += _section(1, _vec(ob.types_raw));
    imps = [];
    for im in kept {
        imps.append(_nm_bytes(im[1]) + _nm_bytes(im[2]) + b"\x00" + _uleb(im[3]));
    }
    out += _section(2, _vec(imps));
    out += _section(3, _vec([_uleb(t) for t in ob.func_types]));
    if needs_table {
        out += _section(4, _vec([b"\x70\x00" + _uleb(nslot)]));
    }
    out += _section(5, _vec([b"\x00" + _uleb(mem_pages)]));
    g_sp = b"\x7f\x01\x41" + _sleb_bytes(stack_top) + b"\x0b";
    g_hb = b"\x7f\x00\x41" + _sleb_bytes(heap_base) + b"\x0b";
    out += _section(6, _vec([g_sp, g_hb]));

    ef = export_funcs;
    if not ef {
        ef = [];
        for e in ob.symtab {
            if e[0] == 0 and e[3] and not (e[1] & 0x10) and not (e[1] & 0x2) {
                ef.append(e[3]);
            }
        }
    }
    exps = [_nm_bytes("memory") + b"\x02" + _uleb(0)];
    exps.append(_nm_bytes("__stack_pointer") + b"\x03" + _uleb(0));
    exps.append(_nm_bytes("__heap_base") + b"\x03" + _uleb(1));
    for nm in ef {
        fi = -1;
        for e in ob.symtab {
            if e[0] == 0 and e[3] == nm {
                fi = old2new[e[2]];
            }
        }
        if fi >= 0 {
            exps.append(_nm_bytes(nm) + b"\x00" + _uleb(fi));
        }
    }
    out += _section(7, _vec(exps));

    if nslot > 1 {
        pairs = [];
        for kv in slot_of.items() {
            pairs.append((kv[1], kv[0]));
        }
        pairs.sort();
        funcidxs = [p[1] for p in pairs];
        expr = b"\x41" + _sleb_bytes(1) + b"\x0b";
        elem = b"\x00" + expr + _vec([_uleb(fi) for fi in funcidxs]);
        out += _section(9, _vec([elem]));
    }
    out += _section(10, bytes(code));

    dsegs = [];
    i = 0;
    while i < len(segs) {
        expr = b"\x41" + _sleb_bytes(seg_base[i]) + b"\x0b";
        c = segs[i];
        dsegs.append(b"\x00" + expr + _uleb(len(c)) + c);
        i += 1;
    }
    if dsegs {
        out += _section(11, _vec(dsegs));
    }

    nm_entries = [];
    fi2 = 0;
    for im in kept {
        nm_entries.append((fi2, im[2]));
        fi2 += 1;
    }
    seen_fi = set();
    for e in ob.symtab {
        if e[0] == 0 and e[3] and not (e[1] & 0x10) and e[2] in old2new {
            nfi = old2new[e[2]];
            if nfi not in seen_fi {
                seen_fi.add(nfi);
                nm_entries.append((nfi, e[3]));
            }
        }
    }
    nm_entries.sort();
    nm_map = bytearray();
    for pair in nm_entries {
        nm_map += _uleb(pair[0]) + _nm_bytes(pair[1]);
    }
    sub = _uleb(len(nm_entries)) + bytes(nm_map);
    payload = _nm_bytes("name") + b"\x01" + _uleb(len(sub)) + sub;
    out += _section(0, payload);
    return bytes(out);
}
