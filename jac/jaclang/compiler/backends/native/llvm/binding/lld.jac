glob _LLD_SPENT: list[bool] = [];

"""Run LLD in process; `args` starts with the flavor (`ld.lld`, `ld64.lld`,
`lld-link`, `wasm-ld`). Returns the exit code and LLD's output."""
def lld_link(args: list[str]) -> tuple[int, str] {
    if _LLD_SPENT {
        raise RuntimeError(
            "LLD crashed earlier in this process and cannot link again; rerun the build"
        );
    }
    argv = c_text_array(args);
    out: ptr[u8] = ptr[u8]();
    can_run_again: i32 = i32(1);
    code = LLVMPY_LldLink(argv, u64(len(args)), &mut out, &mut can_run_again);
    free_text_array(argv, len(args));
    text = take_text(out);
    if can_run_again == 0 {
        _LLD_SPENT.append(True);
    }
    return (int(code), text);
}

def write_import_library(
    dll_name: str, path: str, machine: int, names: list[str], import_names: list[str]
) {
    if len(import_names) != len(names) {
        raise ValueError("an import library needs one import name per export");
    }
    c_names = c_text_array(names);
    c_imports = c_text_array(import_names);
    err: ptr[u8] = ptr[u8]();
    failed = LLVMPY_WriteImportLibrary(
        dll_name, path, u32(machine), c_names, c_imports, u64(len(names)), &mut err
    );
    free_text_array(c_names, len(names));
    free_text_array(c_imports, len(import_names));
    message = take_text(err);
    if failed != 0 {
        raise RuntimeError(f"cannot write the import library for {dll_name}: {message}");
    }
}

def object_symbols(data: bytes) -> tuple[set[str], set[str]] {
    defined: set[str] = set();
    undefined: set[str] = set();
    for row in _symbol_rows(data, False) {
        if row[0] == "U" {
            undefined.add(row[1]);
        } else {
            defined.add(row[1]);
        }
    }
    return (defined, undefined);
}

def image_symbol_addresses(data: bytes) -> list[tuple[str, int]] {
    out: list[tuple[str, int]] = [];
    for row in _symbol_rows(data, True) {
        if row[0] == "D" {
            out.append((row[1], row[2]));
        }
    }
    return out;
}

def _symbol_rows(data: bytes, with_locals: bool) -> list[tuple[str, str, int]] {
    out: ptr[u8] = ptr[u8]();
    failed = LLVMPY_ObjectSymbols(
        data, u64(len(data)), i32(1 if with_locals else 0), &mut out
    );
    text = take_text(out);
    if failed != 0 {
        raise RuntimeError(f"cannot read an object's symbols: {text}");
    }
    rows: list[tuple[str, str, int]] = [];
    for line in text.splitlines() {
        parts = line.split(" ");
        if len(parts) == 2 and parts[0] == "U" {
            rows.append(("U", parts[1], 0));
        } elif len(parts) == 3 and parts[0] == "D" {
            rows.append(("D", parts[1], int(parts[2], 16)));
        }
    }
    return rows;
}
