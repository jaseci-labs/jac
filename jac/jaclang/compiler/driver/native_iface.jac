import hashlib;
import json;
import os;
import sys;
import from jaclang.compiler.frontend.codeinfo {
    NATIVE_ABI_VERSION,
    NativeFieldInfo,
    NativeEnumLayout,
    NativeFuncLayout,
    NativeModuleLayout,
    NativeStructLayout,
    NativeTupleLayout,
    native_unit_identity,
    native_unit_root
}
import from jaclang.compiler.kernel_target { target_pkg_root }

def native_unit_ref(path: str) -> str {
    """How one unit names another in what it writes to disk: by package
    identity when the other lives under a root, so the reference survives
    the package moving, and by real path otherwise.""";
    rp = os.path.realpath(path);
    ident = native_unit_identity(rp);
    return ident if ident != rp else rp;
}

def resolve_native_unit_ref(ref: str, anchor: str = "") -> str {
    """The path a unit reference names here: an absolute path is itself;
    `jaclang/...` is under this process's jaclang; another root's identity
    is looked for as the anchor unit's own root, beside it, then under each
    import path. A reference found nowhere names a path that cannot exist,
    never one relative to the working directory, so its unit reads as
    missing and is rebuilt.""";
    if not ref or os.path.isabs(ref) {
        return ref;
    }
    (root_name, _sep, rel) = ref.partition("/");
    if not rel {
        return ref;
    }
    if root_name == "jaclang" {
        return os.path.join(os.path.dirname(target_pkg_root()), ref);
    }
    if anchor {
        anchor_root = native_unit_root(os.path.dirname(os.path.realpath(anchor)));
        if anchor_root is not None {
            if os.path.basename(anchor_root) == root_name {
                return os.path.join(anchor_root, rel);
            }
            sibling = os.path.join(os.path.dirname(anchor_root), ref);
            if os.path.isfile(sibling) {
                return sibling;
            }
        }
    }
    for search_dir in sys.path {
        if search_dir and os.path.isabs(search_dir) {
            candidate = os.path.join(search_dir, ref);
            if os.path.isfile(candidate) {
                return candidate;
            }
        }
    }
    return os.path.join(os.path.abspath(os.sep), "<unresolved native unit>", ref);
}

def _tuple_layout_to_dict(t: (NativeTupleLayout | None)) -> (dict[str, any] | None) {
    if t is None {
        return None;
    }
    return {
        "key": t.key,
        "element_types": list(t.element_types),
        "element_struct_hints": list(t.element_struct_hints)
    };
}

def _func_layout_to_dict(f: NativeFuncLayout) -> dict[str, any] {
    return {
        "name": f.name,
        "param_types": list(f.param_types),
        "param_names": list(f.param_names),
        "ret_type": f.ret_type,
        "ret_struct_name": f.ret_struct_name,
        "ret_tuple_layout": _tuple_layout_to_dict(f.ret_tuple_layout),
        "ret_enum_type": f.ret_enum_type,
        "ret_elem_keys": (
            list(f.ret_elem_keys) if f.ret_elem_keys is not None else None
        )
    };
}

def native_layout_to_dict(layout: NativeModuleLayout) -> dict[str, any] {
    return {
        "abi_version": layout.abi_version,
        "structs": {
            name: {
                "name": s.name,
                "has_vtable": s.has_vtable,
                "accessors": {
                    fname: dict[str, str](kinds)
                    for (fname, kinds) in s.accessors.items()
                },
                "fields": [
                    {
                        "name": fld.name,
                        "llvm_type": fld.llvm_type,
                        "index": fld.index,
                        "enum_type": fld.enum_type,
                        "is_func_ptr": fld.is_func_ptr,
                        "func_param_types": (
                            list(fld.func_param_types)
                                if fld.func_param_types is not None
                                else None
                        ),
                        "func_ret_type": fld.func_ret_type,
                        "elem_keys": (
                            list(fld.elem_keys) if fld.elem_keys is not None else None
                        ),
                        "foreign": fld.foreign
                    } for fld in s.fields
                ]
            } for (name, s) in layout.structs.items()
        },
        "enums": {
            name: {
                "name": e.name,
                "is_string_valued": e.is_string_valued,
                "members": list(e.members)
            } for (name, e) in layout.enums.items()
        },
        "functions": {
            name: _func_layout_to_dict(f) for (name, f) in layout.functions.items()
        },
        "methods": {
            name: _func_layout_to_dict(f) for (name, f) in layout.methods.items()
        },
        "list_elem_types": dict(layout.list_elem_types),
        "tuples": {key: _tuple_layout_to_dict(t) for (key, t) in layout.tuples.items()},
        "str_headerless": layout.str_headerless
    };
}

