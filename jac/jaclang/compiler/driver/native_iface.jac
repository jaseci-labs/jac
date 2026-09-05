"""The native interface of one unit: everything a consumer links against.

One record per native unit, written into the module's JIR as `SEC_NIFACE`
and prefixed with its 64-hex digest exactly as `SEC_IFACE` is. It replaces
the dependency IR sidecar (`DepClibMeta`), the `NativeModuleLayout` export
and the `<lib>.layout.json` sidecar with a single typed record.

Digest rules: a body edit, a renamed local or a new private helper leaves
the digest alone and rebuilds one object; adding or removing an export,
changing a signature or ownership convention, changing a layout, adding an
enum member, or gaining or losing an initializer changes it and rebuilds
dependents. Codegen options never enter the digest; the object header
carries them (see `NativeStamp` in `driver/jir.jac`).
"""
import hashlib;
import json;
import from dataclasses { field }
import from jaclang.compiler.frontend.codeinfo {
    NativeModuleLayout,
    native_layout_to_dict
}

glob NIFACE_FORMAT: int = 1,
     NIFACE_HASH_LEN: int = 64,
     EXPORT_FUNCTION: str = "function",
     EXPORT_METHOD: str = "method",
     EXPORT_GLOBAL: str = "global",
     EXPORT_STATIC: str = "static",
     EXPORT_VTABLE: str = "vtable",
     EXPORT_TEST: str = "test";

"""One external symbol a unit defines."""
obj NativeExport {
    has name: str,
        symbol: str,
        kind: str,
        is_pub: bool = False,
        param_types: list[str] = field(default_factory=`list),
        param_names: list[str] = field(default_factory=`list),
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
            ret_type=str(d.get("ret_type", "")),
            ownership=[str(x) for x in d.get("ownership", [])]
        );
    }
}

"""One field of a class layout as the C ABI sees it."""
obj NativeFieldSlot {
    has index: int,
        offset: int,
        code: str,
        aux: str = "";

    def to_dict -> dict {
        return {
            "index": self.index,
            "offset": self.offset,
            "code": self.code,
            "aux": self.aux
        };
    }

    static def from_dict(d: dict) -> NativeFieldSlot {
        return NativeFieldSlot(
            index=int(d.get("index", -1)),
            offset=int(d.get("offset", -1)),
            code=str(d.get("code", "opaque")),
            aux=str(d.get("aux", ""))
        );
    }
}

"""The layout of one archetype defined by this unit.

This is what the kernel loader registers (`native_compiler.jac`) and what a
consumer's declaration of the class must agree with.
"""
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
                str(k): NativeFieldSlot.from_dict(v)
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
        init: str = "",
        entry: str = "",
        demoted: list[str] = field(default_factory=`list),
        clib_paths: list[str] = field(default_factory=`list),
        clib_symbol_lib: dict[str, str] = field(default_factory=`dict),
        layout: (NativeModuleLayout | None) = None,
        deps: list[str] = field(default_factory=`list),
        coverage: dict = field(default_factory=`dict);

    """The fields that decide whether dependents must relink."""
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
            "init": self.init,
            "entry": self.entry,
            "demoted": sorted(self.demoted),
            "clib_paths": list(self.clib_paths),
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
        d = self.digest_fields();
        d["deps"] = list(self.deps);
        d["coverage"] = dict(self.coverage);
        return d;
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
                str(k): NativeExport.from_dict(v)
                for (k, v) in (d.get("exports") or {}).items()
            },
            classes={
                str(k): NativeClassLayout.from_dict(v)
                for (k, v) in (d.get("classes") or {}).items()
            },
            enums={
                str(k): [str(m) for m in v] for (k, v) in (d.get("enums") or {}).items()
            },
            init=str(d.get("init", "")),
            entry=str(d.get("entry", "")),
            demoted=[str(x) for x in d.get("demoted", [])],
            clib_paths=[str(x) for x in d.get("clib_paths", [])],
            clib_symbol_lib={
                str(k): str(v) for (k, v) in (d.get("clib_symbol_lib") or {}).items()
            },
            layout=(
                native_layout_from_dict(layout_d) if isinstance(layout_d, dict) else None
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
            return NativeIface.from_dict(json.loads(raw[NIFACE_HASH_LEN:].decode("utf-8")));
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

    """Symbols a shared library promises over the C ABI: the `:pub` exports."""
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

    """Every symbol this unit defines, by Jac-level name."""
    def symbol_of(name: str) -> (str | None) {
        ex = self.exports.get(name);
        return ex.symbol if ex is not None else None;
    }

    def is_demoted(name: str) -> bool {
        return name in self.demoted;
    }

    """The sidecar the kernel loader reads: class name -> jc layout."""
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

"""Merge the class layouts of several units into one sidecar, refusing a
class that two units lay out differently."""
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
