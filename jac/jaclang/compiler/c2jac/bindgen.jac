import from jaclang.vendor.pycparser { c_ast }
import from jaclang.jac0core.helpers { read_file_with_encoding }
import from jaclang.compiler.c2jac.c_common { parse_c_int, jac_id, enumerator_value }

glob _FFI_SCALARS: set = {
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

     },
     _STDINT_SCALARS: dict = {
         "int8_t": "i8",
         "uint8_t": "u8",
         "int16_t": "i16",
         "uint16_t": "u16",
         "int32_t": "i32",
         "uint32_t": "u32",
         "int64_t": "i64",
         "uint64_t": "u64",
         "intmax_t": "i64",
         "uintmax_t": "u64",
         "intptr_t": "i64",
         "uintptr_t": "u64",
         "ptrdiff_t": "i64",
         "size_t": "u64",
         "ssize_t": "i64",

     };

obj BindReport {
    has functions: int = 0,
        constants: int = 0,
        variadic: int = 0,
        skipped: int = 0;
}

def ffi_prim(names: list) -> str {
    if not names {
        return "i32";
    }
    if "void" in names {
        return "None";
    }
    if "double" in names {
        return "f64";
    }
    if "float" in names {
        return "f32";
    }
    if "bool" in names or "_Bool" in names {
        return "bool";
    }
    unsigned = "unsigned" in names;
    if "char" in names {
        if "signed" in names {
            return "i8";
        }
        if unsigned {
            return "u8";
        }
        return "i8";
    }
    if names.count("long") >= 2 {
        return "u64" if unsigned else "i64";
    }
    if "long" in names {
        return "u64" if unsigned else "i64";
    }
    if "short" in names {
        return "u16" if unsigned else "i16";
    }
    if "int" in names or "signed" in names or unsigned {
        return "u32" if unsigned else "i32";
    }
    return "int";
}

def _collect_typedefs(file_ast: object) -> dict {
    out: dict = {};
    for ext in file_ast.ext {
        if not isinstance(ext, c_ast.Typedef) {
            continue;
        }
        inner = ext.type;
        if isinstance(inner, c_ast.TypeDecl)
        and isinstance(inner.type, c_ast.IdentifierType) {
            out[ext.name] = inner.type.names;
        }
    }
    return out;
}

def _scalar_for_names(names: list, typedefs: dict, depth: int = 0) -> str {
    if names and len(names) == 1 and depth < 16 {
        nm = names[0];
        if nm in _STDINT_SCALARS {
            return _STDINT_SCALARS[nm];
        }
        if nm in typedefs {
            return _scalar_for_names(typedefs[nm], typedefs, depth + 1);
        }
    }
    return ffi_prim(names);
}

def _ptr_ffi(ptr_decl: object, typedefs: dict) -> str {
    inner = ptr_decl.type;
    if isinstance(inner, c_ast.TypeDecl) {
        names = inner.type?.names or [];
        if "char" in names and "signed" not in names and "unsigned" not in names {
            return "str";
        }
        if names and _scalar_for_names(names, typedefs) in _FFI_SCALARS {
            return "bytes";
        }
    }
    return "int";
}

def ffi_type(decl_type: object, typedefs: dict | None = None) -> str {
    tds = typedefs or {};
    t = decl_type;
    while not isinstance(t, c_ast.TypeDecl) {
        if isinstance(t, c_ast.ArrayDecl) {
            return "int";
        }
        if isinstance(t, c_ast.PtrDecl) {
            return _ptr_ffi(t, tds);
        }
        if isinstance(t, c_ast.FuncDecl) {
            t = t.type;
            continue;
        }
        t = t?.type;
        if t is None {
            return "int";
        }
    }
    names = t.type?.names or ["int"];
    return _scalar_for_names(names, tds);
}

