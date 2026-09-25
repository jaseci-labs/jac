import inspect;
import json;
import os;
import from pathlib { Path }
import from jaclang.compiler.frontend.constant { SymbolAccess, SymbolType }
import from jaclang.compiler.frontend.unitree { HasVar, Module, Symbol }
import from jaclang.compiler.types.types { ClassType, FunctionType, ParamKind }

glob API_FORMAT: int = 1,
     DOC_KEYS: tuple[str, ...] = ("doc", "value"),
     MODULE_DOCS: str = "module_docs",
     ARCHETYPE_KINDS: dict[SymbolType, str] = {
         SymbolType.OBJECT_ARCH: "obj",
         SymbolType.NODE_ARCH: "node",
         SymbolType.EDGE_ARCH: "edge",
         SymbolType.WALKER_ARCH: "walker",
         SymbolType.ENUM_ARCH: "enum"
     },
     PARAM_KINDS: dict[int, str] = {
         0: "positional",
         1: "normal",
         2: "varargs",
         3: "keyword",
         4: "kwargs"
     };

obj ApiError(Exception) {}

def _type_text(t: any) -> str {
    return str(t) if t is not None else "any";
}

def _is_public(name: str, sym: Symbol) -> bool {
    return not sym.imported
        and not name.startswith("_")
        and sym.access != SymbolAccess.PRIVATE;
}

def _decl_of(sym: Symbol) -> any {
    return sym.decl.name_of if sym.decl is not None else None;
}

def doc_text(nd: any) -> str {
    text = nd?.doc?.lit_value;
    return inspect.cleandoc(text) if isinstance(text, str) else "";
}

def source_text(nd: any) -> str {
    if nd is None or nd.loc is None {
        return "";
    }
    loc = nd.loc;
    return " ".join(loc.orig_src.code[loc.pos_start:loc.pos_end].split());
}

def _with_doc(desc: dict[str, any], nd: any) -> dict[str, any] {
    text = doc_text(nd);
    if text {
        desc["doc"] = text;
    }
    return desc;
}

def _param_nodes(decl: any) -> dict[str, any] {
    sig = decl?.signature;
    if sig is None or not hasattr(sig, "kwonlyargs") {
        return {};
    }
    nodes = [
        *sig.posonly_params,
        *(sig.params or []),
        *sig.kwonlyargs,
        *[
            p
            for p in (sig.varargs, sig.kwargs)
            if p is not None
        ]
    ];
    return {p.name.value: p for p in nodes};
}

def _signature(ftype: any, decl: any = None) -> dict[str, any] {
    if not isinstance(ftype, FunctionType) {
        return {"params": [], "returns": _type_text(ftype)};
    }
    nodes = _param_nodes(decl);
    params: list[dict[str, any]] = [];
    for p in ftype.parameters {
        if p.is_self or p.is_cls {
            continue;
        }
        pv = nodes.get(p.name);
        declared = pv is not None and pv.value is not None;
        param: dict[str, any] = {
            "name": p.name,
            "kind": PARAM_KINDS.get(int(p.param_kind), "normal"),
            "default": bool(p.has_default) or declared,
            "type": _type_text(p.param_type)
        };
        if declared {
            param["value"] = source_text(pv.value);
        }
        params.append(param);
    }
    return {"params": params, "returns": _type_text(ftype.return_type)};
}

def _field(sym: Symbol, mtype: any) -> dict[str, any] {
    owner = _decl_of(sym);
    has_value = isinstance(owner, HasVar) and owner.value is not None;
    out: dict[str, any] = {
        "kind": "field",
        "type": _type_text(mtype),
        "default": has_value
    };
    if has_value {
        out["value"] = source_text(owner.value);
    }
    return out;
}

def _members(sym: Symbol, evaluator: any) -> dict[str, dict[str, any]] {
    out: dict[str, dict[str, any]] = {};
    scope = sym.symbol_table;
    if scope is None {
        return out;
    }
    for (name, member) in sorted(scope.names_in_scope.items()) {
        if not _is_public(name, member) {
            continue;
        }
        mtype = evaluator.get_type_of_symbol(member);
        if member.sym_type == SymbolType.HAS_VAR {
            out[name] = _field(member, mtype);
        } elif member.sym_type in (SymbolType.ABILITY, SymbolType.METHOD) {
            decl = _decl_of(member);
            out[name] = _with_doc({"kind": "method", ** _signature(mtype, decl)}, decl);
        } elif member.sym_type == SymbolType.ENUM_MEMBER {
            out[name] = {"kind": "member"};
        }
    }
    return out;
}

