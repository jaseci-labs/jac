import re;
import sys;

import from dataclasses { fields as dc_fields }
import from enum { EnumMeta }
import from pathlib { Path }

glob _MASK_MEMO: dict[str, tuple[dict[str, set[str]], dict[str, str]]] = {};

obj MaterializeProfile {
    has class_modules: list[str],
        enum_modules: list[str],
        envelope_modules: list[str],
        chain_base_module: str,
        chain_base_class: str,
        mask_sources: list[str],
        mask_corpus: str,
        parse_entry: str,
        parse_entry_module: str,
        diag_class: str,
        comment_class: str;
}

glob _UNITREE_MASK_CORPUS_LINES: tuple[str, ...] = (
         "import os;",
         "glob G: int = 42, H: (str | None) = None;",
         "enum Hue { RED = 1, GREEN = 2 }",
         "node Spot { has label: str = ''; }",
         "edge Road { has miles: int = 0; }",
         "walker Tour {",
         "    can step with Spot entry;",
         "}",
         "impl Tour.step with Spot entry {",
         "    visit [-->];",
         "}",
         "obj Box { has x: int = 0, y: list[int] = [], z: dict[str, int] = {}; ",
         "    def m(p: int = 1) -> int; }",
         "impl Box.m(p: int = 1) -> int {",
         "    if p > 1 and p < 9 or not p { for i in range(p) { self.x += i; } }",
         "    elif p == 0 { while self.x { self.x -= 1; } }",
         "    else { try { raise ValueError('v'); } except ValueError as e { } }",
         "    return self.x if self.x else -1;",
         "}",
         "def pick(v: any) -> int {",
         "    match v {",
         "        case [1, 2]: return 1;",
         "        case {'k': 2}: return 2;",
         "        case _: return 0;",
         "    }",
         "}",
         "def:pub View(t: str) -> JsxElement {",
         "    return <div id='a'>{t}</div>;",
         "}",
         "async def later -> None {}",
         "enum Tone: int {",
         "    LOW = 3,",
         "    HIGH = 4,",
         "}",
         "test box_holds { assert Box(x=1).m() >= -1; }",
         "with entry { b = Box(x=5); print(f'v={b.m(2)}', {'s': [1, 2.5, True, None]}); }",

     );

def unitree_profile -> MaterializeProfile {
    nl = chr(10);
    return MaterializeProfile(
        class_modules=["jaclang.jac0core.unitree", "jaclang.jac0core.srcloc"],
        enum_modules=[
            "jaclang.jac0core.unitree",
            "jaclang.jac0core.constant",
            "jaclang.jac0core.srcloc"
        ],
        envelope_modules=["jaclang.jac0core.parser.tokens"],
        chain_base_module="jaclang.jac0core.unitree",
        chain_base_class="UniNode",
        mask_sources=["jac0core/unitree.jac", "jac0core/parser/impl/parser.impl.jac"],
        mask_corpus=nl.join(list(_UNITREE_MASK_CORPUS_LINES)),
        parse_entry="parse_program",
        parse_entry_module="jaclang.jac0core.parser.parser",
        diag_class="SrcDiag",
        comment_class="CommentData"
    );
}

def _materialize_mask(
    pkg_path: Path, profile: MaterializeProfile
) -> tuple[dict[str, set[str]], dict[str, str]] {
    memo_key = str(pkg_path);
    cached = _MASK_MEMO.get(memo_key);
    if cached is not None {
        return cached;
    }
    import from jaclang.jac0core.parser.lexer { tokenize_full }
    import from jaclang.jac0core.parser.parser { Parser }
    sources: list[tuple[str, str]] = [(profile.mask_corpus, "__mask_corpus__.jac", )];
    for rel in profile.mask_sources {
        src_file = pkg_path / rel;
        if src_file.is_file() {
            sources.append((src_file.read_text(encoding="utf-8"), rel, ));
        }
    }
    observed: dict[str, set[str]] = {};
    mangle: dict[str, str] = {};
    for (src, path) in sources {
        (tokens, _c, _ld, _le) = tokenize_full(src, path);
        parser = Parser(tokens=tokens, file_path=path, source_code=src);
        mod = parser.parse();
        stack = [mod];
        seen: set[int] = set();
        while stack {
            objn = stack.pop();
            if id(objn) in seen {
                continue;
            }
            seen.add(id(objn));
            d = objn?.__dict__;
            if d is None {
                continue;
            }
            cname = type(objn).__name__;
            keys = observed.get(cname);
            if keys is None {
                keys = set();
                observed[cname] = keys;
            }
            for k in d.keys() {
                keys.add(k);
                if k.startswith("_") and "__" in k[1:] {
                    `priv = k[k.index("__", 1):];
                    mangle[`priv] = k;
                }
            }
            for v in d.values() {
                if hasattr(v, "__dict__") and hasattr(v, "kid") {
                    stack.append(v);
                } elif type(v).__name__ == "CodeLocInfo" {
                    stack.append(v);
                } elif isinstance(v, list) {
                    for it in v {
                        if hasattr(it, "__dict__") and hasattr(it, "kid") {
                            stack.append(it);
                        }
                    }
                }
            }
        }
    }
    result = (observed, mangle);
    _MASK_MEMO[memo_key] = result;
    return result;
}

