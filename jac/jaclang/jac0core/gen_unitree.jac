import re;

glob EXCLUDE: tuple = (
         "UniNode",
         "Source",
         "CommentToken",
         "ProgramModule",
         "PythonModuleAst",

     ),
     FAMILIES: tuple = (
         "Token",
         "Name",
         "String",
         "MultiString",
         "EmptyToken",
         "Semi",
         "ExprStmt",
         "KWPair",
         "KVPair",
         "GenCompr",
         "JsxElement",
         "ParamVar",
         "ContextAwareNode",
         "FuncSignature",
         "EventSignature",
         "YieldExpr",

     ),
     ENUM_PARAMS: tuple = ("EdgeDir", "OwnershipKind"),
     ARENA_SRC: str = "jac0core/arena.jac",
     BUILDERS_ANNEX: str = "jac0core/arena.impl/builders.impl.jac",
     SCHEMA_OUT: str = "jac0core/arena_schema.jac",
     SPECS_OUT: str = "jac0core/arena_specs.jac",
     DECL_BEGIN: str = "    # >>> generated builder surface (jac gen-unitree) >>>",
     DECL_END: str = "    # <<< generated builder surface <<<";


def abs_path(rel: str) -> str {
    import jaclang;
    import from pathlib { Path }
    return str(Path(jaclang.__file__).parent / rel);
}


def _parts_of(ann: str) -> list[str] {
    out: list[str] = [];
    depth = 0;
    cur = "";
    for ch in ann {
        if ch == "[" {
            depth += 1;
        } elif ch == "]" {
            depth -= 1;
        }
        if ch == "|" and depth == 0 {
            out.append(cur.strip());
            cur = "";
        } else {
            cur += ch;
        }
    }
    out.append(cur.strip());
    return out;
}


def _strip_generic(nm: str) -> str {
    return nm.split("[")[0].strip();
}


obj ParamSpec {
    has name: str,
        cat: str,
        enum_name: str = "",
        optional: bool = False,
        has_default: bool = False,
        default_lit: str = "";
}


obj ClassSpec {
    has name: str,
        snake: str,
        kind_id: int = 0,
        token_family: bool = False,
        has_kid: bool = False,
        params: list[ParamSpec] = [];
}


def _default_lit_for(cat: str, dflt: any) -> str {
    if cat == "NODE" {
        return "NIL";
    }
    if cat in ("LIST", "POLY") {
        return "None";
    }
    if cat == "STR" {
        return "None" if dflt is None else repr(dflt);
    }
    if cat == "BOOL" {
        return "True" if dflt else "False";
    }
    if cat == "INT" {
        return str(dflt);
    }
    if cat == "ENUM" {
        m = re.match(r"<(\w+\.\w+):", repr(dflt));
        return m.group(1) if m else str(dflt);
    }
    return "None";
}


def _classify(
    pname: str, ann: str, class_names: set[str]
) -> (tuple[(str, bool, str)] | None) {
    if pname == "kid" {
        return ("KID", False, "");
    }
    parts = _parts_of(ann);
    optional = "None" in parts;
    parts = [
        p
        for p in parts
        if p != "None"
    ];
    if not parts {
        return ("NODE", True, "");
    }
    bases = [_strip_generic(p) for p in parts];
    if all(b == "Source" for b in bases) {
        return ("SOURCE", optional, "");
    }
    seq_re = re.compile(r"^(?:Sequence|list)\[(.+)\]$");
    if len(parts) == 1 {
        (p, b) = (parts[0], bases[0]);
        if b == "str" {
            return ("STR", optional, "");
        }
        if b == "int" {
            return ("INT", optional, "");
        }
        if b == "bool" {
            return ("BOOL", optional, "");
        }
        if b in ENUM_PARAMS {
            return ("ENUM", optional, b);
        }
        if seq_re.match(p) {
            return ("LIST", optional, "");
        }
        if b == "T" {
            return ("POLY", optional, "");
        }
        if b in class_names or b in ("UniNode", "NameAtom", "AtomExpr") {
            return ("NODE", optional, "");
        }
        return None;
    }
    seqs = [
        p
        for p in parts
        if seq_re.match(p)
    ];
    nodes = [
        p
        for p in parts
        if not seq_re.match(p)
    ];
    if seqs and not nodes {
        return ("LIST", optional, "");
    }
    if nodes and not seqs {
        if all(_strip_generic(p) == "str" for p in nodes) {
            return ("STR", optional, "");
        }
        return ("NODE", optional, "");
    }
    return ("POLY", optional, "");
}


