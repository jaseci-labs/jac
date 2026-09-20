import jaclang.compiler.frontend.unitree as uni;

obj NativePythonImport {
    has module: str,
        binding: str,
        attribute: str = "",
        bind_module: str = "";
}

obj NativePythonImports {
    has symbols: dict[int, NativePythonImport] = {},
        statements: dict[int, NativePythonImport] = {},
        module_bindings: set[tuple[int, str]] = set(),
        local_bindings: dict[int, list[NativePythonImport]] = {},
        module_statements: list[uni.UniNode] = [];

    def plan_globals(module: uni.Module) {
        import from jaclang.compiler.frontend.module_facts { ModuleFacts }
        import from jaclang.compiler.frontend.constant { CodeContext }
        if not self.symbols {
            return;
        }
        for statement in ModuleFacts.iter_context_stmts(module, CodeContext.NATIVE) {
            if isinstance(statement, uni.Import) {
                if any(id(item) in self.statements for item in statement.items) {
                    self.module_statements.append(statement);
                }
            } elif isinstance(statement, uni.GlobalVars) {
                for assignment in statement.assignments {
                    if ModuleFacts.is_erased_type_decl(assignment) {
                        continue;
                    }
                    self.module_statements.append(assignment);
                    self.plan_assignment(assignment);
                }
            } elif isinstance(statement, uni.ModuleCode) {
                for assignment in statement.get_all_sub_nodes(uni.Assignment) {
                    self.plan_assignment(assignment);
                }
            }
        }
    }

    def plan_assignment(assignment: uni.Assignment) {
        import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
        annotation = assignment.type_tag.tag if assignment.type_tag else None;
        native_scalar = isinstance(annotation, (uni.Name, uni.BuiltinType))
            and (
                annotation.value in {"int", "float", "bool", "str", "bytes"}
                or JAC_TYPE_REGISTRY.is_sized(annotation.value)
            );
        if native_scalar
            or assignment.value is None
            or not python_object_expression(assignment.value) {
            return;
        }
        for target in assignment.target {
            if isinstance(target, uni.Name)
                and target.sym is not None
                and target.sym.storage == uni.SymbolStorage.MODULE_GLOBAL {
                self.module_bindings.add((id(target.sym), target.value));
            }
        }
    }

    def register(item: uni.UniNode, binding: NativePythonImport, module_level: bool) {
        symbol = python_import_symbol(item);
        if symbol is None {
            return;
        }
        self.symbols[id(symbol)] = binding;
        self.statements[id(item)] = binding;
        if module_level {
            self.module_bindings.add((id(symbol), binding.binding));
        } else {
            owner = item.parent;
            while owner is not None
                and not isinstance(owner, (uni.Ability, uni.ImplDef)) {
                owner = owner.parent;
            }
            if owner is not None {
                self.local_bindings.setdefault(id(owner), []).append(binding);
            }
        }
    }
}

def python_import_symbol(item: uni.UniNode) -> uni.Symbol | None {
    if isinstance(item, uni.ModuleItem) {
        bound = item.binding_name;
        return bound.sym if bound is not None else None;
    }
    if isinstance(item, uni.ModulePath) {
        if item.alias is not None {
            return item.alias.sym;
        }
        if item.path and isinstance(item.path[0], uni.Name) {
            return item.path[0].sym;
        }
    }
    return None;
}

def python_object_expression(nd: uni.UniNode, seen: set[int] | None = None) -> bool {
    import os;
    if seen is None {
        seen = set();
    }
    if id(nd) in seen {
        return False;
    }
    seen.add(id(nd));
    if isinstance(nd, uni.CfgExpr) {
        return python_object_expression(nd.expr, seen);
    }
    if isinstance(nd, uni.AtomUnit) {
        return python_object_expression(nd.value, seen);
    }
    if isinstance(nd, uni.FuncCall) {
        if python_object_expression(nd.target, seen) {
            return True;
        }
        import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
        return nd.call_kind == "builtin"
            and isinstance(nd.target, uni.Name)
            and not JAC_TYPE_REGISTRY.is_sized(nd.target.value)
            and any(
                python_object_expression(
                    param.value if isinstance(param, uni.KWPair) else param, seen
                ) for param in (nd.params or [])
            );
    }
    if isinstance(nd, uni.AtomTrailer) {
        return python_object_expression(nd.target, seen);
    }
    if isinstance(nd, uni.BinaryExpr) {
        return python_object_expression(nd.left, seen)
            or python_object_expression(nd.right, seen);
    }
    if not isinstance(nd, uni.Name) or nd.sym is None or nd.sym.decl is None {
        return False;
    }
    if nd.sym.imported or nd.sym.in_stub_scope() {
        module = nd.find_parent_of_type(uni.Module);
        if module is not None {
            base = os.path.dirname(os.path.abspath(module.loc.mod_path));
            for statement in module.get_all_sub_nodes(uni.Import) {
                for item in statement.items {
                    if python_import_symbol(item) is nd.sym {
                        if python_import_binding(item, base) is not None {
                            return True;
                        }
                    }
                }
            }
        }
    }
    declaration = nd.sym.decl;
    owner: uni.UniNode | None = declaration;
    while owner is not None {
        if isinstance(owner, (uni.ModulePath, uni.ModuleItem)) {
            base = os.path.dirname(os.path.abspath(owner.loc.mod_path));
            return python_import_binding(owner, base) is not None;
        }
        if isinstance(owner, uni.Assignment) {
            return owner.value is not None
                and python_object_expression(owner.value, seen);
        }
        if isinstance(owner, uni.InForStmt) {
            return python_object_expression(owner.collection, seen);
        }
        if isinstance(owner, (uni.Ability, uni.ParamVar, uni.HasVar, uni.Module)) {
            break;
        }
        owner = owner.parent;
    }
    return False;
}

def python_import_binding(
    item: uni.UniNode, base_dir: str
) -> NativePythonImport | None {
    import from jaclang.compiler.passes.capability_check_pass {
        classify_native_import,
        import_bound_name,
        from_import_jac_source
    }
    import from jaclang.compiler.frontend.codeinfo { resolve_native_module }
    (module, supported) = classify_native_import(item);
    if module is None or supported {
        return None;
    }
    owner = item.parent;
    if not isinstance(owner, uni.Import)
        or owner.clib_decls
        or owner.is_absorb
        or owner.is_typed
        or owner.is_comptime {
        return None;
    }
    if resolve_native_module(module, base_dir)[1] is not None {
        return None;
    }
    if isinstance(item, uni.ModuleItem) and from_import_jac_source(owner) is not None {
        return None;
    }
    binding = import_bound_name(item);
    if binding is None {
        return None;
    }
    attribute = item.name.value if isinstance(item, uni.ModuleItem) else "";
    bind_module = module;
    if isinstance(item, uni.ModulePath) and item.alias is None {
        bind_module = module.split(".")[0];
    }
    return NativePythonImport(
        module=module, binding=binding, attribute=attribute, bind_module=bind_module
    );
}
