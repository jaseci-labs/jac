impl WasmValueContract.to_dict -> dict[str, any] {
    out: dict[str, any] = {
        "type": self.type_name,
        "mode": self.mode,
        "kind": self.kind
    };
    if self.bits {
        out["bits"] = self.bits;
        out["signed"] = self.signed;
        out["numeric"] = "float" if self.is_float else "int";
        if not self.is_float {
            out["minimum"] = self.minimum;
            out["maximum"] = self.maximum;
        }
    }
    if self.name {
        out["name"] = self.name;
    }
    return out;
}

impl WasmFunctionContract.to_dict -> dict[str, any] {
    return {
        "params": [p.to_dict() for p in self.params],
        "result": self.result.to_dict()
    };
}

impl _ownership_mode(ownership: OwnershipKind) -> str {
    if ownership == OwnershipKind.OWN {
        return "own";
    }
    if ownership == OwnershipKind.MUT_BORROW {
        return "borrow_mut";
    }
    if ownership == OwnershipKind.BORROW or ownership == OwnershipKind.IMM {
        return "borrow";
    }
    return "value";
}

impl value_contract(
    expr: (Expr | None),
    ownership: OwnershipKind = OwnershipKind.NONE,
    host: bool = False
) -> WasmValueContract {
    if isinstance(expr, UnaryExpr) and expr.ownership != OwnershipKind.NONE {
        ownership = expr.ownership;
        expr = expr.operand;
    }

    name = unparse_node(expr).strip() if expr is not None else "None";
    mode = _ownership_mode(ownership);

    shape = JAC_TYPE_REGISTRY.shape_of(name);
    if host and name == "str" {
        return WasmValueContract(type_name=name, mode=mode, kind="cstring");
    }
    if name == "None" {
        return WasmValueContract(type_name=name, mode=mode, kind="scalar");
    }
    if shape is not None {
        value = WasmValueContract(
            type_name=name,
            mode=mode,
            kind="scalar",
            bits=shape.width,
            signed=shape.signed,
            is_float=shape.is_float
        );
        if not shape.is_float and not shape.signed and shape.width == 64 {
            value.minimum = "0";
            value.maximum = U64_MAX_TEXT;
        } elif not shape.is_float {
            import from jaclang.runtime.scalars { ScalarShape, shape_range }
            limits = shape_range(
                ScalarShape(
                    name=shape.name, width=shape.width, signed=shape.signed, sized=True
                )
            );
            value.minimum = str(limits[0]);
            value.maximum = str(limits[1]);
        }
        return value;
    }
    if mode == "value" {
        raise ValueError(
            f"Wasm boundary type '{name}' requires an explicit ownership contract"
        );
    }
    return WasmValueContract(type_name=name, mode=mode, kind="handle");
}

impl function_contract(decl: Ability, host: bool = False) -> WasmFunctionContract {
    sig = decl.signature;
    if not isinstance(sig, FuncSignature) {
        raise ValueError("Wasm exports require a function signature");
    }
    params: list[WasmValueContract] = [];
    for p in sig.get_parameters() {
        tag = p.type_tag;
        if tag is None {
            raise ValueError(f"Wasm parameter '{p.sym_name}' requires a type");
        }
        value = value_contract(tag.tag, tag.ownership, host);
        value.name = p.sym_name;
        params.append(value);
    }
    return WasmFunctionContract(
        params=params, result=value_contract(sig.return_type, host=host)
    );
}

impl host_contracts(
    module: (Module | None), program: JacProgram
) -> dict[str, WasmFunctionContract] {
    visited: set[str] = set();
    todo: list[Module | None] = [module];
    contracts: dict[str, WasmFunctionContract] = {};
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
                        linked = program.load_dependency_module(path, need_tree=True);
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

impl host_contract_dicts(
    module: (Module | None), program: JacProgram
) -> dict[str, dict[str, any]] {
    return {
        name: contract.to_dict()
        for (name, contract) in host_contracts(module, program).items()
    };
}

impl _host_type(name: str) -> str {
    shape = JAC_TYPE_REGISTRY.shape_of(name);
    if shape is not None and shape.sized {
        return "float" if shape.is_float else "int";
    }
    return name;
}

impl _host_export(export: Expr | KWPair, program: JacProgram) -> (Ability | None) {
    if not isinstance(export, Name) or export.sym is None {
        return None;
    }
    found = ability_of_symbol(export.sym);
    if found is not None {
        return found;
    }
    decl = resolved_decl_of(export.sym);
    if decl is not None and isinstance(decl.parent, Ability) {
        return decl.parent;
    }
    items: list[ModuleItem] = [];
    for link in import_chain_of(export.sym) {
        if isinstance(link.decl.parent, ModuleItem) {
            items.append(link.decl.parent);
        }
    }
    consumer = export.find_parent_of_type(Module);
    if consumer is not None {
        for item in consumer.get_all_sub_nodes(ModuleItem) {
            bound = item.alias.value if item.alias is not None else item.name.value;
            if bound == export.value {
                items.append(item);
            }
        }
    }
    for item in items {
        imp = item.find_parent_of_type(Import);
        if imp is None or imp.from_loc is None {
            continue;
        }
        path = imp.from_loc.resolve_relative_path();
        if not path.endswith(".jac") {
            continue;
        }
        provider_module = program.load_dependency_module(path, need_tree=True);
        if provider_module is None {
            continue;
        }
        for ab in provider_module.get_all_sub_nodes(Ability) {
            if ab.sym_name == item.name.value
                and ab.enclosing_decl(Archetype) is None {
                return ab;
            }
        }
    }
    return None;
}

impl check_host_call(call: FuncCall, program: JacProgram) -> None {
    callee = call.target;
    if not isinstance(callee, Name) or callee.value != "bind_na_host" {
        return;
    }
    target = ability_of_symbol(callee.sym);
    bound = callee.sym;
    target_path = (
        target.loc.mod_path
            if target is not None
            else (bound.decl.loc.mod_path if bound is not None else "")
    );
    if not target_path.replace("\\", "/").endswith("/client/wasm_host.jac") {
        return;
    }
    args = call.params;
    if not args or len(args) != 2 {
        raise ValueError("bind_na_host requires a native export and a typed host");
    }
    export = args[0];
    provider = _host_export(export, program);

    host = args[1];
    host_type = (host.narrowed_type or host.type) if isinstance(host, Expr) else None;
    if provider is None or not isinstance(host_type, ClassType) {
        raise ValueError(
            "Host binding requires statically known export and host types"
        );
    }
    evaluator = program.get_type_evaluator();
    for (name, required) in host_contracts(
        provider.find_parent_of_type(Module), program
    ).items() {
        member = evaluator._lookup_class_member(host_type, name);
        if member is None {
            raise ValueError(f"Host is missing native import '{name}'");
        }
        supplied = evaluator.get_type_of_member(member, host_type);
        if not isinstance(supplied, FunctionType) {
            raise ValueError(f"Host import '{name}' must be a function");
        }
        expected = [_host_type(p.type_name) for p in required.params];
        expected_return = _host_type(required.result.type_name);
        if expected_return == "None" {
            expected_return = "NoneType";
        }
        actual = [
            str(p.param_type)
            for p in supplied.parameters
            if not p.is_self and not p.is_cls
        ];
        if expected != actual or expected_return != str(supplied.return_type) {
            raise ValueError(
                f"Host import '{name}' has incompatible signature: expected {expected} -> {_host_type(
                    required.result.type_name
                )}"
            );
        }
    }
}