def collect_schema -> list[ClassSpec] {
    import inspect;
    import from jaclang.jac0core { unitree as ut_mod }
    import from jaclang.jac0core.unitree { UniNode, Token }
    import from jaclang.jac0core.helpers { pascal_to_snake }

    class_names: set[str] = set();
    for nm in dir(ut_mod) {
        attr = getattr(ut_mod, nm);
        if isinstance(attr, type) and issubclass(attr, UniNode) {
            class_names.add(nm);
        }
    }

    out: list[ClassSpec] = [];
    for nm in sorted(class_names) {
        if nm in EXCLUDE {
            continue;
        }
        cls = getattr(ut_mod, nm);
        spec = ClassSpec(
            name=nm, snake=pascal_to_snake(nm), token_family=issubclass(cls, Token)
        );
        sig = inspect.signature(cls.__init__);
        for (pname, p) in sig.parameters.items() {
            if pname == "self" {
                continue;
            }
            ann = p.annotation;
            ann_s = "" if ann is inspect.Parameter.empty else str(ann);
            got = _classify(pname, ann_s, class_names);
            if got is None {
                raise ValueError(f"gen-unitree: unclassifiable {nm}.{pname}: {ann_s}");
            }
            (cat, optional, ename) = got;
            if cat == "KID" {
                spec.has_kid = True;
                continue;
            }
            has_def = p.default is not inspect.Parameter.empty;
            ps = ParamSpec(
                name=pname,
                cat=cat,
                enum_name=ename,
                optional=(optional or has_def),
                has_default=has_def
            );
            if has_def {
                ps.default_lit = _default_lit_for(cat, p.default);
            }
            spec.params.append(ps);
        }
        out.append(spec);
    }
    kid = 1;
    for spec in out {
        spec.kind_id = kid;
        kid += 1;
    }
    return out;
}


def _family_members(schema: list[ClassSpec]) -> dict[str, list[int]] {
    import from jaclang.jac0core { unitree as ut_mod }
    out: dict[str, list[int]] = {};
    for fam in FAMILIES {
        fam_cls = getattr(ut_mod, fam);
        members: list[int] = [];
        for spec in schema {
            if issubclass(getattr(ut_mod, spec.name), fam_cls) {
                members.append(spec.kind_id);
            }
        }
        out[fam] = members;
    }
    return out;
}


glob _HEADER: str = (
         "# GENERATED by `jac gen-unitree` -- do not edit by hand.\n"
         "# Regenerate after changing unitree constructor signatures;\n"
         "# `jac gen-unitree --verify` gates drift in CI.\n"
     );


def schema_module_src(schema: list[ClassSpec]) -> str {
    lines: list[str] = [
        '"""Arena kind ids and family membership (generated)."""',
        _HEADER,

    ];
    for spec in schema {
        lines.append(f"glob KIND_{spec.snake.upper()}: int = {spec.kind_id};");
    }
    lines.append("");
    for fld in ("doc", "is_enum_stmt") {
        entries: list[str] = [];
        for spec in schema {
            slot = 0;
            for p in spec.params {
                if p.cat == "SOURCE" {
                    continue;
                }
                if p.name == fld {
                    entries.append(f"{spec.kind_id}: {slot}");
                    break;
                }
                slot += 1;
            }
        }
        gname = "DOC_SLOTS" if fld == "doc" else "ENUM_STMT_SLOTS";
        lines.append(f"glob {gname}: dict[int, int] = {{" + ", ".join(entries) + "};");
    }
    lines.append("");
    fams = _family_members(schema);
    for fam in FAMILIES {
        members = ", ".join([str(k) for k in fams[fam]]);
        lines.append(f"glob KS_{_snake_upper(fam)}: list[int] = [{members}];");
    }
    lines.append("");
    return "\n".join(lines);
}