def _tuple_layout_from_dict(raw: any) -> (NativeTupleLayout | None) {
    if not isinstance(raw, dict) {
        return None;
    }
    d: dict[str, any] = raw;
    return NativeTupleLayout(
        key=str(d.get("key", "")),
        element_types=[str(x) for x in (d.get("element_types") or [])],
        element_struct_hints=list(d.get("element_struct_hints") or [])
    );
}

def _func_layout_from_dict(raw: any) -> NativeFuncLayout {
    d: dict[str, any] = raw;
    keys: any = d.get("ret_elem_keys");
    return NativeFuncLayout(
        name=str(d.get("name", "")),
        param_types=[str(x) for x in (d.get("param_types") or [])],
        param_names=[str(x) for x in (d.get("param_names") or [])],
        ret_type=str(d.get("ret_type", "i64")),
        ret_struct_name=d.get("ret_struct_name"),
        ret_tuple_layout=_tuple_layout_from_dict(d.get("ret_tuple_layout")),
        ret_enum_type=d.get("ret_enum_type"),
        ret_elem_keys=list(keys) if keys is not None else None
    );
}

def _field_info_from_dict(raw: any) -> NativeFieldInfo {
    fd: dict[str, any] = raw;
    fpt: any = fd.get("func_param_types");
    ek: any = fd.get("elem_keys");
    return NativeFieldInfo(
        name=str(fd.get("name", "")),
        llvm_type=str(fd.get("llvm_type", "i64")),
        index=int(fd.get("index", 0)),
        enum_type=fd.get("enum_type"),
        is_func_ptr=bool(fd.get("is_func_ptr", False)),
        func_param_types=list(fpt) if fpt is not None else None,
        func_ret_type=fd.get("func_ret_type"),
        elem_keys=list(ek) if ek is not None else None,
        foreign=bool(fd.get("foreign", False))
    );
}

def native_layout_from_dict(raw: any) -> NativeModuleLayout {
    d: dict[str, any] = raw;
    layout = NativeModuleLayout(
        abi_version=int(d.get("abi_version", NATIVE_ABI_VERSION)),
        str_headerless=d.get("str_headerless")
    );
    structs: dict[str, any] = d.get("structs") or {};
    for (name, sraw) in structs.items() {
        sd: dict[str, any] = sraw;
        fields: list[NativeFieldInfo] = [];
        for fd in (sd.get("fields") or []) {
            fields.append(_field_info_from_dict(fd));
        }
        accessors: dict[str, dict[str, str]] = {};
        raw_acc: dict[str, any] = sd.get("accessors") or {};
        for (fn_name, kinds) in raw_acc.items() {
            kind_map: dict[str, any] = kinds;
            accessors[str(fn_name)] = {str(k): str(v) for (k, v) in kind_map.items()};
        }
        layout.structs[str(name)] = NativeStructLayout(
            name=str(sd.get("name", name)),
            fields=fields,
            has_vtable=bool(sd.get("has_vtable", False)),
            accessors=accessors
        );
    }
    enums: dict[str, any] = d.get("enums") or {};
    for (name, eraw) in enums.items() {
        ed: dict[str, any] = eraw;
        layout.enums[str(name)] = NativeEnumLayout(
            name=str(ed.get("name", name)),
            is_string_valued=bool(ed.get("is_string_valued", False)),
            members=list(ed.get("members") or [])
        );
    }
    functions: dict[str, any] = d.get("functions") or {};
    for (name, fraw) in functions.items() {
        layout.functions[str(name)] = _func_layout_from_dict(fraw);
    }
    methods: dict[str, any] = d.get("methods") or {};
    for (name, mraw) in methods.items() {
        layout.methods[str(name)] = _func_layout_from_dict(mraw);
    }
    elem_types: dict[str, any] = d.get("list_elem_types") or {};
    layout.list_elem_types = {str(k): str(v) for (k, v) in elem_types.items()};
    tuples: dict[str, any] = d.get("tuples") or {};
    for (key, traw) in tuples.items() {
        t = _tuple_layout_from_dict(traw);
        if t is not None {
            layout.tuples[str(key)] = t;
        }
    }
    return layout;
}

