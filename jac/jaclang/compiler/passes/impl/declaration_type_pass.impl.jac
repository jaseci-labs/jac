impl declaration_body_roots(module: Module) -> set[int] {
    roots: set[int] = set();
    for ability in module.get_all_sub_nodes(Ability) {
        body = ability.body;
        if isinstance(body, list) {
            for stmt in body {
                roots.add(id(stmt));
            }
        }
    }
    for impl_def in module.get_all_sub_nodes(ImplDef) {
        if not isinstance(impl_def.decl_link, Ability) {
            continue;
        }
        impl_body = impl_def.body;
        if isinstance(impl_body, list) {
            for stmt in impl_body {
                roots.add(id(stmt));
            }
        } elif isinstance(impl_body, Expr) {
            roots.add(id(impl_body));
        }
    }
    for code in module.get_all_sub_nodes(ModuleCode) {
        if code.find_parent_of_type(Archetype) is None
            and code.find_parent_of_type(Enum) is None {
            roots.add(id(code));
        }
    }
    for test_block in module.get_all_sub_nodes(Test) {
        roots.add(id(test_block));
    }
    return roots;
}

impl importer_lowers_bodies(module: Module) -> bool {
    for ability in module.get_all_sub_nodes(Ability) {
        if ability.type_params or ability.is_comptime {
            return True;
        }
        sig = ability.signature;
        if isinstance(sig, FuncSignature) {
            for param in sig.get_parameters() {
                if param.is_comptime {
                    return True;
                }
            }
        }
    }
    return False;
}

impl DeclarationTypePass.prepare with entry {
    if self.ctx.nested_depth {
        return;
    }
    self._bodies = declaration_body_roots(self.module);
    self._insert_builtin_symbols();
    self._install_client_state_setters();
}

impl DeclarationTypePass.finish with exit {
    self._flush_immutable_writes();
    if self.ctx.nested_depth {
        return;
    }
    self._stamp_fixed_width();
}

impl DeclarationTypePass.enter_walk with UniNode entry {
    if id(here) in self._bodies {
        osp_skip_rest();
        return;
    }
    self.ctx.enter_node(here);
}

impl DeclarationTypePass.exit_walk with UniNode exit {
    if id(here) in self._bodies {
        osp_skip_rest();
        return;
    }
    self.ctx.exit_node(here);
}

impl DeclarationTypePass._body_always_returns(body: list[CodeBlockStmt]) -> bool {
    return True;
}

impl DeclarationTypePass._stamp_fixed_width -> None {
    stack: list[UniNode] = [self.module];
    while stack {
        nd = stack.pop();
        if isinstance(nd, Expr) {
            name = numeric_name_of(nd.type);
            if name is not None and JAC_TYPE_REGISTRY.is_sized(name) {
                nd.fw = name;
                nd.fw_safe = self._provably_in_range(nd, name);
            }
        }
        for k in [nd->:Kid:->] {
            if id(k) not in self._bodies {
                stack.append(k);
            }
        }
    }
}
