import ctypes;
import json;
import os;
import sys;
import from ctypes { c_char_p, c_double, c_int64, c_void_p, cast, py_object }
import from jaclang.runtime.osp_tag { stable_osp_tag }
import type from jaclang.compiler.passes.transform { PassResult }

glob CODE_INT: int = 1,
     CODE_BOOL: int = 2,
     CODE_STR: int = 3,
     CODE_ENUM: int = 4,
     CODE_OPTREF: int = 5,
     CODE_OBJ: int = 6,
     CODE_NATLIST: int = 7,
     CODE_UNION: int = 8,
     CODE_OPTENUM: int = 9,
     CODE_NATDICT: int = 10;

glob CLASS_MODULES: tuple = (
         "jaclang.compiler.frontend.unitree",
         "jaclang.compiler.frontend.codeinfo",
         "jaclang.compiler.frontend.srcloc",
         "jaclang.compiler.frontend.constant",
         "jaclang.compiler.frontend.parser.tokens",
         "jaclang.compiler.frontend.roles",
         "jaclang.compiler.frontend.relations",
         "jaclang.compiler.frontend.diagnostics",
         "jaclang.compiler.passes.transform",

     );


def _enum_class(name: str) -> any {
    import importlib;
    for modname in (
        "jaclang.compiler.frontend.constant",
        "jaclang.compiler.frontend.parser.tokens",
        "jaclang.compiler.frontend.diagnostics"
    ) {
        mod = importlib.import_module(modname);
        cls = getattr(mod, name, None);
        if isinstance(cls, `type) {
            return cls;
        }
    }
    return None;
}


def _enum_table(cls: any) -> (dict | None) {
    import enum as _enum;
    if not (isinstance(cls, `type) and issubclass(cls, _enum.Enum)) {
        return None;
    }
    members: list = `list(cls);
    if not members {
        return None;
    }
    if isinstance(members[0].value, int) {
        return {int(m.value): m for m in members};
    }
    return {i: members[i] for i in range(len(members))};
}


class NativeCompiler {
    def init(self: NativeCompiler, lib_path: str) {
        self.lib = ctypes.PyDLL(lib_path);
        with open(lib_path + ".layout.json") as f {
            self.layout = json.load(f)["classes"];
        }
        self._keep = [];
        self.classes = {};
        self._value_rows: dict[str, int] = {};
        self._bind();
        self._register();
    }

    def _bind(self: NativeCompiler) {
        L = self.lib;
        L.jac_str_new.argtypes = [c_char_p, c_int64];
        L.jac_str_new.restype = c_void_p;
        for name in ("jc_run", "jc_annex") {
            fn = getattr(L, name);
            fn.argtypes = [c_void_p, c_void_p, c_int64, c_void_p, c_void_p, c_int64];
            fn.restype = c_int64;
        }
        for name in ("jc_probe", "jc_err_count", "jc_lex_errs", "jc_mz_skipped") {
            fn = getattr(L, name);
            fn.argtypes = [];
            fn.restype = c_int64;
        }
        for name in (
            "jc_take_module",
            "jc_take_diags",
            "jc_take_lexdiags",
            "jc_take_comments"
        ) {
            fn = getattr(L, name);
            fn.argtypes = [];
            fn.restype = c_void_p;
        }
        L.jc_reg_consts.argtypes = [c_int64] * 12;
        L.jc_reg_consts.restype = c_int64;
        L.jc_reg_shape_roles.argtypes = [c_int64] * 3;
        L.jc_reg_shape_roles.restype = c_int64;
        L.jc_reg_class.argtypes = [c_int64] * 5;
        L.jc_reg_class.restype = c_int64;
        L.jc_reg_field.argtypes = [c_int64] * 7;
        L.jc_reg_field.restype = c_int64;
        L.jc_reg_default.argtypes = [c_int64] * 3;
        L.jc_reg_default.restype = c_int64;
        L.jc_reg_edge.argtypes = [c_int64] * 2;
        L.jc_reg_edge.restype = c_int64;
        L.jc_reg_hint_tags.argtypes = [c_int64] * 2;
        L.jc_reg_hint_tags.restype = c_int64;
        self.supports_early: bool = hasattr(L, "jc_set_early");
        if self.supports_early {
            L.jc_set_early.argtypes = [c_int64];
            L.jc_set_early.restype = c_int64;
            L.jc_completed.argtypes = [];
            L.jc_completed.restype = c_int64;
            L.jc_pass_time.argtypes = [c_int64];
            L.jc_pass_time.restype = c_double;
            L.jc_take_pass_alerts.argtypes = [c_int64, c_int64];
            L.jc_take_pass_alerts.restype = c_void_p;
        }
    }

    def _hold(self: NativeCompiler, o: any) -> int {
        self._keep.append(o);
        return id(o);
    }

    def _intern(self: NativeCompiler, s: str) -> int {
        return self._hold(sys.intern(s));
    }

    def _resolve_classes(self: NativeCompiler) {
        import importlib;
        for modname in CLASS_MODULES {
            mod = importlib.import_module(modname);
            for name in `list(vars(mod)) {
                if name in self.layout and name not in self.classes {
                    cls = getattr(mod, name);
                    if isinstance(cls, `type) {
                        self.classes[name] = cls;
                    }
                }
            }
        }
    }

    def _class_tag(self: NativeCompiler, name: str) -> int {
        info = self.layout.get(name);
        if info and info.get("tag") {
            return info["tag"];
        }
        return stable_osp_tag(name);
    }

    def _field_annotations(self: NativeCompiler, cls: any) -> dict {
        import from jaclang.runtime.object_interop { fields }
        import from jaclang.runtime.object_model { MISSING }
        out = {};
        try {
            for f in fields(cls) {
                out[f.name] = str(f.`type);
            }
        } except TypeError {}
        return out;
    }

    def _register_fields(self: NativeCompiler, name: str, cls: any, tag: int) {
        info = self.layout[name];
        anns = self._field_annotations(cls);
        fields: dict[str, dict[str, any]] = info["fields"];
        for (fname, f) in fields.items() {
            if fname.startswith("__") and not fname.endswith("__") {
                continue;
            }
            descr = getattr(cls, fname, None);
            if isinstance(descr, property) {
                continue;
            }
            code = f["code"];
            off = f["offset"];
            aux = str(f.get("aux", ""));
            nat_code = 0;
            aux_tag = 0;
            enum_h = 0;
            flags = 0;
            if code == "int" {
                nat_code = CODE_INT;
            } elif code == "bool" {
                nat_code = CODE_BOOL;
            } elif code == "str" {
                nat_code = CODE_STR;
            } elif code == "enum" {
                ecls = _enum_class(aux);
                table = _enum_table(ecls) if ecls else None;
                if table is None {
                    continue;
                }
                nat_code = CODE_ENUM;
                enum_h = self._hold(table);
            } elif code == "natlist" {
                nat_code = CODE_NATLIST;
            } elif code == "natdict" {
                nat_code = CODE_NATDICT;
                aux_tag = self._register_value(f["schema"]);
            } elif code == "union" {
                nat_code = CODE_UNION;
                parts = [x.strip(" ()") for x in anns.get(fname, "").split("|")];
                if "str" in parts {
                    flags = 1;
                }
            } elif code in ("optref", "obj") {
                if code == "obj" and aux == "" {
                    nat_code = CODE_OBJ;
                } elif aux not in self.layout or aux not in self.classes {
                    continue;
                } else {
                    nat_code = CODE_OPTREF if code == "optref" else CODE_OBJ;
                    aux_tag = self._class_tag(aux);
                }
            } elif code == "opaque" {
                import re;
                m = re.fullmatch(r"\(?\s*(\w+)\s*\|\s*None\s*\)?", anns.get(fname, ""));
                if not m {
                    continue;
                }
                ecls = _enum_class(m.group(1));
                table = _enum_table(ecls) if ecls else None;
                if table is None {
                    continue;
                }
                nat_code = CODE_OPTENUM;
                enum_h = self._hold(table);
            } else {
                continue;
            }
            self.lib.jc_reg_field(
                tag, self._intern(fname), nat_code, off, aux_tag, enum_h, flags
            );
        }
    }

    def _register_value(self: NativeCompiler, schema: dict) -> int {
        key = json.dumps(schema, sort_keys=True);
        cached = self._value_rows.get(key);
        if cached is not None {
            return cached;
        }
        child = self._register_value(schema["element"]) if "element" in schema else 0;
        index = len(self._value_rows) + 1;
        self._value_rows[key] = index;
        codes = {
            "str": CODE_STR,
            "obj": CODE_OBJ,
            "list": CODE_NATLIST,
            "dict": CODE_NATDICT
        };
        fn = self.lib.jc_reg_value;
        fn.argtypes = [c_int64] * 7;
        fn.restype = c_int64;
        fn(
            index,
            codes[schema["code"]],
            self._class_tag(schema["class"]) if "class" in schema else 0,
            child,
            schema.get("key_offset", 0),
            schema.get("data_offset", 0),
            schema.get("order_offset", 0)
        );
        return index;
    }

    def _register_defaults(self: NativeCompiler, cls: any, tag: int) {
        import from jaclang.runtime.object_interop { fields }
        import from jaclang.runtime.object_model { MISSING }
        try {
            dc_fields = fields(cls);
        } except TypeError {
            return;
        }
        for f in dc_fields {
            if f.`default is not MISSING {
                continue;
            }
            descr = getattr(cls, f.name, None);
            if isinstance(descr, property) {
                continue;
            }
            kind = -1;
            if f.default_factory is not None {
                if f.default_factory is `list {
                    kind = 1;
                } elif f.default_factory is `dict {
                    kind = 2;
                } elif f.default_factory is `set {
                    kind = 3;
                }
            }
            if kind < 0 {
                ann = str(f.`type);
                parts = [x.strip(" ()") for x in ann.split("|")];
                bare = ann.lstrip("(").strip();
                if "None" in parts {
                    kind = 0;
                } elif bare.startswith("dict") {
                    kind = 2;
                } elif bare.startswith("list") {
                    kind = 1;
                } elif bare.startswith("set") {
                    kind = 3;
                } else {
                    kind = 0;
                }
            }
            self.lib.jc_reg_default(tag, self._intern(str(f.name)), kind);
        }
    }

    def _register_edges(self: NativeCompiler) {
        import importlib;
        roles_mod = importlib.import_module("jaclang.compiler.frontend.roles");
        relations_mod = importlib.import_module("jaclang.compiler.frontend.relations");
        seen = set();
        for mod in (roles_mod, relations_mod) {
            mod_name = getattr(mod, "__name__", "");
            for name in `list(vars(mod)) {
                cls = getattr(mod, name);
                if (
                    isinstance(cls, `type)
                    and getattr(cls, "__module__", "") == mod_name
                    and name not in seen
                ) {
                    seen.add(name);
                    self.lib.jc_reg_edge(stable_osp_tag(name), self._hold(cls));
                }
            }
        }
    }

    def _register(self: NativeCompiler) {
        import from jaclang.runtime.archetype { NodeArchetype }
        import from jaclang.compiler.frontend.roles {
            AccessorsRole,
            BodyRole,
            SpecRole
        }
        self._resolve_classes();
        self.lib.jc_reg_consts(
            self._hold(None),
            self._hold(True),
            self._hold(False),
            self._intern(""),
            self._intern("none"),
            self._intern("one"),
            self._intern("many"),
            self._intern("out_light"),
            self._intern("in_light"),
            self._intern("__jac__"),
            self._intern("_role_shapes"),
            self._intern("archetype")
        );
        self.lib.jc_reg_shape_roles(
            self._hold(BodyRole), self._hold(SpecRole), self._hold(AccessorsRole)
        );
        for (name, cls) in self.classes.items() {
            info = self.layout[name];
            tag = self._class_tag(name);
            tagged = 0;
            if info.get("tag") and info.get("tag_offset", -1) >= 0 {
                tagged = 1;
            }
            is_node = 1 if issubclass(cls, NodeArchetype) else 0;
            self.lib.jc_reg_class(tag, self._hold(cls), info["size"], tagged, is_node);
            self._register_defaults(cls, tag);
            self._register_fields(name, cls, tag);
        }
        import from jaclang.runtime.archetype { NodeAnchor }
        self.lib.jc_reg_class(1, self._hold(NodeAnchor), 0, 0, 0);
        self._register_defaults(NodeAnchor, 1);
        self._register_edges();
        self.lib.jc_reg_hint_tags(
            stable_osp_tag("SrcDiag"), stable_osp_tag("CommentData")
        );
    }

    def _call_str2(self: NativeCompiler, name: str, a: str, b: str) -> int {
        fn = getattr(self.lib, name);
        ab = a.encode();
        bb = b.encode();
        pa = self.lib.jac_str_new(ab, len(ab));
        pb = self.lib.jac_str_new(bb, len(bb));
        return fn(
            c_void_p(pa),
            c_void_p(pa),
            c_int64(len(ab)),
            c_void_p(pb),
            c_void_p(pb),
            c_int64(len(bb))
        );
    }

    def annex(self: NativeCompiler, annex_src: str, annex_path: str) -> int {
        return self._call_str2("jc_annex", annex_src, annex_path);
    }

    def run(self: NativeCompiler, source: str, path: str) -> int {
        return self._call_str2("jc_run", source, path);
    }

    def prepare_early(self: NativeCompiler, context: str) {
        if self.supports_early {
            self.lib.jc_set_early(
                {"server": 1, "client": 2, "native": 3}.get(context, 0)
            );
        }
    }

    def take_pass_results(self: NativeCompiler) -> dict[str, PassResult] {
        import from jaclang.compiler.passes.transform { PassResult }
        import from jaclang.compiler.passes.ast_validation_pass { ASTValidationPass }
        import from jaclang.compiler.passes.sym_tab_build_pass { SymTabBuildPass }
        out: dict[str, PassResult] = {};
        if not self.supports_early {
            return out;
        }
        completed = self.lib.jc_completed();
        passes: list[tuple[int, type]] = [(1, ASTValidationPass), (2, SymTabBuildPass)];
        for (pass_id, pass_cls) in passes {
            if not (completed & pass_id) {
                continue;
            }
            errors = self._take(self.lib.jc_take_pass_alerts(pass_id, 0)) or [];
            warnings = self._take(self.lib.jc_take_pass_alerts(pass_id, 1)) or [];
            for alert in errors + warnings {
                alert.from_pass = pass_cls;
                if alert.code is not None {
                    import from jaclang.compiler.frontend.diagnostics { DIAGNOSTICS }
                    alert.code = DIAGNOSTICS[alert.code.code];
                }
            }
            out[pass_cls.__name__] = PassResult(
                errors_had=errors,
                warnings_had=warnings,
                time_taken=self.lib.jc_pass_time(pass_id)
            );
        }
        return out;
    }

    def _take(self: NativeCompiler, ptr: any) -> any {
        if not ptr {
            return None;
        }
        boxed = cast(ptr, py_object);
        out = boxed.value;
        ctypes.pythonapi.Py_DecRef(boxed);
        return out;
    }

    def take_module(self: NativeCompiler) -> any {
        return self._take(self.lib.jc_take_module());
    }

    def take_diags(self: NativeCompiler) -> list {
        return self._take(self.lib.jc_take_diags()) or [];
    }

    def take_lexdiags(self: NativeCompiler) -> list {
        return self._take(self.lib.jc_take_lexdiags()) or [];
    }

    def take_comments(self: NativeCompiler) -> list {
        return self._take(self.lib.jc_take_comments()) or [];
    }

    def err_count(self: NativeCompiler) -> int {
        return self.lib.jc_err_count();
    }

    def lex_errs(self: NativeCompiler) -> int {
        return self.lib.jc_lex_errs();
    }

    def skipped(self: NativeCompiler) -> int {
        return self.lib.jc_mz_skipped();
    }
}


glob _KERNEL_CELL: list = [],
     _RESOLVED: list = [];


def _lib_name -> str {
    if sys.platform == "darwin" {
        return "libjac_compiler.dylib";
    }
    return "libjac_compiler.so";
}


def _kit_site_present -> bool {
    shim = "libjacllvm.dylib" if sys.platform == "darwin" else "libjacllvm.so";
    here = os.path.dirname(os.path.abspath(__file__));
    if os.path.isfile(os.path.join(here, "backends", "native", "llvm", shim)) {
        return True;
    }
    for p in sys.path {
        if p
            and os.path.isfile(
                os.path.join(
                    p, "jaclang", "compiler", "backends", "native", "llvm", shim
                )
            ) {
            return True;
        }
    }
    return False;
}


def _find_lib -> (str | None) {
    if os.environ.get("JAC_STUBCAT_BUILDING") {
        return None;
    }
    ov = os.environ.get("JAC_COMPILER_LIB", "");
    if ov.strip().lower() in ("none", "off", "disabled", "0") {
        return None;
    }
    if ov {
        if os.path.isfile(ov) and os.path.isfile(ov + ".layout.json") {
            return ov;
        }
        raise OSError(
            f"JAC_COMPILER_LIB={ov} does not name a kernel lib with its "
            ".layout.json sidecar"
        );
    }
    name = _lib_name();
    here = os.path.dirname(os.path.abspath(__file__));
    cand = os.path.join(here, name);
    if os.path.isfile(cand) and os.path.isfile(cand + ".layout.json") {
        return cand;
    }
    if os.environ.get("JAC_DEV_SOURCE") {
        return None;
    }
    for p in sys.path {
        if not p {
            continue;
        }
        alt = os.path.join(p, "jaclang", "compiler", name);
        if os.path.isfile(alt) and os.path.isfile(alt + ".layout.json") {
            return alt;
        }
    }
    if _kit_site_present() {
        raise OSError(
            f"This jac build is missing its native compiler kernel ('{name}' "
            "+ .layout.json under jaclang/compiler/). Every fully built jac "
            "binary parses natively; rebuild the kit (zig build), or set "
            "JAC_COMPILER_LIB=off to run the store parser explicitly."
        );
    }
    return None;
}


def ensure_loaded -> (NativeCompiler | None) {
    if _KERNEL_CELL {
        return _KERNEL_CELL[0];
    }
    if _RESOLVED {
        return None;
    }
    path = _find_lib();
    if path is None {
        _RESOLVED.append(None);
        return None;
    }
    k = NativeCompiler(path);
    _KERNEL_CELL.append(k);
    return k;
}