def _is_void_params(params: list) -> bool {
    if len(params) != 1 {
        return False;
    }
    p = params[0];
    if isinstance(p, c_ast.EllipsisParam) {
        return False;
    }
    t = p.type;
    if isinstance(t, c_ast.TypeDecl) {
        return (t.type?.names or []) == ["void"];
    }
    return False;
}

def _func_signature(funcdecl: object, typedefs: dict) -> tuple {
    pl = funcdecl.args;
    if pl is None {
        return ("", False);
    }
    params = pl.params;
    if _is_void_params(params) {
        return ("", False);
    }
    parts: list[str] = [];
    is_var = False;
    idx = 0;
    for p in params {
        if isinstance(p, c_ast.EllipsisParam) {
            parts.append("*rest");
            is_var = True;
            continue;
        }
        pname = jac_id(p.name or f"arg{idx}");
        parts.append(f"{pname}: {ffi_type(p.type, typedefs)}");
        idx += 1;
    }
    return (", ".join(parts), is_var);
}

def _lib_token(lib: str) -> str {
    for c in lib {
        if not (c.isalnum() or c == "_") {
            escaped = lib.replace("\\", "\\\\").replace("\"", "\\\"");
            return f"\"{escaped}\"";
        }
    }
    return lib;
}

def _emit_func_block(lib: str, name: str, sig: str, ret: str) -> str {
    return f"import from {_lib_token(lib)} {{ def {jac_id(name)}({sig}) -> {ret}; }}\n";
}

def _func_node(ext: object) -> object {
    if isinstance(ext, c_ast.FuncDef) {
        return ext.decl;
    }
    if isinstance(ext, c_ast.Decl) and isinstance(ext.type, c_ast.FuncDecl) {
        return ext;
    }
    return None;
}

def _int_from_macro_tokens(toks: list) -> int | None {
    parts = [
        t
        for t in toks
        if t[0] != "CPP_WS"
    ];
    if not parts {
        return None;
    }
    sign = 1;
    idx = 0;
    if parts[0][0] in ("CPP_MINUS", "CPP_PLUS") {
        if parts[0][0] == "CPP_MINUS" {
            sign = -1;
        }
        idx = 1;
    }
    if len(parts) - idx != 1 or parts[idx][0] != "CPP_INTEGER" {
        return None;
    }
    v = parse_c_int(parts[idx][1]);
    return None if v is None else sign * v;
}


def _enum_def(ext: object) -> object | None {
    t = ext?.type;
    while t is not None and not isinstance(t, c_ast.Enum) {
        t = t?.type;
    }
    if isinstance(t, c_ast.Enum) and t.values is not None {
        return t;
    }
    return None;
}


def _eval_enum(enum_node: object) -> list | None {
    out: list = [];
    nxt = 0;
    for en in enum_node.values.enumerators {
        (val, simple) = enumerator_value(en, nxt);
        if not simple {
            return None;
        }
        out.append((en.name, val));
        nxt = val + 1;
    }
    return out;
}


def _emit_const_block(name: str, value: int) -> str {
    return f"glob {jac_id(name)}: int = {value};\n";
}


def _take_const(
    cname: str,
    val: int,
    allow_set: (set | None),
    block_set: set,
    seen: set,
    lines: list,
    rep: BindReport
) -> None {
    if (allow_set is not None and cname not in allow_set) or cname in block_set {
        rep.skipped += 1;
        return;
    }
    if cname in seen {
        rep.skipped += 1;
        return;
    }
    seen.add(cname);
    lines.append(_emit_const_block(cname, val));
    rep.constants += 1;
}


def _emit_consts(
    file_ast: object,
    macros: (dict | None),
    allow_set: (set | None),
    block_set: set,
    rep: BindReport,
    emitted_names: (set | None) = None
) -> str {
    lines: list[str] = [];
    seen: set = set(emitted_names) if emitted_names else set();
    for ext in file_ast.ext {
        enum_node = _enum_def(ext);
        if enum_node is None {
            continue;
        }
        pairs = _eval_enum(enum_node);
        if pairs is None {
            rep.skipped += 1;
            continue;
        }
        for (cname, val) in pairs {
            _take_const(cname, val, allow_set, block_set, seen, lines, rep);
        }
    }
    for (mname, toks) in (macros or {}).items() {
        val = _int_from_macro_tokens(toks);
        if val is not None {
            _take_const(mname, val, allow_set, block_set, seen, lines, rep);
        }
    }
    if not lines {
        return "";
    }
    return "\n# Integer constants (enum / #define).\n" + "".join(lines);
}


