import hashlib;
import json;
import from jaclang.runtime.object_model { field }
import from jaclang.compiler.frontend.codeinfo {
    NativeModuleLayout,
    native_layout_to_dict
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
        param_types: list[str] = field(default_factory=`list),
        param_names: list[str] = field(default_factory=`list),
        param_defaults: list[str] = field(default_factory=`list),
        ret_type: str = "",
        ownership: list[str] = field(default_factory=`list);

    def to_dict -> dict {
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

    static def from_dict(d: dict) -> NativeExport {
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

    def to_dict -> dict {
        out: dict = {"code": self.code};
        if self.code == "obj" {
            out["class"] = self.class_name;
        } elif self.code in ("list", "dict") {
            if self.element is not None {
                out["element"] = self.element.to_dict();
            }
            out["data_offset"] = self.data_offset;
            if self.code == "dict" {
                out["key_offset"] = self.key_offset;
                out["order_offset"] = self.order_offset;
            }
        }
        return out;
    }

    static def from_dict(d: dict) -> NativeValueSchema {
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

    def to_dict -> dict {
        out: dict = {
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

    static def from_dict(d: dict) -> NativeFieldSlot {
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
        fields: dict[str, NativeFieldSlot] = field(default_factory=`dict),
        bases: list[str] = field(default_factory=`list),
        vtable: list[str] = field(default_factory=`list),
        is_node: bool = False;

    def to_dict -> dict {
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

    static def from_dict(d: dict) -> NativeClassLayout {
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

obj NativeIface {
    has format: int = NIFACE_FORMAT,
        module: str = "",
        prefix: str = "",
        exports: dict[str, NativeExport] = field(default_factory=`dict),
        classes: dict[str, NativeClassLayout] = field(default_factory=`dict),
        enums: dict[str, list[str]] = field(default_factory=`dict),
        init_symbol: str = "",
        entry_symbol: str = "",
        demoted: list[str] = field(default_factory=`list),
        clib_paths: list[str] = field(default_factory=`list),
        python_imports: list[str] = field(default_factory=`list),
        clib_symbol_lib: dict[str, str] = field(default_factory=`dict),
        layout: (NativeModuleLayout | None) = None,
        deps: list[str] = field(default_factory=`list),
        coverage: dict = field(default_factory=`dict);

    def digest_fields -> dict {
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
            )
        };
    }

    def digest -> str {
        body = json.dumps(self.digest_fields(), sort_keys=True, separators=(",", ":"));
        return hashlib.sha256(body.encode("utf-8")).hexdigest();
    }

    def to_dict -> dict {
        import from jaclang.compiler.frontend.codeinfo { native_unit_ref }
        d = self.digest_fields();
        d["deps"] = [native_unit_ref(x) for x in self.deps];
        d["coverage"] = dict(self.coverage);
        return d;
    }

    def resolve_deps(anchor: str) {
        """Dependencies read from disk are references; the unit's own path
        tells where a same-package reference lives.""";
        import from jaclang.compiler.frontend.codeinfo { resolve_native_unit_ref }
        self.deps = [resolve_native_unit_ref(x, anchor) for x in self.deps];
    }

    def to_bytes -> bytes {
        body = json.dumps(self.to_dict(), sort_keys=True, separators=(",", ":"));
        return self.digest().encode("ascii") + body.encode("utf-8");
    }

    static def from_dict(d: dict) -> (NativeIface | None) {
        if not isinstance(d, dict) or d.get("format") != NIFACE_FORMAT {
            return None;
        }
        import from jaclang.compiler.frontend.codeinfo { native_layout_from_dict }
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
            coverage=dict(d.get("coverage") or {})
        );
    }

    static def from_bytes(raw: (bytes | None)) -> (NativeIface | None) {
        if raw is None or len(raw) <= NIFACE_HASH_LEN {
            return None;
        }
        try {
            return NativeIface.from_dict(
                json.loads(raw[NIFACE_HASH_LEN:].decode("utf-8"))
            );
        } except Exception {
            return None;
        }
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

    def classes_json -> dict {
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

def merge_class_layouts(ifaces: list[NativeIface]) -> dict {
    merged: dict = {};
    owner: dict[str, str] = {};
    for iface in ifaces {
        for (name, body) in iface.classes_json().items() {
            prev = merged.get(name);
            if prev is None {
                merged[name] = body;
                owner[name] = iface.module;
                continue;
            }
            if prev != body {
                raise ValueError(
                    f"native layout disagreement for class '{name}': "
                    f"{owner[name]} and {iface.module} lay it out differently"
                );
            }
        }
    }
    return merged;
}

def layout_digest(classes: dict) -> str {
    body = json.dumps(classes, sort_keys=True, separators=(",", ":"));
    return hashlib.sha256(body.encode("utf-8")).hexdigest();
}
