import json;
import from jaclang.compiler.backends.native.wasm_host_abi { WASM_HOST_MODULE }

def wasm_import_map(wasm_bytes: bytes) -> dict[str, list[str]] {
    import from jaclang.compiler.backends.native.linker_common {
        read_leb_name,
        read_uleb128
    }
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

def wasm_assets(stem: str, content: bytes) -> dict[str, bytes] {
    manifest = {'abi': WASM_HOST_MODULE, 'imports': wasm_import_map(content)};
    return {
        f'{stem}.wasm': content,
        f'{stem}.wasm.imports.json': json.dumps(manifest, indent=2).encode('utf-8')
    };
}
