import ctypes;
import json;
import os;
import sys;
import from ctypes { c_char_p, c_int64, c_void_p, cast, py_object }
import from jaclang.runtime.osp_tag { stable_osp_tag }
import type from jaclang.compiler.passes.transform { PassResult }
import from jaclang.compiler.frontend.result { FRONTEND_ABI, FrontendResult }

glob CODE_INT: int = 1,
     CODE_BOOL: int = 2,
     CODE_STR: int = 3,
     CODE_ENUM: int = 4,
     CODE_OPTREF: int = 5,
     CODE_OBJ: int = 6,
     CODE_NATLIST: int = 7,
     CODE_UNION: int = 8,
     CODE_OPTENUM: int = 9,
     CODE_NATDICT: int = 10,
     CODE_FLOAT: int = 11;

glob CLASS_MODULES: tuple = (
         "jaclang.compiler.frontend.unitree",
         "jaclang.compiler.frontend.codeinfo",
         "jaclang.compiler.frontend.srcloc",
         "jaclang.compiler.frontend.constant",
         "jaclang.compiler.frontend.parser.tokens",
         "jaclang.compiler.frontend.result",
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
        version = getattr(L, "jc_result_abi", None);
        if version is None {
            raise OSError("Rebuild the native compiler kernel for the typed frontend ABI");
        }
        version.argtypes = [];
        version.restype = c_int64;
        self.result_abi: int = version();
        if self.result_abi != FRONTEND_ABI {
            raise OSError("Native compiler kernel frontend ABI does not match the compiler");
        }
        L.jac_str_new.argtypes = [c_char_p, c_int64];
        L.jac_str_new.restype = c_void_p;
        strings = [c_void_p, c_void_p, c_int64, c_void_p, c_void_p, c_int64];
        L.jc_request.argtypes = strings + [c_int64];
        L.jc_request.restype = c_void_p;
        L.jc_annex.argtypes = [c_void_p] + strings;
        L.jc_annex.restype = c_int64;
        L.jc_run.argtypes = [c_void_p];
        L.jc_run.restype = c_void_p;
        L.jc_discard.argtypes = [c_void_p];
        L.jc_discard.restype = None;
        for name in ("jc_probe", "jc_mz_skipped") {
            fn = getattr(L, name);
            fn.argtypes = [];
            fn.restype = c_int64;
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
        L.jc_reg_edge_builder.argtypes = [c_int64];
        L.jc_reg_edge_builder.restype = c_int64;
        L.jc_reg_edge.argtypes = [c_int64] * 2;
        L.jc_reg_edge.restype = c_int64;
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
            } elif code == "float" {
                nat_code = CODE_FLOAT;
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
        import from jaclang.runtime.runtime { JacGraph }
        self.lib.jc_reg_edge_builder(self._hold(JacGraph.heavy_edge));
    }

    def _call_str2(
        self: NativeCompiler, name: str, a: str, b: str,
        prefix: tuple = (), suffix: tuple = ()
    ) -> int {
        fn = getattr(self.lib, name);
        ab = a.encode();
        bb = b.encode();
        pa = self.lib.jac_str_new(ab, len(ab));
        pb = self.lib.jac_str_new(bb, len(bb));
        return fn(
            *prefix,
            c_void_p(pa),
            c_void_p(pa),
            c_int64(len(ab)),
            c_void_p(pb),
            c_void_p(pb),
            c_int64(len(bb)),
            *suffix
        );
    }

    def run(
        self: NativeCompiler,
        source: str,
        path: str,
        annexes: list[tuple[str, str]],
        context: str = ""
    ) -> (FrontendResult | None) {
        request = self._call_str2(
            "jc_request", source, path,
            suffix=(c_int64({"server": 1, "client": 2, "native": 3}.get(context, 0)),)
        );
        if not request {
            raise MemoryError("Cannot allocate native frontend request");
        }
        try {
            for (annex_source, annex_path) in annexes {
                self._call_str2(
                    "jc_annex", annex_source, annex_path,
                    prefix=(c_void_p(request),)
                );
            }
        } except BaseException {
            self.lib.jc_discard(c_void_p(request));
            raise;
        }
        # jc_run consumes the request, including on a compilation failure.
        result = self._take(self.lib.jc_run(c_void_p(request)));
        if result is None {
            return None;
        }
        if not isinstance(result, FrontendResult) {
            raise RuntimeError("native frontend returned an invalid result");
        }
        return result;
    }

    def pass_results(
        self: NativeCompiler, result: FrontendResult
    ) -> dict[str, PassResult] {
        import from jaclang.compiler.passes.transform { PassResult, Transform }
        import from jaclang.compiler.passes.ast_validation_pass { ASTValidationPass }
        import from jaclang.compiler.passes.sym_tab_build_pass { SymTabBuildPass }
        import from jaclang.compiler.passes.decl_impl_match_pass { DeclImplMatchPass }
        import from jaclang.compiler.frontend.diagnostics { DIAGNOSTICS }
        classes: dict[str, type[Transform]] = {
            "ASTValidationPass": ASTValidationPass,
            "SymTabBuildPass": SymTabBuildPass,
            "DeclImplMatchPass": DeclImplMatchPass
        };
        out: dict[str, PassResult] = {};
        for completed in result.passes {
            pass_cls = classes[completed.name];
            for alert in completed.errors_had + completed.warnings_had {
                alert.from_pass = pass_cls;
                if alert.code is not None {
                    alert.code = DIAGNOSTICS[alert.code.code];
                }
            }
            out[completed.name] = completed;
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