def _snake_upper(nm: str) -> str {
    import from jaclang.jac0core.helpers { pascal_to_snake }
    return pascal_to_snake(nm).upper();
}


def specs_module_src(schema: list[ClassSpec]) -> str {
    lines: list[str] = [
        '"""Materializer specs per arena kind (generated; Python-side only).',
        "",
        "SPECS[kind] = (class_name, params, token_family, has_kid) where each",
        "param is (name, cat, enum_name, has_default). Arg slots map to the",
        "non-SOURCE params in order; SOURCE params consume no slot.",
        '"""',
        _HEADER,
        "glob SPECS: dict[int, tuple] = {",

    ];
    for spec in schema {
        plines: list[str] = [];
        for p in spec.params {
            hd = "True" if p.has_default else "False";
            plines.append(f'("{p.name}", "{p.cat}", "{p.enum_name}", {hd})');
        }
        ptxt = "(" + ", ".join(plines) + ("," if len(plines) == 1 else "") + ")";
        tf = "True" if spec.token_family else "False";
        hk = "True" if spec.has_kid else "False";
        lines.append(f'    {spec.kind_id}: ("{spec.name}", {ptxt}, {tf}, {hk}),');
    }
    lines.append("};");
    lines.append("");
    return "\n".join(lines);
}


def _builder_sig_params(spec: ClassSpec) -> list[str] {
    out: list[str] = [];
    for p in spec.params {
        if p.cat == "SOURCE" {
            continue;
        }
        if p.cat == "NODE" {
            ann = "int";
        } elif p.cat == "LIST" {
            ann = "(list[int] | None)" if p.optional else "list[int]";
        } elif p.cat == "POLY" {
            ann = "(int | list[int] | None)";
        } elif p.cat == "STR" {
            ann = "(str | None)" if p.optional and p.default_lit == "None" else "str";
        } elif p.cat == "INT" {
            ann = "int";
        } elif p.cat == "BOOL" {
            ann = "bool";
        } elif p.cat == "ENUM" {
            ann = p.enum_name;
        } else {
            ann = "int";
        }

        if p.has_default {
            d = f" = {p.default_lit}";
        } elif p.cat == "NODE" {
            d = " = NIL";
        } elif p.cat in ("LIST", "POLY") {
            d = " = None";
            if "None" not in ann {
                ann = f"({ann} | None)";
            }
        } elif p.cat == "STR" {
            d = ' = ""';
        } elif p.cat == "INT" {
            d = " = 0";
        } elif p.cat == "BOOL" {
            d = " = False";
        } elif p.cat == "ENUM" {
            d = f" = {p.enum_name}.{_first_member(p.enum_name)}";
        } else {
            d = "";
        }
        out.append(f"{p.name}: {ann}{d}");
    }
    out.append("kid: list[int] = []");
    return out;
}


def _first_member(enum_name: str) -> str {
    import from jaclang.jac0core { constant as const_mod }
    return list(getattr(const_mod, enum_name))[0].name;
}


def _sig_text(name: str, params: list[str], indent: str) -> str {
    one = f"{indent}def {name}(" + ", ".join(params) + ") -> int";
    if len(one) <= 76 {
        return one;
    }
    inner = f",\n{indent}    ".join(params);
    return f"{indent}def {name}(\n{indent}    {inner}\n{indent}) -> int";
}


def builder_decls_block(schema: list[ClassSpec]) -> str {
    lines: list[str] = [DECL_BEGIN];
    for spec in schema {
        lines.append(
            _sig_text(f"mk_{spec.snake}", _builder_sig_params(spec), "    ") + ";"
        );
    }
    lines.append(DECL_END);
    return "\n".join(lines);
}


