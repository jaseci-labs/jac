impl wasm_ld_args(
    output_path: str,
    inputs: list[str],
    export_funcs: list[str],
    allow_file: str = "",
    memory_pages: int = WASM_MEMORY_PAGES
) -> list[str] {
    """wasm-ld's arguments for a Jac wasm module: memory and the stack pointer
    stay inside the module (256 pages, a 256 KiB stack above the data, which
    starts at 1024), and the module exports its memory, `__stack_pointer`,
    `__heap_base` and the functions named. Undefined functions become
    imports: only those listed in `allow_file`, or any when there is none.""";
    args = [
        "-o",
        output_path,
        "--no-entry",
        "--no-stack-first",
        f"--initial-memory={memory_pages * 65536}",
        f"--global-base={WASM_GLOBAL_BASE}",
        "-z",
        f"stack-size={WASM_STACK_BYTES}",
        f"--allow-undefined-file={allow_file}" if allow_file else "--allow-undefined",
        "--export=__heap_base",
        "--export=__stack_pointer"
    ];
    for name in export_funcs {
        args.append(f"--export={name}");
    }
    return args + inputs;
}

impl wasm_object_functions(obj_bytes: bytes) -> list[str] {
    """The functions a wasm relocatable object defines and does not keep
    local, read from its `linking` section's symbol table: what a module
    exports when its caller names no exports. (The wasm target hides
    symbols by default, so visibility does not decide this.)""";
    names: list[str] = [];
    o = 8;
    while o < len(obj_bytes) {
        sid = obj_bytes[o];
        (size, body) = read_uleb128(obj_bytes, o + 1);
        end = body + size;
        if sid == 0 {
            (section, p) = read_leb_name(obj_bytes, body);
            if section == "linking" {
                (_version, p) = read_uleb128(obj_bytes, p);
                while p < end {
                    kind = obj_bytes[p];
                    (sub_size, q) = read_uleb128(obj_bytes, p + 1);
                    sub_end = q + sub_size;
                    if kind == 8 {
                        names.extend(_symbol_table_functions(obj_bytes, q));
                    }
                    p = sub_end;
                }
            }
        }
        o = end;
    }
    return names;
}

impl _symbol_table_functions(b: bytes, p: int) -> list[str] {
    names: list[str] = [];
    (count, p) = read_uleb128(b, p);
    i = 0;
    while i < count {
        kind = b[p];
        (flags, p) = read_uleb128(b, p + 1);
        undefined = bool(flags & 0x10);
        if kind == 1 {
            (name, p) = read_leb_name(b, p);
            if not undefined {
                (_segment, p) = read_uleb128(b, p);
                (_offset, p) = read_uleb128(b, p);
                (_size, p) = read_uleb128(b, p);
            }
        } elif kind == 3 {
            (_index, p) = read_uleb128(b, p);
            name = "";
        } else {
            (_index, p) = read_uleb128(b, p);
            name = "";
            if not undefined or flags & 0x40 {
                (name, p) = read_leb_name(b, p);
            }
            if kind == 0 and not undefined and not flags & 0x2 and name {
                names.append(name);
            }
        }
        i += 1;
    }
    return names;
}

impl write_allowed_imports(path: str, names: list[str]) {
    with open(path, "w") as f {
        f.write("".join(f"{name}\n" for name in sorted(set(names))));
    }
}

impl read_uleb128(b: bytes, o: int) -> tuple[int, int] {
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

impl encode_uleb128(v: int) -> bytes {
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

impl read_leb_name(b: bytes, o: int) -> tuple[str, int] {
    (n, o) = read_uleb128(b, o);
    return (b[o:o + n].decode("utf-8"), o + n);
}

impl _name_bytes(name: str) -> bytes {
    raw = name.encode("utf-8");
    return encode_uleb128(len(raw)) + raw;
}

impl rename_wasm_imports(wasm_bytes: bytes, names: set[str], module: str) -> bytes {
    """Move the function imports named in `names` into import module
    `module`. wasm-ld imports every undefined function from `env`; the host
    ABI lives in its own module, so the host can tell its syscalls from the
    app's imports.""";
    out = bytearray(wasm_bytes[:8]);
    o = 8;
    while o < len(wasm_bytes) {
        sid = wasm_bytes[o];
        (size, body) = read_uleb128(wasm_bytes, o + 1);
        end = body + size;
        if sid != 2 {
            out += wasm_bytes[o:end];
            o = end;
            continue;
        }
        (count, p) = read_uleb128(wasm_bytes, body);
        entries = bytearray(encode_uleb128(count));
        i = 0;
        while i < count {
            (mod_name, p) = read_leb_name(wasm_bytes, p);
            (field, p) = read_leb_name(wasm_bytes, p);
            desc_start = p;
            kind = wasm_bytes[p];
            p += 1;
            if kind == 0 {
                (_type_index, p) = read_uleb128(wasm_bytes, p);
            } elif kind == 1 {
                p += 1;
                flags = wasm_bytes[p];
                (_lo, p) = read_uleb128(wasm_bytes, p + 1);
                if flags & 1 {
                    (_hi, p) = read_uleb128(wasm_bytes, p);
                }
            } elif kind == 2 {
                flags = wasm_bytes[p];
                (_lo, p) = read_uleb128(wasm_bytes, p + 1);
                if flags & 1 {
                    (_hi, p) = read_uleb128(wasm_bytes, p);
                }
            } elif kind == 3 {
                p += 2;
            } else {
                p += 1;
                (_tag_type, p) = read_uleb128(wasm_bytes, p);
            }
            if kind == 0 and field in names {
                mod_name = module;
            }
            entries += _name_bytes(mod_name)
                + _name_bytes(field)
                + wasm_bytes[desc_start:p];
            i += 1;
        }
        out.append(2);
        out += encode_uleb128(len(entries)) + entries;
        o = end;
    }
    return bytes(out);
}

impl wasm_import_map(wasm_bytes: bytes) -> dict[str, list[str]] {
    out: dict[str, list[str]] = {};
    o = 8;
    while o < len(wasm_bytes) {
        sid = wasm_bytes[o];
        o += 1;
        (size, o) = read_uleb128(wasm_bytes, o);
        end = o + size;
        if sid == 2 {
            (cnt, o) = read_uleb128(wasm_bytes, o);
            ci = 0;
            while ci < cnt and o < end {
                (mod_nm, o) = read_leb_name(wasm_bytes, o);
                (fld, o) = read_leb_name(wasm_bytes, o);
                kind = wasm_bytes[o];
                o += 1;
                if kind == 0 {
                    (_t, o) = read_uleb128(wasm_bytes, o);
                    out.setdefault(mod_nm, []).append(fld);
                } else {
                    break;
                }
                ci += 1;
            }
            break;
        }
        o = end;
    }
    for k in out {
        out[k].sort();
    }
    return out;
}

impl wasm_assets(stem: str, content: bytes) -> dict[str, bytes] {
    manifest = {'abi': WASM_HOST_MODULE, 'imports': wasm_import_map(content)};
    return {
        f'{stem}.wasm': content,
        f'{stem}.wasm.imports.json': json.dumps(manifest, indent=2).encode('utf-8')
    };
}
