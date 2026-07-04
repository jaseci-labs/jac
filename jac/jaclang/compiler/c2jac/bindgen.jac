import from jaclang.vendor.pycparser { c_ast }
import from jaclang.jac0core.helpers { read_file_with_encoding }
import from jaclang.compiler.cfront.c_common {
    parse_c_int,
    jac_id,
    eval_enumerators,
    EnumPairs
}
import from jaclang.compiler.cfront.c_types {
    walk_to_typedecl,
    ptr_inner_typedecl,
    is_plain_char_ptr,
    TypeKind
}
import from jaclang.compiler.cfront.cbind_ir {
    build_binding_module,
    FuncDesc,
    StructDesc,
    ConstDesc
}

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
     _MAX_TYPEDEF_DEPTH: int = 16,
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
        structs: int = 0,
        constants: int = 0,
        externs: int = 0,
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
    if names and len(names) == 1 and depth < _MAX_TYPEDEF_DEPTH {
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

def _ptr_ffi(ptr_decl: object, typedefs: dict, structs: (set | None) = None) -> str {
    if is_plain_char_ptr(ptr_decl) {
        return "str";
    }
    inner = ptr_inner_typedecl(ptr_decl);
    if inner is not None {
        names = inner.type?.names or [];
        if names and _scalar_for_names(names, typedefs) in _FFI_SCALARS {
            return "bytes";
        }
    }
    return "int";
}

def ffi_type(
    decl_type: object, typedefs: dict | None = None, structs: (set | None) = None
) -> str {
    tds = typedefs or {};
    chain = walk_to_typedecl(decl_type);
    if chain.kind == TypeKind.ARRAY {
        return "int";
    }
    if chain.kind == TypeKind.PTR {
        return _ptr_ffi(chain.node, tds, structs);
    }
    if chain.kind == TypeKind.NONE {
        return "int";
    }
    scalar = chain.node;
    if isinstance(scalar.type, c_ast.Struct)
    and scalar.type.name
    and structs
    and scalar.type.name in structs {
        return scalar.type.name;
    }
    names = scalar.type?.names or ["int"];
    if names and len(names) == 1 and structs and names[0] in structs {
        return names[0];
    }
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

obj FuncSig {
    has params: list[tuple[str, str]],
        variadic: bool;
}

def _func_signature(
    funcdecl: object, typedefs: dict, structs: (set | None) = None
) -> FuncSig {
    pl = funcdecl.args;
    if pl is None {
        return FuncSig(params=[], variadic=False);
    }
    params = pl.params;
    if _is_void_params(params) {
        return FuncSig(params=[], variadic=False);
    }
    parts: list[tuple[str, str]] = [];
    is_var = False;
    idx = 0;
    for p in params {
        if isinstance(p, c_ast.EllipsisParam) {
            is_var = True;
            continue;
        }
        pname = jac_id(p.name or f"arg{idx}");
        parts.append((pname, ffi_type(p.type, typedefs, structs)));
        idx += 1;
    }
    return FuncSig(params=parts, variadic=is_var);
}

def _struct_fields_from_node(
    snode: object, typedefs: dict, known_structs: set
) -> list {
    out: list = [];
    for decl in (snode.decls or []) {
        fname = jac_id(decl.name or "_f");
        ft = ffi_type(decl.type, typedefs, known_structs);
        out.append((fname, ft));
    }
    return out;
}

obj StructDefs {
    has emit_defs: list,
        all_names: set;
}

def _collect_struct_defs(file_ast: object, typedefs: dict) -> StructDefs {
    emit_defs: list = [];
    all_names: set = set();
    for ext in file_ast.ext {
        if isinstance(ext, c_ast.Typedef) {
            inner = ext.type;
            if not (
                isinstance(inner, c_ast.TypeDecl)
                and isinstance(inner.type, c_ast.Struct)
            ) {
                continue;
            }
            snode = inner.type;
            if snode.decls is None {
                continue;
            }
            if ext.name in all_names {
                continue;
            }
            fields = _struct_fields_from_node(snode, typedefs, all_names);
            emit_defs.append((ext.name, fields));
            all_names.add(ext.name);
            if snode.name {
                all_names.add(snode.name);
            }
        } elif isinstance(ext, c_ast.Decl) {
            t = ext.type;
            if not (isinstance(t, c_ast.Struct) and t.name and t.decls is not None) {
                continue;
            }
            if t.name in all_names {
                continue;
            }
            fields = _struct_fields_from_node(t, typedefs, all_names);
            emit_defs.append((t.name, fields));
            all_names.add(t.name);
        }
    }
    return StructDefs(emit_defs=emit_defs, all_names=all_names);
}

def _collect_struct_descs(
    emit_defs: list, block_set: set, rep: BindReport
) -> list[StructDesc] {
    out: list[StructDesc] = [];
    for (name, fields) in emit_defs {
        if name in block_set {
            rep.skipped += 1;
            continue;
        }
        out.append(StructDesc(name=name, fields=fields));
        rep.structs += 1;
    }
    return out;
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
    ep: EnumPairs = eval_enumerators(enum_node.values);
    if not ep.all_simple {
        return None;
    }
    return ep.pairs;
}


def _take_const(
    cname: str,
    val: int,
    allow_set: (set | None),
    block_set: set,
    seen: set,
    out: list,
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
    out.append(ConstDesc(name=jac_id(cname), value=val));
    rep.constants += 1;
}


def _collect_const_descs(
    file_ast: object,
    macros: (dict | None),
    allow_set: (set | None),
    block_set: set,
    rep: BindReport,
    emitted_names: (set | None) = None
) -> list[ConstDesc] {
    out: list[ConstDesc] = [];
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
            _take_const(cname, val, allow_set, block_set, seen, out, rep);
        }
    }
    for (mname, toks) in (macros or {}).items() {
        val = _int_from_macro_tokens(toks);
        if val is not None {
            _take_const(mname, val, allow_set, block_set, seen, out, rep);
        }
    }
    return out;
}