def _emit_bindings(
    file_ast: object,
    lib: str,
    allow: (list[str] | None),
    block: (list[str] | None),
    macros: (dict | None) = None
) -> tuple[str, BindReport] {
    allow_set = set(allow) if allow else None;
    block_set = set(block) if block else set();
    typedefs = _collect_typedefs(file_ast);
    rep = BindReport();
    blocks: list[str] = [];
    fn_names: set[str] = set();
    for ext in file_ast.ext {
        fn = _func_node(ext);
        if fn is None or fn.name is None {
            continue;
        }
        name = fn.name;
        if (allow_set is not None and name not in allow_set) or name in block_set {
            rep.skipped += 1;
            continue;
        }
        funcdecl = fn.type;
        (sig, is_var) = _func_signature(funcdecl, typedefs);
        ret = ffi_type(funcdecl.type, typedefs);
        blocks.append(_emit_func_block(lib, name, sig, ret));
        fn_names.add(name);
        rep.functions += 1;
        if is_var {
            rep.variadic += 1;
        }
    }
    consts = _emit_consts(file_ast, macros, allow_set, block_set, rep, fn_names);
    header = f"# Native FFI bindings for `{lib}`, generated by `jac cbindgen`.\n" + "# Do not edit by hand — regenerate from the C header.\n\n";
    return (header + "".join(blocks) + consts, rep);
}

def bindings_from_source(
    c_src: str,
    filename: str,
    lib: str,
    include_dirs: (list[str] | None) = None,
    defines: (list[str] | None) = None,
    undefines: (list[str] | None) = None,
    force_includes: (list[str] | None) = None,
    nostdinc: bool = False,
    allow: (list[str] | None) = None,
    block: (list[str] | None) = None
) -> tuple[str, BindReport] {
    macros: dict = {};
    if not filename.endswith(".i") {
        import from jaclang.compiler.c2jac.preprocess { preprocess_c_collect }
        (c_src, macros) = preprocess_c_collect(
            c_src,
            filename,
            include_dirs=include_dirs,
            defines=defines,
            undefines=undefines,
            force_includes=force_includes,
            nostdinc=nostdinc,
        );
    }
    import from jaclang.vendor.pycparser { c_parser }
    parser = c_parser.CParser();
    try {
        file_ast = parser.parse(c_src, filename);
    } except Exception as e {
        if "Directive" in str(e) {
            raise ValueError(
                f"{filename}: generate_bindings expects already-preprocessed C, "
                f"but the input still has #include/#define/#pragma directives. "
                f"Use a .c/.h source (cbindgen preprocesses with pcpp) or a "
                f"preprocessed .i file."
            ) from e;
        }
        raise;
    }
    return _emit_bindings(file_ast, lib, allow, block, macros=macros);
}


def generate_bindings(
    filename: str,
    lib: str,
    include_dirs: (list[str] | None) = None,
    defines: (list[str] | None) = None,
    undefines: (list[str] | None) = None,
    force_includes: (list[str] | None) = None,
    nostdinc: bool = False,
    allow: (list[str] | None) = None,
    block: (list[str] | None) = None
) -> tuple[str, BindReport] {
    c_src = read_file_with_encoding(filename);
    return bindings_from_source(
        c_src,
        filename,
        lib,
        include_dirs=include_dirs,
        defines=defines,
        undefines=undefines,
        force_includes=force_includes,
        nostdinc=nostdinc,
        allow=allow,
        block=block,
    );
}
