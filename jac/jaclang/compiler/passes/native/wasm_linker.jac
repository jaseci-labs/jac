"""Pure-Jac WebAssembly linker for native Jac compilation.

Takes the relocatable wasm object bytes from llvmlite's emit_object() (target
triple wasm32-unknown-unknown) and produces a single instantiable wasm module.
No external linker (wasm-ld / lld) required.

Single-translation-unit model: the whole .na.jac module compiles to ONE LLVM
module -> ONE object, so there is no cross-object merge. The linker:
  - drops placeholder env imports (__linear_memory / __stack_pointer / ...),
  - assigns the final function index space (kept imports first, then defined),
  - lays out data segments + a stack in linear memory,
  - synthesizes the memory, __stack_pointer + __heap_base globals, and the
    indirect-function table + elem segment,
  - rewrites code relocations (FUNCTION_INDEX / MEMORY_ADDR / GLOBAL_INDEX /
    TABLE_INDEX / TABLE_NUMBER), and
  - exports memory, the magic globals, and every defined function.

Undefined externs (raylib, malloc/free/memcpy, __multi3, ...) remain wasm
imports from module "env", satisfied by the JS host at instantiation time.
"""

# Names llvmlite emits as env placeholders that the linker resolves itself.
glob _PLACEHOLDER: set = {
         "__linear_memory",
         "__indirect_function_table",
         "__stack_pointer",
         "__memory_base",
         "__table_base"
     };