obj BindDescs {
    has funcs: list[FuncDesc],
        structs: list[StructDesc],
        consts: list[ConstDesc];
}

def collect_descs(
    file_ast: object,
    allow: (list[str] | None),
    block: (list[str] | None),
    macros: (dict | None),
    rep: BindReport
) -> BindDescs {
    allow_set = set(allow) if allow else None;
    block_set = set(block) if block else set();
    typedefs = _collect_typedefs(file_ast);
    sd = _collect_struct_defs(file_ast, typedefs);
    struct_names = sd.all_names;
    struct_descs = _collect_struct_descs(sd.emit_defs, block_set, rep);
    func_descs: list[FuncDesc] = [];
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
        fs = _func_signature(funcdecl, typedefs, struct_names);
        ret = ffi_type(funcdecl.type, typedefs, struct_names);
        func_descs.append(
            FuncDesc(name=jac_id(name), params=fs.params, ret=ret, variadic=fs.variadic)
        );
        fn_names.add(name);
        rep.functions += 1;
        if fs.variadic {
            rep.variadic += 1;
        }
    }
    const_descs = _collect_const_descs(
        file_ast, macros, allow_set, block_set, rep, fn_names
    );
    return BindDescs(funcs=func_descs, structs=struct_descs, consts=const_descs);
}

def _emit_bindings(
    file_ast: object,
    lib: str,
    allow: (list[str] | None),
    block: (list[str] | None),
    macros: (dict | None) = None
) -> tuple[str, BindReport] {
    rep = BindReport();
    d = collect_descs(file_ast, allow, block, macros, rep);
    body = build_binding_module(lib, d.funcs, d.structs, d.consts).unparse();
    header = f"# Native FFI bindings for `{lib}`, generated by `jac cbindgen`.\n" + "# Do not edit by hand, regenerate from the C header.\n\n";
    return (header + body, rep);
}

def parse_header_source(
    c_src: str,
    filename: str,
    include_dirs: (list[str] | None) = None,
    defines: (list[str] | None) = None,
    undefines: (list[str] | None) = None,
    force_includes: (list[str] | None) = None,
    nostdinc: bool = False
) -> tuple {
    macros: dict = {};
    if not filename.endswith(".i") {
        import from jaclang.compiler.cfront.preprocess { preprocess_c_collect }
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
    return (file_ast, macros);
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
    (file_ast, macros) = parse_header_source(
        c_src,
        filename,
        include_dirs=include_dirs,
        defines=defines,
        undefines=undefines,
        force_includes=force_includes,
        nostdinc=nostdinc,
    );
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
