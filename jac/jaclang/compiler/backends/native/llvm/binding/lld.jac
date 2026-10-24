import from ctypes { c_int, c_uint, c_char_p, c_size_t, POINTER }

glob _LLD_SPENT: list[bool] = [];

def lld_link(args: list[str]) -> tuple[int, str] {
    if _LLD_SPENT {
        raise RuntimeError(
            "LLD crashed earlier in this process and cannot link again; rerun the build"
        );
    }
    argv = (c_char_p * len(args))(*[a.encode("utf-8") for a in args]);
    can_run_again = c_int(1);
    with ffi.OutputString() as out {
        code = ffi.lib.LLVMPY_LldLink(argv, len(args), out, can_run_again);
        text = str(out);
    }
    if not can_run_again.value {
        _LLD_SPENT.append(True);
    }
    return (int(code), text);
}

def write_import_library(
    dll_name: str, path: str, machine: int, names: list[str], import_names: list[str]
) {
    c_names = (c_char_p * len(names))(*[n.encode("utf-8") for n in names]);
    c_imports = (c_char_p * len(names))(*[n.encode("utf-8") for n in import_names]);
    with ffi.OutputString() as err {
        failed = ffi.lib.LLVMPY_WriteImportLibrary(
            dll_name.encode("utf-8"),
            path.encode("utf-8"),
            machine,
            c_names,
            c_imports,
            len(names),
            err
        );
        if failed {
            raise RuntimeError(
                f"cannot write the import library for {dll_name}: {err}"
            );
        }
    }
}

def object_symbols(data: bytes) -> tuple[set[str], set[str]] {
    defined: set[str] = set();
    undefined: set[str] = set();
    for (kind, name, _address) in _symbol_rows(data, False) {
        if kind == "U" {
            undefined.add(name);
        } else {
            defined.add(name);
        }
    }
    return (defined, undefined);
}

def image_symbol_addresses(data: bytes) -> list[tuple[str, int]] {
    return [
        (name, address)
        for (kind, name, address) in _symbol_rows(data, True)
        if kind == "D"
    ];
}

def _symbol_rows(data: bytes, with_locals: bool) -> list[tuple[str, str, int]] {
    with ffi.OutputString() as out {
        failed = ffi.lib.LLVMPY_ObjectSymbols(
            data, len(data), 1 if with_locals else 0, out
        );
        text = str(out);
    }
    if failed {
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

with entry {
    ffi.lib.LLVMPY_LldLink.argtypes = [
        POINTER(c_char_p),
        c_size_t,
        POINTER(c_char_p),
        POINTER(c_int)
    ];
    ffi.lib.LLVMPY_LldLink.restype = c_int;
    ffi.lib.LLVMPY_WriteImportLibrary.argtypes = [
        c_char_p,
        c_char_p,
        c_uint,
        POINTER(c_char_p),
        POINTER(c_char_p),
        c_size_t,
        POINTER(c_char_p)
    ];
    ffi.lib.LLVMPY_WriteImportLibrary.restype = c_int;
    ffi.lib.LLVMPY_ObjectSymbols.argtypes = [
        c_char_p,
        c_size_t,
        c_int,
        POINTER(c_char_p)
    ];
    ffi.lib.LLVMPY_ObjectSymbols.restype = c_int;
}