glob _SCALARS: tuple[str, ...] = ("int", "bool", "float", "str");

def _import_block(mod_name: str, by_module: dict[str, list[str]]) -> str {
    nl = chr(10);
    names = sorted(set(by_module.get(mod_name, [])));
    if not names {
        return "";
    }
    joined = ("," + nl + "    ").join(names);
    return f"import from {mod_name} {{" + nl + "    " + joined + nl + "}";
}

def _norm(t: str) -> str {
    return t.replace("Sequence[", "list[").strip("() ");
}

def _base_of(t: str) -> str {
    m = re.`match(r"^(\w+)", t);
    return m.group(1) if m else "";
}

def _inner(t: str) -> str {
    m = re.`match(r"^\w+\[(.*)\]$", t);
    return m.group(1) if m else "";
}

def _split_union(s: str) -> list[str] {
    out: list[str] = [];
    depth = 0;
    cur = "";
    for ch in s {
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
    return [
        a.strip("() ")
        for a in out
        if a.strip("() ")
    ];
}

def _split_kv(kv: str) -> tuple[str, str] {
    depth = 0;
    cur = "";
    parts: list[str] = [];
    for ch in kv {
        if ch == "[" {
            depth += 1;
        } elif ch == "]" {
            depth -= 1;
        }
        if ch == "," and depth == 0 {
            parts.append(cur.strip());
            cur = "";
        } else {
            cur += ch;
        }
    }
    parts.append(cur.strip());
    while len(parts) < 2 {
        parts.append("");
    }
    return (_norm(parts[0]), _norm(parts[1]));
}

obj _MatGen {
    has ns: dict[str, type] = {},
        enum_ns: dict[str, EnumMeta] = {},
        chain_base: any = None,
        envelope: set[str] = set(),
        observed: dict[str, set[str]] = {},
        mangle: dict[str, str] = {},
        foreign: dict[tuple[str, str], bool] = {},
        layout_fields: dict[str, list[str]] = {},
        struct_names: set[str] = set(),
        keys: list[str] = [],
        key_idx: dict[str, int] = {},
        enum_sites: list[str] = [],
        warnings: list[str] = [];

    def is_chain(name: str) -> bool {
        cls = self.ns.get(name);
        return (
            cls is not None
            and self.chain_base is not None
            and issubclass(cls, self.chain_base)
        );
    }

    def kidx(name: str) -> int {
        if name not in self.key_idx {
            self.key_idx[name] = len(self.keys);
            self.keys.append(name);
        }
        return self.key_idx[name];
    }

    def register_enum(en: str) {
        if en not in self.enum_sites {
            self.enum_sites.append(en);
        }
    }

    def warn(msg: str) {
        if msg not in self.warnings {
            self.warnings.append(msg);
        }
    }

    def scalar_expr(expr: str, a: str) -> str {
        a = a.strip();
        if a == "int" {
            return f"PyLong_FromLongLong({expr})";
        }
        if a == "bool" {
            return f"PyBool_FromLong(1 if {expr} else 0)";
        }
        if a == "float" {
            return f"PyFloat_FromDouble({expr})";
        }
        if a == "str" {
            return f"_py_str({expr})";
        }
        return "_py_none()";
    }

    def elem_materializable(elem: str) -> bool {
        elem = _norm(elem);
        eb = _base_of(elem);
        return elem in _SCALARS or eb in self.ns or eb == "SubTag";
    }

    def emit_list(
        v: str, expr: str, elem: str, out: list[str], ind: str, uid: str
    ) -> bool {
        elem = _norm(elem);
        eb = _base_of(elem);
        u = uid + "l";
        if not self.elem_materializable(elem) {
            self.warn(f"unhandled list element {repr(elem)} -> field erased to None");
            out.append(ind + f"{v} = _py_none();");
            return False;
        }
        out.append(ind + f"{v} = PyList_New(len({expr}));");
        out.append(ind + f"li_{u} = 0;");
        out.append(ind + f"for it_{u} in {expr} {{");
        if elem in _SCALARS {
            out.append(ind + f"    e_{u} = " + self.scalar_expr(f"it_{u}", elem) + ";");
        } elif eb in self.ns and not self.is_chain(eb) {
            out.append(ind + f"    e_{u} = _emit_{eb}(it_{u});");
        } else {
            out.append(ind + f"    e_{u} = _emit_node(it_{u});");
        }
        out.append(ind + f"    PyList_SetItem({v}, li_{u}, e_{u});");
        out.append(ind + f"    li_{u} += 1;");
        out.append(ind + "}");
        return True;
    }

    def key_expr(expr: str, kt: str) -> (str | None) {
        kt = _norm(kt);
        kb = _base_of(kt);
        if kt in _SCALARS {
            return self.scalar_expr(expr, kt);
        }
        if kb in self.enum_ns {
            self.register_enum(kb);
            return f"_enum_{kb}({expr})";
        }
        if kb in self.ns {
            if self.is_chain(kb) {
                return f"_emit_node({expr})";
            }
            return f"_emit_{kb}({expr})";
        }
        return None;
    }

    def emit_dict(
        v: str, expr: str, kv: str, out: list[str], ind: str, uid: str
    ) -> bool {
        (kt, vt) = _split_kv(kv);
        u = uid + "d";
        kexpr = self.key_expr(f"dk_{u}", kt);
        if kexpr is None {
            self.warn(
                f"dict key type {repr(kt)} has no materializer -> field erased to None"
            );
            out.append(ind + f"{v} = _py_none();");
            return False;
        }
        out.append(ind + f"{v} = PyDict_New();");
        out.append(ind + f"for (dk_{u}, dv_{u}) in {expr}.items() {{");
        out.append(ind + f"    kh_{u} = {kexpr};");
        vb = _base_of(vt);
        if vt in _SCALARS {
            out.append(ind + f"    vh_{u} = " + self.scalar_expr(f"dv_{u}", vt) + ";");
        } elif vb == "list" {
            self.emit_list(f"vh_{u}", f"dv_{u}", _inner(vt), out, ind + "    ", u);
        } elif vb == "set" {
            _sv = _norm(_inner(vt));
            if _sv in _SCALARS {
                out.append(ind + f"    vh_{u} = PySet_New(0);");
                out.append(ind + f"    for sv_{u} in dv_{u} {{");
                out.append(
                    ind + f"        se_{u} = " + self.scalar_expr(f"sv_{u}", _sv) + ";"
                );
                out.append(ind + f"        PySet_Add(vh_{u}, se_{u});");
                out.append(ind + f"        Py_DecRef(se_{u});");
                out.append(ind + "    }");
            } else {
                out.append(ind + f"    vh_{u} = _py_none();");
            }
        } elif vb in self.ns and not self.is_chain(vb) {
            out.append(ind + f"    vh_{u} = _emit_{vb}(dv_{u});");
        } else {
            out.append(ind + f"    vh_{u} = _emit_node(dv_{u});");
        }
        out.append(ind + f"    PyDict_SetItem({v}, kh_{u}, vh_{u});");
        out.append(ind + f"    Py_DecRef(kh_{u});");
        out.append(ind + f"    Py_DecRef(vh_{u});");
        out.append(ind + "}");
        return True;
    }

    def emit_value(expr: str, ann: str, out: list[str], ind: str, uid: str) -> str {
        v = f"v_{uid}";
        ann = _norm(ann);
        arms = _split_union(ann);
        has_none = "None" in arms;
        arms = [
            a
            for a in arms
            if a != "None"
        ];
        pre = ind;
        if not arms {
            out.append(pre + f"{v} = _py_none();");
            return v;
        }
        buf: list[str] = [];
        fv = f"fv_{uid}";
        buf.append(pre + f"{fv} = {expr};");
        expr = fv;
        if has_none {
            buf.append(pre + f"if {expr} is None {{");
            buf.append(pre + f"    {v} = _py_none();");
            buf.append(pre + "} else {");
            pre = ind + "    ";
        }
        emitted = True;
        if len(arms) == 1 {
            a = arms[0];
            ab = _base_of(a);
            if a in _SCALARS {
                buf.append(pre + f"{v} = " + self.scalar_expr(expr, a) + ";");
            } elif ab == "list" {
                emitted = self.emit_list(v, expr, _inner(a), buf, pre, uid);
            } elif ab == "dict" {
                emitted = self.emit_dict(v, expr, _inner(a), buf, pre, uid);
            } elif ab == "set" {
                _se = _norm(_inner(a));
                if _se in _SCALARS {
                    buf.append(pre + f"{v} = PySet_New(0);");
                    buf.append(pre + f"for it_{uid}s in {expr} {{");
                    buf.append(
                        pre
                            + f"    e_{uid}s = "
                            + self.scalar_expr(f"it_{uid}s", _se)
                            + ";"
                    );
                    buf.append(pre + f"    PySet_Add({v}, e_{uid}s);");
                    buf.append(pre + f"    Py_DecRef(e_{uid}s);");
                    buf.append(pre + "}");
                } else {
                    self.warn(f"unhandled set element {repr(ann)} -> None");
                    emitted = False;
                }
            } elif ab in self.enum_ns {
                self.register_enum(ab);
                buf.append(pre + f"{v} = _enum_{ab}({expr});");
            } elif ab == "SubTag" or (ab in self.ns and self.is_chain(ab)) {
                buf.append(pre + f"{v} = _emit_node({expr});");
            } elif ab in self.ns {
                buf.append(pre + f"{v} = _emit_{ab}({expr});");
            } else {
                self.warn(f"unhandled annotation {repr(ann)} -> None");
                emitted = False;
            }
        } else {
            list_arms = [
                a
                for a in arms
                if _norm(a).startswith("list[")
                    and self.elem_materializable(_inner(_norm(a)))
            ];
            cls_arms: list[str] = [];
            for a in arms {
                ab = _base_of(_norm(a));
                if ab != "list" and ab in self.ns {
                    cls_arms.append(ab);
                }
            }
            first_kw = "if";
            if list_arms {
                la_elem = _inner(_norm(list_arms[0]));
                la_base = _base_of(la_elem) if la_elem else "UniNode";
                buf.append(pre + f"if isinstance({expr}, list) {{");
                buf.append(pre + f"    tl_{uid}: list[{la_base}] = {expr};");
                self.emit_list(v, f"tl_{uid}", la_elem, buf, pre + "    ", uid);
                first_kw = "} elif";
            }
            for ab in cls_arms {
                buf.append(pre + f"{first_kw} isinstance({expr}, {ab}) {{");
                buf.append(pre + f"    {v} = _emit_node({expr});");
                first_kw = "} elif";
            }
            if first_kw == "if" {
                emitted = False;
            } else {
                buf.append(pre + "} else {");
                buf.append(pre + f"    {v} = _py_none();");
                buf.append(pre + "}");
            }
        }
        if has_none {
            buf.append(ind + "}");
        }
        if not emitted {
            out.append(ind + f"{v} = _py_none();");
            return v;
        }
        out.extend(buf);
        return v;
    }

    def class_fields(sn: str) -> list[tuple[str, str, str | None]] {
        cls = self.ns[sn];
        inv_mangle = {v: k for (k, v) in self.mangle.items()};
        ann_by_name: dict[str, str] = {};
        for f in dc_fields(cls) {
            base = inv_mangle.get(f.name, f.name);
            ann_by_name[base] = str(f.type);
        }
        if sn in self.envelope {
            return [(f.name, f.name, str(f.type), ) for f in dc_fields(cls)];
        }
        keep = self.observed.get(sn);
        out: list[tuple[str, str, str | None]] = [];
        for lf in self.layout_fields.get(sn, []) {
            dict_key = self.mangle.get(lf, lf);
            if keep is not None and dict_key not in keep {
                continue;
            }
            out.append((lf, dict_key, ann_by_name.get(lf), ));
        }
        return out;
    }
}

glob _HEADER_LINES: tuple[str, ...] = (
         '\'\'\'GENERATED at seal time by jaclang/utils/gen_native_materialize.jac.',
         '',
         'The seal root for the native parser artifact: importing the parser pulls',
         'the parse entry (and the whole schema closure) into this native unit, and',
         'the emitters below rebuild everything that crosses the boundary as real',
         'CPython objects through libpython externs resolved from the host process',
         '(ELF lazy PLT / Mach-O flat lookup). Bound with the GIL HELD (PYFUNCTYPE);',
         'see jac0core/parser/materialize.jac. Erased native slots stay None here',
         'and are reconstructed by materialize_fixups. mat_merge_probe runs the',
         'sealed annex merge (annex_weave.merge_annex_into, the implementation',
         'JacAnnexPass._merge_annex wraps) natively over two native parses and',
         'materializes the woven module: the native-execution canary the',
         'pass-serving binder verifies at bind time.',
         '\'\'\'',
         '@UNI_IMPORT@',
         (
             'import from jaclang.jac0core.passes.prefix_drive {'
             ' PrefixAlertRow, run_prefix_passes }'
         ),
         '@ENTRY_IMPORT@',
         'import from jaclang.jac0core.passes.annex_weave { merge_annex_into }',
         '@CONST_IMPORT@',
         '@SRC_IMPORT@',
         '@ENV_IMPORT@',
         '',
         'import from python {',
         '    def PyLong_FromLongLong(v: int) -> int;',
         '    def PyBool_FromLong(v: int) -> int;',
         '    def PyFloat_FromDouble(v: float) -> int;',
         '    def PyUnicode_FromStringAndSize(s: str, n: int) -> int;',
         '    def PyList_New(n: int) -> int;',
         '    def PyList_SetItem(l: int, i: int, v: int) -> i32;',
         '    def PyDict_New() -> int;',
         '    def PyDict_SetItem(d: int, k: int, v: int) -> i32;',
         '    def PySet_New(i: int) -> int;',
         '    def PySet_Add(s: int, v: int) -> i32;',
         '    def PyObject_CallOneArg(f: int, a: int) -> int;',
         '    def PyObject_GenericGetDict(o: int, ctx: int) -> int;',
         '    def Py_IncRef(o: int) -> None;',
         '    def Py_DecRef(o: int) -> None;',
         '    def Py_GetConstant(cid: int) -> int;',
         '}',
         '',
         'glob _mat_classes: list[int] = [],',
         '     _mat_news: list[int] = [],',
         '     _mat_keys: list[int] = [],',
         '     _mat_enums: list[int] = [],',
         '     _mat_memo: dict[int, int] = {};',
         '',
         'def _py_none -> int {',
         '    return Py_GetConstant(0);',
         '}',
         '',
         'def _py_str(s: str) -> int {',
         '    return PyUnicode_FromStringAndSize(s, len(s));',
         '}',
         '',
         'def mat_reset(ncls: int, nkeys: int, nenums: int) -> None {',
         '    _mat_classes.clear();',
         '    _mat_news.clear();',
         '    _mat_keys.clear();',
         '    _mat_enums.clear();',
         '    i = 0;',
         '    while i < ncls {',
         '        _mat_classes.append(0);',
         '        _mat_news.append(0);',
         '        i += 1;',
         '    }',
         '    i = 0;',
         '    while i < nkeys {',
         '        _mat_keys.append(0);',
         '        i += 1;',
         '    }',
         '    i = 0;',
         '    while i < nenums {',
         '        _mat_enums.append(0);',
         '        i += 1;',
         '    }',
         '}',
         '',
         'def mat_set_class(i: int, cls_h: int, new_h: int) -> None {',
         '    _mat_classes[i] = cls_h;',
         '    _mat_news[i] = new_h;',
         '}',
         '',
         'def mat_set_key(i: int, key_h: int) -> None {',
         '    _mat_keys[i] = key_h;',
         '}',
         '',
         'def mat_set_enum(i: int, member_h: int) -> None {',
         '    _mat_enums[i] = member_h;',
         '}',
         '',
         'def _mat_flush -> None {',
         '    for (_addr, h) in _mat_memo.items() {',
         '        Py_DecRef(h);',
         '    }',
         '    _mat_memo.clear();',
         '}',
         '',
         'def mat_materialize(mod: @CHAIN_BASE@) -> int {',
         '    root_h = _emit_node(mod);',
         '    return root_h;',
         '}',

     ),
     _CROSSING_LINES: tuple[str, ...] = (
         'def _emit_diag_list(items: list[@DIAG@]) -> int {',
         '@DIAG_LIST_BODY@',
         '    return v_dl;',
         '}',
         '',
         'def _emit_comment_list(items: list[@COMMENT@]) -> int {',
         '@COMMENT_LIST_BODY@',
         '    return v_cl;',
         '}',
         '',
         'def mat_parse(src: str, path: str) -> int {',
         '    (mod, p_errs, p_diags, comments, lex_diags, lex_errs) = @ENTRY@(',
         '        src, path',
         '    );',
         '    out = PyList_New(6);',
         '    PyList_SetItem(out, 0, mat_materialize(mod));',
         '    PyList_SetItem(out, 1, PyLong_FromLongLong(p_errs));',
         '    PyList_SetItem(out, 2, _emit_diag_list(p_diags));',
         '    PyList_SetItem(out, 3, _emit_comment_list(comments));',
         '    PyList_SetItem(out, 4, _emit_diag_list(lex_diags));',
         '    PyList_SetItem(out, 5, PyLong_FromLongLong(lex_errs));',
         '    _mat_flush();',
         '    return out;',
         '}',
         '',
         'def mat_parse_diags(src: str, path: str) -> int {',
         '    (mod, p_errs, p_diags, comments, lex_diags, lex_errs) = @ENTRY@(',
         '        src, path',
         '    );',
         '    out = PyList_New(4);',
         '    PyList_SetItem(out, 0, PyLong_FromLongLong(p_errs));',
         '    PyList_SetItem(out, 1, PyLong_FromLongLong(lex_errs));',
         '    PyList_SetItem(out, 2, _emit_diag_list(p_diags));',
         '    PyList_SetItem(out, 3, _emit_diag_list(lex_diags));',
         '    _mat_flush();',
         '    return out;',
         '}',
         '',
         'def mat_merge_probe(',
         '    src: str, path: str, annex_src: str, annex_path: str',
         ') -> int {',
         '    (mod, p_errs, _pd, _cm, _ld, lex_errs) = @ENTRY@(src, path);',
         '    (amod, a_errs, _apd, _acm, _ald, a_lex_errs) = @ENTRY@(',
         '        annex_src, annex_path',
         '    );',
         '    merge_annex_into(mod, amod);',
         '    out = PyList_New(3);',
         '    PyList_SetItem(out, 0, mat_materialize(mod));',
         '    PyList_SetItem(out, 1, PyLong_FromLongLong(p_errs + lex_errs));',
         '    PyList_SetItem(out, 2, PyLong_FromLongLong(a_errs + a_lex_errs));',
         '    _mat_flush();',
         '    return out;',
         '}',
         '',
         'def _emit_alert_rows(rows: list[PrefixAlertRow]) -> int {',
         '    v_rl = PyList_New(len(rows));',
         '    ri = 0;',
         '    for r in rows {',
         '        v_t = PyList_New(9);',
         '        PyList_SetItem(v_t, 0, PyLong_FromLongLong(r.severity));',
         '        PyList_SetItem(v_t, 1, _py_str(r.code));',
         '        PyList_SetItem(v_t, 2, _py_str(r.msg));',
         '        PyList_SetItem(v_t, 3, _py_str(r.help_text));',
         '        PyList_SetItem(v_t, 4, PyLong_FromLongLong(r.first_line));',
         '        PyList_SetItem(v_t, 5, PyLong_FromLongLong(r.col_start));',
         '        PyList_SetItem(v_t, 6, PyLong_FromLongLong(r.pos_start));',
         '        PyList_SetItem(v_t, 7, PyLong_FromLongLong(r.pos_end));',
         '        PyList_SetItem(v_t, 8, PyLong_FromLongLong(r.pass_idx));',
         '        PyList_SetItem(v_rl, ri, v_t);',
         '        ri += 1;',
         '    }',
         '    return v_rl;',
         '}',
         '',
         'def mat_parse_and_run_prefix(',
         '    src: str,',
         '    path: str,',
         '    claimed_n: int,',
         '    project_root: str,',
         '    has_project_root: int,',
         '    access_enforced: int',
         ') -> int {',
         '    (mod, p_errs, p_diags, comments, lex_diags, lex_errs) = @ENTRY@(',
         '        src, path',
         '    );',
         '    executed = 0;',
         '    clause = "";',
         '    detail = "";',
         '    rows_h = PyList_New(0);',
         '    if (p_errs + lex_errs) == 0 {',
         '        if has_project_root != 0 {',
         '            mod.jac_project_root = project_root;',
         '        }',
         '        mod.access_enforced = access_enforced != 0;',
         '        run = run_prefix_passes(mod, claimed_n);',
         '        executed = run.executed;',
         '        clause = run.clause;',
         '        detail = run.detail;',
         '        rows_h = _emit_alert_rows(run.rows);',
         '    }',
         '    out = PyList_New(10);',
         '    PyList_SetItem(out, 0, mat_materialize(mod));',
         '    PyList_SetItem(out, 1, PyLong_FromLongLong(p_errs));',
         '    PyList_SetItem(out, 2, _emit_diag_list(p_diags));',
         '    PyList_SetItem(out, 3, _emit_comment_list(comments));',
         '    PyList_SetItem(out, 4, _emit_diag_list(lex_diags));',
         '    PyList_SetItem(out, 5, PyLong_FromLongLong(lex_errs));',
         '    PyList_SetItem(out, 6, PyLong_FromLongLong(executed));',
         '    PyList_SetItem(out, 7, _py_str(clause));',
         '    PyList_SetItem(out, 8, _py_str(detail));',
         '    PyList_SetItem(out, 9, rows_h);',
         '    _mat_flush();',
         '    return out;',
         '}',

     );

def generate(
    layout: dict[str, any],
    out_jac: Path,
    waivers: tuple[str, ...],
    profile: (MaterializeProfile | None) = None
) -> dict[str, list[str] | list[tuple[str, list[str]]]] {
    import importlib;
    import jaclang;

    prof: MaterializeProfile = profile if profile is not None else unitree_profile();
    class_mods = [importlib.import_module(m) for m in prof.class_modules];
    enum_mods = [importlib.import_module(m) for m in prof.enum_modules];
    env_mods = [importlib.import_module(m) for m in prof.envelope_modules];
    chain_mod = importlib.import_module(prof.chain_base_module);

    g = _MatGen();
    g.chain_base = getattr(chain_mod, prof.chain_base_class);
    for mod in class_mods {
        for (k, v) in vars(mod).items() {
            if isinstance(v, type) and v.__module__ == mod.__name__ {
                g.ns.setdefault(k, v);
            }
        }
    }
    for cname in (prof.diag_class, prof.comment_class) {
        for mod in env_mods {
            cls = getattr(mod, cname, None);
            if cls is not None {
                g.ns.setdefault(cname, cls);
                g.envelope.add(cname);
                for f in dc_fields(cls) {
                    nested = _base_of(_norm(str(f.type)));
                    ncls = getattr(mod, nested, None);
                    if nested not in _SCALARS and ncls is not None {
                        g.ns.setdefault(nested, ncls);
                        g.envelope.add(nested);
                    }
                }
                break;
            }
        }
    }
    for mod in enum_mods {
        for (k, v) in vars(mod).items() {
            if isinstance(v, EnumMeta) {
                g.enum_ns.setdefault(k, v);
            }
        }
    }
    pkg_path = Path(str(jaclang.__file__)).parent;
    (g.observed, g.mangle) = _materialize_mask(pkg_path, prof);

    structs = layout["structs"];
    for (sn, sd) in structs.items() {
        flds: list[dict[str, any]] = list(sd["fields"]);
        for f in flds {
            g.foreign[(sn, f["name"], )] = bool(f.get("foreign"));
        }
        g.layout_fields[sn] = [f["name"] for f in flds];
    }
    g.struct_names = set(structs.keys());

    chain_classes: list[str] = [];
    direct_classes: list[str] = [];
    for sn in structs {
        if sn not in g.ns {
            continue;
        }
        if g.is_chain(sn) {
            chain_classes.append(sn);
        } else {
            direct_classes.append(sn);
        }
    }
    for sn in sorted(g.envelope) {
        if sn not in direct_classes {
            direct_classes.append(sn);
        }
    }

    freq = {"Name": 0, "Token": 1, "String": 2, "Int": 3, "Semi": 4};
    deco = [(-len(g.ns[n].__mro__), freq.get(n, 50), n, ) for n in chain_classes];
    deco.sort();
    chain_classes = [t[2] for t in deco];
    all_emit = chain_classes + sorted(direct_classes);

    emit_fns: list[str] = [];
    for (ci, sn) in enumerate(all_emit) {
        lines: list[str] = [];
        lines.append(f"def _emit_{sn}(nd: {sn}) -> int {{");
        lines.append("    h = _mat_memo.get(id(nd), 0);");
        lines.append("    if h != 0 {");
        lines.append("        Py_IncRef(h);");
        lines.append("        return h;");
        lines.append("    }");
        lines.append(
            f"    obj_h = PyObject_CallOneArg(_mat_news[{ci}], _mat_classes[{ci}]);"
        );
        lines.append("    if obj_h == 0 {");
        lines.append("        return 0;");
        lines.append("    }");
        lines.append("    _mat_memo[id(nd)] = obj_h;");
        lines.append("    d_h = PyObject_GenericGetDict(obj_h, 0);");
        lines.append("    if d_h == 0 {");
        lines.append("        return 0;");
        lines.append("    }");
        for (fi, fld) in enumerate(g.class_fields(sn)) {
            (lf, dict_key, ann) = fld;
            ki = g.kidx(dict_key);
            uid = f"{ci}_{fi}";
            lines.append(f"    # {dict_key}: {ann}");
            if (sn not in g.envelope and g.foreign.get((sn, lf, ))) or ann is None {
                vname = f"v_{uid}";
                lines.append(f"    {vname} = _py_none();");
            } elif sn == "SubTag" and lf == "tag" {
                vname = f"v_{uid}";
                lines.append(f"    {vname} = _emit_node(nd.kid[len(nd.kid) - 1]);");
            } else {
                body: list[str] = [];
                vname = g.emit_value(f"nd.{lf}", ann, body, "    ", uid);
                lines.extend(body);
            }
            lines.append(f"    PyDict_SetItem(d_h, _mat_keys[{ki}], {vname});");
            lines.append(f"    Py_DecRef({vname});");
        }
        lines.append("    Py_DecRef(d_h);");
        lines.append("    Py_IncRef(obj_h);");
        lines.append("    return obj_h;");
        lines.append("}");
        emit_fns.append("\n".join(lines));
    }

    chain: list[str] = [f"def _emit_node(nd: {prof.chain_base_class}) -> int {{"];
    first = True;
    for sn in chain_classes {
        kw = "if" if first else "} elif";
        chain.append(f"    {kw} isinstance(nd, {sn}) {{");
        chain.append(f"        return _emit_{sn}(nd);");
        first = False;
    }
    chain.append("    }");
    chain.append("    return _py_none();");
    chain.append("}");

    enum_fns: list[str] = [];
    enum_members_manifest: list[tuple[str, list[str]]] = [];
    base = 0;
    for en in g.enum_sites {
        ecls = g.enum_ns[en];
        members = [m for m in ecls.__members__];
        enum_members_manifest.append((en, members, ));
        fl: list[str] = [f"def _enum_{en}(v: {en}) -> int {{"];
        for (mi, mn) in enumerate(members) {
            kw = "if" if mi == 0 else "} elif";
            fl.append(f"    {kw} v == {en}.{mn} {{");
            fl.append(f"        h = _mat_enums[{base + mi}];");
            fl.append("        Py_IncRef(h);");
            fl.append("        return h;");
        }
        fl.append("    }");
        fl.append("    return PyLong_FromLongLong(0);");
        fl.append("}");
        enum_fns.append("\n".join(fl));
        base += len(members);
    }

    nl = chr(10);
    dl_body: list[str] = [];
    g.emit_list("v_dl", "items", prof.diag_class, dl_body, "    ", "dl");
    cl_body: list[str] = [];
    g.emit_list("v_cl", "items", prof.comment_class, cl_body, "    ", "cl");
    crossing: str = nl.join(list(_CROSSING_LINES));
    crossing = crossing.replace("@DIAG_LIST_BODY@", nl.join(dl_body));
    crossing = crossing.replace("@COMMENT_LIST_BODY@", nl.join(cl_body));
    crossing = crossing.replace("@DIAG@", prof.diag_class);
    crossing = crossing.replace("@COMMENT@", prof.comment_class);
    crossing = crossing.replace("@ENTRY@", prof.parse_entry);

    by_module: dict[str, list[str]] = {};
    for sn in all_emit {
        owner = g.ns[sn].__module__;
        by_module.setdefault(owner, []).append(sn);
    }
    chain_owner = g.chain_base.__module__;
    by_module.setdefault(chain_owner, []);
    if prof.chain_base_class not in by_module[chain_owner] {
        by_module[chain_owner].append(prof.chain_base_class);
    }
    for en in g.enum_sites {
        owner = g.enum_ns[en].__module__;
        by_module.setdefault(owner, []);
        if en not in by_module[owner] {
            by_module[owner].append(en);
        }
    }

    header: str = nl.join(list(_HEADER_LINES));
    header = header.replace(
        "@ENTRY_IMPORT@",
        f"import from {prof.parse_entry_module} {{ {prof.parse_entry} }}"
    );
    header = header.replace(
        "@UNI_IMPORT@", _import_block(prof.chain_base_module, by_module)
    );
    const_mods = [
        m
        for m in prof.enum_modules
        if m not in prof.class_modules
    ];
    header = header.replace(
        "@CONST_IMPORT@",
        nl.join(
            [
                _import_block(m, by_module)
                for m in const_mods
                if _import_block(m, by_module)
            ]
        )
    );
    src_mods = [
        m
        for m in prof.class_modules
        if m != prof.chain_base_module
    ];
    header = header.replace(
        "@SRC_IMPORT@",
        nl.join(
            [
                _import_block(m, by_module)
                for m in src_mods
                if _import_block(m, by_module)
            ]
        )
    );
    header = header.replace(
        "@ENV_IMPORT@",
        nl.join(
            [
                _import_block(m, by_module)
                for m in prof.envelope_modules
                if _import_block(m, by_module)
            ]
        )
    );
    header = header.replace("@CHAIN_BASE@", prof.chain_base_class);

    sep = nl + nl;
    parts = [header, sep.join(enum_fns), sep.join(emit_fns), nl.join(chain), crossing];
    out_jac.write_text(
        sep.join(
            [
                p
                for p in parts
                if p
            ]
        )
            + nl,
        encoding="utf-8"
    );

    waived_attrs = {str(w).split("::")[-1].split(".")[1] for w in waivers};
    emitted_reads = set(re.findall(r"nd\.(\w+)", sep.join(emit_fns)));
    collisions = (emitted_reads - {"kid"}) & waived_attrs;
    assert not collisions , f"emitters read waived accessors: {collisions}";

    return {
        "class_names": all_emit,
        "key_names": g.keys,
        "enums": enum_members_manifest,
        "warnings": g.warnings
    };
}