glob NIFACE_FORMAT: int = 3,
     NIFACE_HASH_LEN: int = 64,
     EXPORT_FUNCTION: str = "function",
     EXPORT_METHOD: str = "method",
     EXPORT_GLOBAL: str = "global",
     EXPORT_STATIC: str = "static",
     EXPORT_VTABLE: str = "vtable",
     EXPORT_TEST: str = "test";

obj NativeExport {
    has name: str,
        symbol: str,
        kind: str,
        is_pub: bool = False,
        param_types: list[str] = [],
        param_names: list[str] = [],
        param_defaults: list[str] = [],
        ret_type: str = "",
        ownership: list[str] = [];

    def to_dict -> dict[str, any] {
        return {
            "name": self.name,
            "symbol": self.symbol,
            "kind": self.kind,
            "is_pub": self.is_pub,
            "param_types": list(self.param_types),
            "param_names": list(self.param_names),
            "param_defaults": list(self.param_defaults),
            "ret_type": self.ret_type,
            "ownership": list(self.ownership)
        };
    }

    static def from_dict(d: dict[str, any]) -> NativeExport {
        return NativeExport(
            name=str(d.get("name", "")),
            symbol=str(d.get("symbol", "")),
            kind=str(d.get("kind", EXPORT_FUNCTION)),
            is_pub=bool(d.get("is_pub", False)),
            param_types=[str(x) for x in d.get("param_types", [])],
            param_names=[str(x) for x in d.get("param_names", [])],
            param_defaults=[str(x) for x in d.get("param_defaults", [])],
            ret_type=str(d.get("ret_type", "")),
            ownership=[str(x) for x in d.get("ownership", [])]
        );
    }
}

obj NativeValueSchema {
    has code: str,
        class_name: str = "",
        element: (NativeValueSchema | None) = None,
        data_offset: int = 0,
        key_offset: int = 0,
        order_offset: int = 0;

    def to_dict -> dict[str, any] {
        out: dict[str, any] = {"code": self.code};
        if self.code == "obj" {
            out["class"] = self.class_name;
        } elif self.code in ("list", "dict", "set") {
            if self.element is not None {
                out["element"] = self.element.to_dict();
            }
            if self.code != "set" {
                out["data_offset"] = self.data_offset;
            }
            if self.code != "list" {
                out["key_offset"] = self.key_offset;
                out["order_offset"] = self.order_offset;
            }
        }
        return out;
    }

    static def from_dict(d: dict[str, any]) -> NativeValueSchema {
        child = d.get("element");
        return NativeValueSchema(
            code=str(d["code"]),
            class_name=str(d.get("class", "")),
            element=(
                NativeValueSchema.from_dict(child) if isinstance(child, dict) else None
            ),
            data_offset=int(d.get("data_offset", 0)),
            key_offset=int(d.get("key_offset", 0)),
            order_offset=int(d.get("order_offset", 0))
        );
    }
}

obj NativeFieldSlot {
    has index: int,
        offset: int,
        code: str,
        aux: str = "",
        schema: (NativeValueSchema | None) = None;

    def to_dict -> dict[str, any] {
        out: dict[str, any] = {
            "index": self.index,
            "offset": self.offset,
            "code": self.code,
            "aux": self.aux
        };
        if self.schema is not None {
            out["schema"] = self.schema.to_dict();
        }
        return out;
    }

    static def from_dict(d: dict[str, any]) -> NativeFieldSlot {
        schema = d.get("schema");
        return NativeFieldSlot(
            index=int(d.get("index", -1)),
            offset=int(d.get("offset", -1)),
            code=str(d.get("code", "opaque")),
            aux=str(d.get("aux", "")),
            schema=(
                NativeValueSchema.from_dict(schema)
                    if isinstance(schema, dict)
                    else None
            )
        );
    }
}