def builders_annex_src(schema: list[ClassSpec]) -> str {
    lines: list[str] = [
        '"""Generated SyntaxArena builder methods (one per unitree kind)."""',
        _HEADER,

    ];
    lines.append("");
    for spec in schema {
        argn = len(
            [
                p
                for p in spec.params
                if p.cat != "SOURCE"
            ]
        );
        sig = _sig_text(
            f"SyntaxArena.mk_{spec.snake}", _builder_sig_params(spec), ""
        ).replace(
            "def SyntaxArena.", "impl SyntaxArena.", 1
        );
        lines.append(sig + " {");
        lines.append(f"    idx = self._start({spec.kind_id}, kid, {argn});");
        for p in spec.params {
            if p.cat == "SOURCE" {
                continue;
            }
            if p.cat == "NODE" {
                lines.append(f"    self._arg_node({p.name});");
            } elif p.cat == "LIST" {
                lines.append(f"    self._arg_list({p.name});");
            } elif p.cat == "POLY" {
                lines.append(f"    self._arg_poly({p.name});");
            } elif p.cat == "STR" {
                lines.append(f"    self._arg_str({p.name});");
            } elif p.cat == "INT" {
                lines.append(f"    self._arg_int({p.name});");
            } elif p.cat == "BOOL" {
                lines.append(f"    self._arg_bool({p.name});");
            } elif p.cat == "ENUM" {
                lines.append(f"    self._arg_enum({p.name}.value);");
            }
        }
        lines.append("    return idx;");
        lines.append("}");
        lines.append("");
    }
    return "\n".join(lines);
}


def apply_decl_block(src: str, block: str) -> str {
    a = src.index(DECL_BEGIN);
    b = src.index(DECL_END) + len(DECL_END);
    return src[:a] + block + src[b:];
}


def _format_generated(content: str, basename: str) -> str {
    import tempfile;
    import warnings;
    import from pathlib { Path }
    import jaclang.cli.commands.analysis;
    with tempfile.TemporaryDirectory() as fmt_dir {
        fpath = Path(fmt_dir) / basename;
        fpath.write_text(content, encoding="utf-8");
        try {
            prev: str = "";
            for _ in range(4) {
                jaclang.cli.commands.analysis.format(
                    [str(fpath)], False, True, False, False
                );
                current = fpath.read_text(encoding="utf-8");
                if current == prev {
                    break;
                }
                prev = current;
            }
        } except Exception as exc {
            warnings.warn(
                "jac fmt failed during arena generation; using unformatted "
                f"output: {exc}",
                stacklevel=2
            );
        }
        return fpath.read_text(encoding="utf-8");
    }
}


def _artifacts(schema: list) -> list {
    return [
        (SCHEMA_OUT, _format_generated(schema_module_src(schema), "arena_schema.jac")),
        (SPECS_OUT, _format_generated(specs_module_src(schema), "arena_specs.jac")),
        (
            BUILDERS_ANNEX,
            _format_generated(builders_annex_src(schema), "builders.impl.jac")
        ),

    ];
}


def write_all -> list {
    import os;
    schema = collect_schema();
    msgs: list = [];
    for entry in _artifacts(schema) {
        (rel, content) = entry;
        out = abs_path(rel);
        os.makedirs(os.path.dirname(out), exist_ok=True);
        with open(out, "w", encoding="utf-8") as f {
            f.write(content);
        }
        msgs.append(f"Generated {out} ({len(content)} bytes)");
    }
    ar = abs_path(ARENA_SRC);
    src = open(ar, encoding="utf-8").read();
    new_src = _format_generated(
        apply_decl_block(src, builder_decls_block(schema)), "arena.jac"
    );
    if new_src != src {
        with open(ar, "w", encoding="utf-8") as f {
            f.write(new_src);
        }
        msgs.append(f"Updated builder decls in {ar}");
    }
    msgs.append(f"{len(schema)} kinds");
    return msgs;
}


def verify_all -> list {
    schema = collect_schema();
    stale: list = [];
    for entry in _artifacts(schema) {
        (rel, content) = entry;
        current = "";
        try {
            current = open(abs_path(rel), encoding="utf-8").read();
        } except Exception {
            ;
        }
        if current != content {
            stale.append(rel);
        }
    }
    ar_src = open(abs_path(ARENA_SRC), encoding="utf-8").read();
    expected = _format_generated(
        apply_decl_block(ar_src, builder_decls_block(schema)), "arena.jac"
    );
    if expected != ar_src {
        stale.append(ARENA_SRC);
    }
    return stale;
}
