import from jaclang.compiler.frontend.unitree { Ability, FuncSignature, UnaryExpr }
import from jaclang.compiler.frontend.constant { OwnershipKind }

def value_contract(
    expr: any, ownership: OwnershipKind = OwnershipKind.NONE, host: bool = False
) -> dict {
    if isinstance(expr, UnaryExpr) and expr.ownership != OwnershipKind.NONE {
        ownership = expr.ownership;
        expr = expr.operand;
    }
    import from jaclang.compiler.tools.unparse_pass { unparse_node }
    name = unparse_node(expr).strip() if expr is not None else "None";
    mode = {
        OwnershipKind.NONE: "value",
        OwnershipKind.OWN: "own",
        OwnershipKind.BORROW: "borrow",
        OwnershipKind.MUT_BORROW: "borrow_mut",
        OwnershipKind.IMM: "borrow"
    }[ownership];
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    shape = JAC_TYPE_REGISTRY.shape_of(name);
    if host and name == "str" {
        return {"type": name, "mode": mode, "kind": "cstring"};
    }
    if name == "None" {
        return {"type": name, "mode": mode, "kind": "scalar"};
    }
    if shape is not None {
        value = {
            "type": name,
            "mode": mode,
            "kind": "scalar",
            "bits": shape.width,
            "signed": shape.signed,
            "numeric": "float" if shape.is_float else "int"
        };
        if not shape.is_float {
            import from jaclang.runtime.scalars { ScalarShape, shape_range }
            limits = shape_range(
                ScalarShape(
                    name=shape.name, width=shape.width, signed=shape.signed, sized=True
                )
            );
            value["minimum"] = str(limits[0]);
            value["maximum"] = str(limits[1]);
        }
        return value;
    }
    if mode == "value" {
        raise ValueError(
            f"Wasm boundary type '{name}' requires an explicit ownership contract"
        );
    }
    return {"type": name, "mode": mode, "kind": "handle"};
}

def function_contract(decl: Ability, host: bool = False) -> dict {
    sig = decl.signature;
    if not isinstance(sig, FuncSignature) {
        raise ValueError("Wasm exports require a function signature");
    }
    params: list[dict] = [];
    for p in sig.get_parameters() {
        if p.type_tag is None {
            raise ValueError(f"Wasm parameter '{p.sym_name}' requires a type");
        }
        value = value_contract(p.type_tag.tag, p.type_tag.ownership, host);
        value["name"] = p.sym_name;
        params.append(value);
    }
    return {"params": params, "result": value_contract(sig.return_type, host=host)};
}


def host_contracts(module: any) -> dict {
    import from jaclang.compiler.frontend.unitree { Import }
    import from jaclang.compiler.driver.boundary_classify {
        symbol_linked_source_module
    }
    import from jaclang.compiler.passes.boundary_analysis_pass {
        _parse_module_for_types
    }
    visited: set[str] = set();
    todo = [module];
    contracts: dict = {};
    while todo {
        current = todo.pop();
        if current is None or current.loc.mod_path in visited {
            continue;
        }
        visited.add(current.loc.mod_path);
        for imp in current.get_all_sub_nodes(Import) {
            if imp.has_clib_decls {
                for decl in imp.get_all_sub_nodes(Ability) {
                    contracts[decl.sym_name] = function_contract(decl, host=True);
                }
            } elif imp.from_loc is not None {
                linked = symbol_linked_source_module(imp);
                if linked is None {
                    path = imp.from_loc.resolve_relative_path();
                    if path.endswith(".jac") {
                        linked = _parse_module_for_types(path);
                    }
                }
                if linked is not None {
                    todo.append(linked);
                }
            }
        }
    }
    return contracts;
}

def _host_type(name: str) -> str {
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    shape = JAC_TYPE_REGISTRY.shape_of(name);
    if shape is not None and shape.sized {
        return "float" if shape.is_float else "int";
    }
    return name;
}

def check_host_call(call: any) -> None {
    import from jaclang.compiler.frontend.unitree {
        Name,
        Module,
        Archetype,
        ability_of_symbol
    }
    if not isinstance(call.target, Name) or call.target.value != "bind_na_host" {
        return;
    }
    target = ability_of_symbol(call.target.sym);
    if target is None
        or not target.loc.mod_path.replace("\\", "/").endswith(
            "/client/wasm_host.jac"
        ) {
        return;
    }
    if not call.params or len(call.params) != 2 {
        raise ValueError("bind_na_host requires a native export and a typed host");
    }
    export = call.params[0];
    provider = ability_of_symbol(export.sym) if isinstance(export, Name) else None;
    import from jaclang.compiler.types.types { ClassType }
    host = call.params[1];
    host_type = host.narrowed_type or host.type;
    scope = host_type.shared.symbol_table if isinstance(host_type, ClassType) else None;
    if provider is None or scope is None {
        raise ValueError(
            "Host binding requires statically known export and host types"
        );
    }
    methods: dict = {};
    todo = [scope];
    seen: set[int] = set();
    while todo {
        current = todo.pop();
        if id(current) in seen {
            continue;
        }
        seen.add(id(current));
        for method in current.get_all_sub_nodes(Ability) {
            if method.sym_name not in methods {
                methods[method.sym_name] = method;
            }
        }
        if isinstance(current, Archetype) {
            for base in current.base_classes or [] {
                base_type = base.type;
                if isinstance(base_type, ClassType) {
                    todo.append(base_type.shared.symbol_table);
                }
            }
        }
    }
    for (name, required) in host_contracts(
        provider.find_parent_of_type(Module)
    ).items() {
        if name not in methods {
            raise ValueError(f"Host is missing native import '{name}'");
        }
        supplied = function_contract(methods[name], host=True);
        expected = [_host_type(p["type"]) for p in required["params"]];
        actual = [p["type"] for p in supplied["params"]];
        if expected != actual
            or _host_type(required["result"]["type"]) != supplied["result"]["type"] {
            raise ValueError(
                f"Host import '{name}' has incompatible signature: expected {expected} -> {_host_type(
                    required['result']['type']
                )}"
            );
        }
    }
}