obj NativeClassLayout {
    has name: str,
        size: int = 0,
        tag: int = 0,
        tag_offset: int = -1,
        fields: dict[str, NativeFieldSlot] = {},
        bases: list[str] = [],
        vtable: list[str] = [],
        is_node: bool = False;

    def to_dict -> dict[str, any] {
        return {
            "name": self.name,
            "size": self.size,
            "tag": self.tag,
            "tag_offset": self.tag_offset,
            "fields": {k: v.to_dict() for (k, v) in self.fields.items()},
            "bases": list(self.bases),
            "vtable": list(self.vtable),
            "is_node": self.is_node
        };
    }

    static def from_dict(d: dict[str, any]) -> NativeClassLayout {
        return NativeClassLayout(
            name=str(d.get("name", "")),
            size=int(d.get("size", 0)),
            tag=int(d.get("tag", 0)),
            tag_offset=int(d.get("tag_offset", -1)),
            fields={
                str(k): NativeFieldSlot.from_dict(dict(v))
                for (k, v) in (d.get("fields") or {}).items()
            },
            bases=[str(x) for x in d.get("bases", [])],
            vtable=[str(x) for x in d.get("vtable", [])],
            is_node=bool(d.get("is_node", False))
        );
    }
}

def _fields_digest(fields: dict[str, any]) -> str {
    body = json.dumps(fields, sort_keys=True, separators=(",", ":"));
    return hashlib.sha256(body.encode("utf-8")).hexdigest();
}