def describe_symbol(sym: Symbol, evaluator: any) -> dict[str, any] | None {
    stype = sym.sym_type;
    if stype in ARCHETYPE_KINDS {
        ctype = evaluator.get_type_of_symbol(sym);
        bases: list[str] = [];
        if isinstance(ctype, ClassType) {
            for base in ctype.shared.base_classes {
                name = _type_text(base);
                if name
                    not in ("object", "Obj", "Node", "Edge", "Walker", "Archetype") {
                    bases.append(name);
                }
            }
        }
        return _with_doc(
            {
                "kind": ARCHETYPE_KINDS[stype],
                "bases": bases,
                "members": _members(sym, evaluator)
            },
            _decl_of(sym)
        );
    }
    if stype == SymbolType.ABILITY {
        decl = _decl_of(sym);
        return _with_doc(
            {
                "kind": "function",
                ** _signature(evaluator.get_type_of_symbol(sym), decl)
            },
            decl
        );
    }
    if stype in (SymbolType.VAR, SymbolType.MOD_VAR, SymbolType.IMM_VAR) {
        return {
            "kind": "global",
            "type": _type_text(evaluator.get_type_of_symbol(sym))
        };
    }
    if stype == SymbolType.TYPE {
        return {"kind": "type", "type": _type_text(evaluator.get_type_of_symbol(sym))};
    }
    return None;
}

def module_surface(mod: Module, evaluator: any) -> dict[str, dict[str, any]] {
    out: dict[str, dict[str, any]] = {};
    for (name, sym) in sorted(mod.names_in_scope.items()) {
        if not _is_public(name, sym) {
            continue;
        }
        described = describe_symbol(sym, evaluator);
        if described is not None {
            out[name] = described;
        }
    }
    return out;
}

def module_path_for(base_root: Path, module: str) -> Path | None {
    base = base_root / module.replace(".", os.sep);
    for candidate in (Path(f"{base}.jac"), base / "__init__.jac", Path(f"{base}.py")) {
        if candidate.is_file() {
            return candidate;
        }
    }
    return None;
}

def package_surface(base_root: Path, exports: list[str]) -> dict[str, any] {
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    import from jaclang.compiler.driver.compilation_context { compilation_scope }
    import from jaclang.compiler.driver.program { JacProgram }
    program = JacProgram();
    modules: dict[str, any] = {};
    module_docs: dict[str, str] = {};
    missing: list[str] = [];
    for module in sorted(set(exports)) {
        path = module_path_for(base_root, module);
        if path is None {
            missing.append(module);
            continue;
        }
        options = CompileOptions(
            no_cgen=True, force_target_program=True, project_root=str(base_root)
        );
        with compilation_scope(options) {
            mod = program.compile(str(path), options=options);
        }
        modules[module] = module_surface(mod, program.get_type_evaluator());
        text = doc_text(mod);
        if text {
            module_docs[module] = text;
        }
    }
    if missing {
        raise ApiError(
            "exported module(s) not found in the package: " + ", ".join(missing)
        );
    }
    surface: dict[str, any] = {"format": API_FORMAT, "modules": modules};
    if module_docs {
        surface[MODULE_DOCS] = module_docs;
    }
    return surface;
}

def _undocumented(desc: dict[str, any]) -> dict[str, any] {
    out = {
        k: v
        for (k, v) in desc.items()
        if k not in DOC_KEYS
    };
    if isinstance(out.get("params"), list) {
        out["params"] = [
            {
                k: v
                for (k, v) in p.items()
                if k not in DOC_KEYS
            } for p in out["params"]
        ];
    }
    if isinstance(out.get("members"), dict) {
        out["members"] = {
            name: _undocumented(m) for (name, m) in out["members"].items()
        };
    }
    return out;
}

def api_shape(surface: dict[str, any]) -> dict[str, any] {
    out = {
        k: v
        for (k, v) in surface.items()
        if k not in (MODULE_DOCS, "modules")
    };
    out["modules"] = {
        module: {name: _undocumented(d) for (name, d) in symbols.items()}
        for (module, symbols) in surface.get("modules", {}).items()
    };
    return out;
}

def surface_digest(surface: dict[str, any]) -> str {
    import hashlib;
    return "sha256:"
        + hashlib.sha256(
            json.dumps(
                api_shape(surface), sort_keys=True, separators=(",", ":")
            ).encode()
        ).hexdigest();
}