# ─── LEB128 / byte emit helpers ──────────────────────────────────────────────
"""Read an unsigned LEB128. Returns (value, new_offset)."""
def _rd_uleb(b: bytes, o: int) -> tuple {
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

"""Read a signed LEB128. Returns (value, new_offset)."""
def _rd_sleb(b: bytes, o: int) -> tuple {
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

"""Encode an unsigned LEB128 (minimal length)."""
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

"""Encode a fixed 5-byte padded unsigned LEB128 (for in-place reloc rewrite).

Also valid as a 5-byte signed LEB for small non-negative values (memory
addresses, table slots), since the sign bit of the 5th byte stays clear."""
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

"""Encode a signed LEB128 (minimal length), used for init-expr constants."""
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

"""Little-endian u32."""
def _u32le(v: int) -> bytes {
    return (v & 0xffffffff).to_bytes(4, "little");
}

"""Read a length-prefixed name. Returns (str, new_offset)."""
def _rd_name(b: bytes, o: int) -> tuple {
    (n, o) = _rd_uleb(b, o);
    return (b[o:o + n].decode("latin1"), o + n);
}

"""Emit a length-prefixed UTF-8 name."""
def _nm_bytes(s: str) -> bytes {
    e = s.encode("utf-8");
    return _uleb(len(e)) + e;
}

"""Emit a section: id byte, ULEB size, payload."""
def _section(sid: int, payload: bytes) -> bytes {
    return bytes([sid]) + _uleb(len(payload)) + payload;
}

"""Emit a vector: ULEB count then concatenated items."""
def _vec(items: list) -> bytes {
    return _uleb(len(items)) + b"".join(items);
}

"""Overwrite buf[off:off+len(data)] in place (byte-wise; no slice assign)."""
def _patch(buf: bytearray, off: int, data: bytes) {
    i = 0;
    while i < len(data) {
        buf[off + i] = data[i];
        i += 1;
    }
}

# ─── Parsed relocatable object ───────────────────────────────────────────────
"""A parsed relocatable wasm object (subset of sections the linker needs).

imports : list of [kind, module, field, extra]  (kind in func/table/mem/global)
func_types : type index per defined function
symtab : list of [kind, flags, idx_or_seginfo, name]   (linking symbol table)
relocs : list of [reloc_section_name, type, offset, sym_index, addend]
seg_info : list of (name, align_log2, flags) from SEGMENT_INFO
"""
obj WasmObj {
    has b: bytes,
        types_raw: list = [],
        imports: list = [],
        func_types: list = [],
        code: bytes = b"",
        data_raw: bytes = b"",
        symtab: list = [],
        relocs: list = [],
        seg_info: list = [];

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
                o += 1;  # 0x60 form byte
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
                    mut = b[o];
                    o += 1;
                    self.imports.append(["global", mod, fld, (vt, mut)]);
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
        if sub == 8 {  # WASM_SYMBOL_TABLE
            (cnt, o) = _rd_uleb(b, o);
            ci = 0;
            while ci < cnt {
                kind = b[o];
                o += 1;
                (flags, o) = _rd_uleb(b, o);
                undef = flags & 0x10;
                if kind == 0 or kind == 2 or kind == 5 {
                    (idx, o) = _rd_uleb(b, o);
                    nm = None;
                    if not undef {
                        (nm, o) = _rd_name(b, o);
                    }
                    self.symtab.append([kind, flags, idx, nm]);
                } elif kind == 1 {  # DATA
                    (nm, o) = _rd_name(b, o);
                    info = None;
                    if not undef {
                        (sg, o) = _rd_uleb(b, o);
                        (of, o) = _rd_uleb(b, o);
                        (sz, o) = _rd_uleb(b, o);
                        info = (sg, of, sz);
                    }
                    self.symtab.append([kind, flags, info, nm]);
                }
                ci += 1;
            }
        } elif sub == 5 {  # WASM_SEGMENT_INFO
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

"""Parse the data section payload into a list of segment content byte strings."""
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
        if flags == 0 {  # active, mem 0, offset expr
            o += 1;  # 0x41 i32.const
            (_v, o) = _rd_sleb(b, o);
            o += 1;  # 0x0b end
            (sz, o) = _rd_uleb(b, o);
            segs.append(b[o:o + sz]);
            o += sz;
        } elif flags == 1 {  # passive
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

"""Resolve a linking-table symbol index to its final value.

FUNCTION -> final function index; GLOBAL -> 0 (the synthesized __stack_pointer);
DATA -> final linear-memory address (segment base + intra-segment offset)."""
def _sym_val(ob: WasmObj, si: int, old2new: dict, seg_base: list) -> int {
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
        return seg_base[idx[0]] + idx[1];
    }
    raise ValueError(f"unsupported symbol kind {k}");
}

# ─── Linker ──────────────────────────────────────────────────────────────────
"""Pure-Jac single-object wasm linker.

`link` turns one relocatable wasm object into an instantiable module.
"""
obj WasmLinker {
    """Link `obj_bytes` into a complete wasm module.

    export_funcs: names to export; empty => export every defined function.
    mem_pages: initial linear-memory size in 64 KiB pages."""
    static def link(
        obj_bytes: bytes, export_funcs: list = [], mem_pages: int = 256
    ) -> bytes;
}

impl WasmLinker.link(
    obj_bytes: bytes, export_funcs: list = [], mem_pages: int = 256
) -> bytes {
    ob = WasmObj(b=obj_bytes);
    segs = _parse_data_segments(ob.data_raw);

    # ── memory layout: data segments at 1024, then a stack, then the heap ──
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
    stack_top = base + (1 << 18);  # 256 KiB stack
    heap_base = ((stack_top + 15) // 16) * 16;

    # ── final function index space: kept imports first, then defined funcs ──
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

    # ── assign indirect-table slots to address-taken funcs (slot 0 = null) ──
    # needs_table: the code references table 0 (call_indirect / table ops) even
    # if no function is address-taken in this object - the table must still exist.
    slot_of = {};
    nslot = 1;
    needs_table = False;
    for r in ob.relocs {
        rt = r[1];
        if rt == 1 or rt == 2 or rt == 20 {
            needs_table = True;
        }
        if rt == 1 or rt == 2 {
            fi = _sym_val(ob, r[3], old2new, seg_base);
            if fi in slot_of { } else {
                slot_of[fi] = nslot;
                nslot += 1;
            }
        }
    }

    # ── rewrite code relocations in place ──
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
            _patch(code, off, _uleb5(_sym_val(ob, sym, old2new, seg_base)));
        } elif rt == 1 {
            _patch(code, off, _uleb5(slot_of[_sym_val(ob, sym, old2new, seg_base)]));
        } elif rt == 2 {
            _patch(code, off, _u32le(slot_of[_sym_val(ob, sym, old2new, seg_base)]));
        } elif rt == 3 or rt == 4 {
            _patch(code, off, _uleb5(_sym_val(ob, sym, old2new, seg_base) + add));
        } elif rt == 5 {
            _patch(code, off, _u32le(_sym_val(ob, sym, old2new, seg_base) + add));
        } elif rt == 6 {
            # TYPE_INDEX_LEB - identity for a single object (type section kept as-is)
        } elif rt == 7 {
            _patch(code, off, _uleb5(_sym_val(ob, sym, old2new, seg_base)));
        } elif rt == 20 {
            _patch(code, off, _uleb5(0));  # TABLE_NUMBER_LEB -> table 0
        } else {
            raise ValueError(f"unsupported reloc type {rt}");
        }
    }

    # ── emit the module ──
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
        out += _section(4, _vec([b"\x70\x00" + _uleb(nslot)]));  # funcref table
    }
    out += _section(5, _vec([b"\x00" + _uleb(mem_pages)]));  # memory
    g_sp = b"\x7f\x01\x41" + _sleb_bytes(stack_top) + b"\x0b";  # mut i32
    g_hb = b"\x7f\x00\x41" + _sleb_bytes(heap_base) + b"\x0b";  # const i32
    out += _section(6, _vec([g_sp, g_hb]));

    ef = export_funcs;
    if not ef {
        ef = [];
        for e in ob.symtab {
            if e[0] == 0 and e[3] and not (e[1] & 0x10) {
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
        }  # (slot, funcidx)
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
    return bytes(out);
}