obj NativeIface {
    has format: int = NIFACE_FORMAT,
        module: str = "",
        prefix: str = "",
        exports: dict[str, NativeExport] = {},
        classes: dict[str, NativeClassLayout] = {},
        enums: dict[str, list[str]] = {},
        init_symbol: str = "",
        entry_symbol: str = "",
        demoted: list[str] = [],
        clib_paths: list[str] = [],
        python_imports: list[str] = [],
        clib_symbol_lib: dict[str, str] = {},
        layout: (NativeModuleLayout | None) = None,
        deps: list[str] = [],
        coverage: dict[str, any] = {},
        headerless: bool = False;

    def digest_fields -> dict[str, any] {
        return {
            "format": self.format,
            "module": self.module,
            "prefix": self.prefix,
            "exports": {
                k: self.exports[k].to_dict() for k in sorted(self.exports.keys())
            },
            "classes": {
                k: self.classes[k].to_dict() for k in sorted(self.classes.keys())
            },
            "enums": {k: list(self.enums[k]) for k in sorted(self.enums.keys())},
            "init": self.init_symbol,
            "entry": self.entry_symbol,
            "demoted": sorted(self.demoted),
            "clib_paths": list(self.clib_paths),
            "python_imports": sorted(self.python_imports),
            "clib_symbol_lib": {
                k: self.clib_symbol_lib[k] for k in sorted(self.clib_symbol_lib.keys())
            },
            "layout": (
                native_layout_to_dict(self.layout) if self.layout is not None else None
            ),
            "headerless": self.headerless
        };
    }

    def digest -> str {
        return _fields_digest(self.digest_fields());
    }

    def to_dict -> dict[str, any] {
        return self._with_references(self.digest_fields());
    }

    def _with_references(fields: dict[str, any]) -> dict[str, any] {
        fields["deps"] = [native_unit_ref(x) for x in self.deps];
        fields["coverage"] = dict(self.coverage);
        return fields;
    }

    def resolve_deps(anchor: str) {
        """Dependencies read from disk are references; the unit's own path
        tells where a same-package reference lives.""";
        self.deps = [resolve_native_unit_ref(x, anchor) for x in self.deps];
    }

    def to_bytes -> bytes {
        fields = self.digest_fields();
        digest = _fields_digest(fields);
        body = json.dumps(
            self._with_references(fields), sort_keys=True, separators=(",", ":")
        );
        return digest.encode("ascii") + body.encode("utf-8");
    }

    static def from_dict(d: dict[str, any]) -> (NativeIface | None) {
        if not isinstance(d, dict) or d.get("format") != NIFACE_FORMAT {
            return None;
        }
        layout_d = d.get("layout");
        return NativeIface(
            module=str(d.get("module", "")),
            prefix=str(d.get("prefix", "")),
            exports={
                str(k): NativeExport.from_dict(dict(v))
                for (k, v) in (d.get("exports") or {}).items()
            },
            classes={
                str(k): NativeClassLayout.from_dict(dict(v))
                for (k, v) in (d.get("classes") or {}).items()
            },
            enums={
                str(k): [str(m) for m in v] for (k, v) in (d.get("enums") or {}).items()
            },
            init_symbol=str(d.get("init", "")),
            entry_symbol=str(d.get("entry", "")),
            demoted=[str(x) for x in d.get("demoted", [])],
            clib_paths=[str(x) for x in d.get("clib_paths", [])],
            python_imports=[str(x) for x in d.get("python_imports", [])],
            clib_symbol_lib={
                str(k): str(v) for (k, v) in (d.get("clib_symbol_lib") or {}).items()
            },
            layout=(
                native_layout_from_dict(layout_d)
                    if isinstance(layout_d, dict)
                    else None
            ),
            deps=[str(x) for x in d.get("deps", [])],
            coverage=dict(d.get("coverage") or {}),
            headerless=bool(d.get("headerless", False))
        );
    }

    static def from_bytes(raw: (bytes | None)) -> (NativeIface | None) {
        """A stored interface is trusted only when its body hashes to the digest
        it is prefixed with: a truncated or corrupted entry decodes to nothing and
        its unit is recompiled, instead of one reader taking the prefix and
        another the body.""";
        if raw is None or len(raw) <= NIFACE_HASH_LEN {
            return None;
        }
        recorded = NativeIface.read_digest(raw);
        if recorded is None {
            return None;
        }
        try {
            iface = NativeIface.from_dict(
                json.loads(raw[NIFACE_HASH_LEN:].decode("utf-8"))
            );
        } except Exception {
            return None;
        }
        if iface is None or iface.digest() != recorded {
            return None;
        }
        return iface;
    }

    static def verified_digest(raw: (bytes | None)) -> (str | None) {
        """The recorded digest of a stored interface whose body agrees with it.""";
        if NativeIface.from_bytes(raw) is None {
            return None;
        }
        return NativeIface.read_digest(raw);
    }

    static def read_digest(raw: (bytes | None)) -> (str | None) {
        if raw is None or len(raw) <= NIFACE_HASH_LEN {
            return None;
        }
        try {
            return raw[:NIFACE_HASH_LEN].decode("ascii");
        } except Exception {
            return None;
        }
    }

    def pub_symbols -> list[str] {
        out: list[str] = [];
        for name in sorted(self.exports.keys()) {
            ex = self.exports[name];
            if ex.is_pub and ex.symbol not in out {
                out.append(ex.symbol);
            }
        }
        return out;
    }

    def symbol_of(name: str) -> (str | None) {
        ex = self.exports.get(name);
        return ex.symbol if ex is not None else None;
    }

    def is_demoted(name: str) -> bool {
        return name in self.demoted;
    }

    def classes_json -> dict[str, any] {
        return {
            name: {
                "size": lay.size,
                "tag": lay.tag,
                "tag_offset": lay.tag_offset,
                "fields": {k: v.to_dict() for (k, v) in lay.fields.items()},
                "bases": list(lay.bases),
                "vtable": list(lay.vtable),
                "is_node": lay.is_node
            } for (name, lay) in sorted(self.classes.items())
        };
    }
}

def merge_class_layouts(ifaces: list[NativeIface]) -> dict[str, any] {
    by_name: dict[str, dict[str, tuple[any, str]]] = {};
    for iface in ifaces {
        bodies = iface.classes_json();
        for (name, lay) in iface.classes.items() {
            ident = lay.name or name;
            body = bodies[name];
            same_name = by_name.setdefault(name, {});
            prev = same_name.get(ident);
            if prev is None {
                same_name[ident] = (body, iface.module);
                continue;
            }
            if prev[0] != body {
                raise ValueError(
                    f"native layout disagreement for class '{name}': "
                    f"{prev[1]} and {iface.module} lay it out differently"
                );
            }
        }
    }
    merged: dict[str, any] = {};
    for (name, idents) in by_name.items() {
        if len(idents) == 1 {
            merged[name] = list(idents.values())[0][0];
            continue;
        }
        for (ident, found) in idents.items() {
            merged[ident] = found[0];
        }
    }
    return {k: merged[k] for k in sorted(merged.keys())};
}

def layout_digest(classes: dict[str, any]) -> str {
    body = json.dumps(classes, sort_keys=True, separators=(",", ":"));
    return hashlib.sha256(body.encode("utf-8")).hexdigest();
}
