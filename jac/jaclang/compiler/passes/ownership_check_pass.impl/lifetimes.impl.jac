import from jaclang.compiler.types.types { ClassType, FunctionType }
import from jaclang.compiler.types.type_utils { lookup_symtab }
import from jaclang.compiler.frontend.diagnostics { E1320 }

impl OwnershipCheckPass._lifetime_call_args(call: FuncCall) -> list[Expr | None] {
    fn = call.target.type;
    if not isinstance(fn, FunctionType) {
        return [];
    }
    result: list[Expr | None] = [None for p in fn.parameters];
    position = 0;
    if fn.parameters
        and fn.parameters[0].is_self
        and isinstance(call.target, AtomTrailer)
        and call.target.is_attr {
        result[0] = call.target.target;
        position = 1;
    }
    for argument in self._call_params(call) {
        if isinstance(argument, KWPair) {
            if argument.key is not None {
                for (index, parameter) in enumerate(fn.parameters) {
                    if parameter.name == argument.key.sym_name {
                        result[index] = argument.value;
                        break;
                    }
                }
            }
        } elif position < len(result) {
            result[position] = argument;
            position += 1;
        }
    }
    return result;
}

impl OwnershipCheckPass._lifetime_expr_owners(expr: Expr | None) -> list[SymId] {
    if isinstance(expr, UnaryExpr) {
        if is_borrow_kind(expr.ownership) {
            place = self._place_of(expr.operand);
            if place is not None and place.sym is not None {
                return [self._name_sym_id(place)];
            }
        }
        return self._lifetime_expr_owners(expr.operand);
    }
    if isinstance(expr, FuncCall) {
        fn = expr.target.type;
        if isinstance(fn, FunctionType) and fn.return_sources {
            arguments = self._lifetime_call_args(expr);
            owners: list[SymId] = [];
            for index in fn.return_sources {
                if index < len(arguments) {
                    place = self._place_of(arguments[index]);
                    if place is not None and place.sym is not None {
                        sid = self._name_sym_id(place);
                        if sid not in owners {
                            owners.append(sid);
                        }
                    } else {
                        for sid in self._lifetime_expr_owners(arguments[index]) {
                            if sid not in owners {
                                owners.append(sid);
                            }
                        }
                    }
                }
            }
            return owners;
        }
        return [];
    }
    place = self._place_of(expr);
    if place is not None and place.sym is not None {
        sid = self._name_sym_id(place);
        if sid in self.borrow_meta {
            owners = self._borrow_owners_of(sid);
            if owners {
                return owners;
            }
        }
        if is_borrow_kind(place.sym.ownership) {
            return [sid];
        }
    }
    return [];
}

impl OwnershipCheckPass._stamp_lifetime_dependencies -> None {
    scopes: list[Ability | LambdaExpr] = [scope for scope in self.ir_in.get_all_sub_nodes(Ability)];
    scopes.extend(self.ir_in.get_all_sub_nodes(LambdaExpr));
    for scope in scopes {
        fn = scope.name_spec.type if isinstance(scope, Ability)
            else self.prog.get_type_evaluator().get_type_of_expression(scope);
        signature = scope.signature;
        if not isinstance(fn, FunctionType)
            or not isinstance(signature, FuncSignature) {
            continue;
        }
        parameters = signature.get_parameters();
        for (index, parameter) in enumerate(fn.parameters) {
            if not parameter.lifetime_sources or index >= len(parameters) {
                continue;
            }
            name = parameters[index].name;
            if not isinstance(name, Name) or name.sym is None {
                continue;
            }
            owners: list[SymId] = [];
            for source in parameter.lifetime_sources {
                source_name = parameters[source].name;
                if isinstance(source_name, Name) and source_name.sym is not None {
                    owners.append(self._name_sym_id(source_name));
                }
            }
            if owners {
                sid = self._name_sym_id(name);
                meta = BorrowMeta(name=name.sym_name, owner=owners[0]);
                meta.extra_owners = owners[1:];
                self.borrow_meta[sid] = meta;
                self.borrow_created_at[sid] = parameters[index];
                self.view_syms.add(sid);
                self.dependent_syms.add(sid);
            }
        }
    }
    for assignment in self.idx_assignments {
        if len(assignment.target) != 1 or assignment.aug_op is not None {
            continue;
        }
        name = assignment.target[0];
        if not isinstance(name, Name) or name.sym is None {
            continue;
        }
        owners = self._lifetime_expr_owners(assignment.value);
        annotation = assignment.type_tag.tag if assignment.type_tag else None;
        if isinstance(annotation, UnaryExpr) and annotation.lifetime_sources {
            for source in annotation.lifetime_sources {
                found = lookup_symtab(name.sym_tab, source, None);
                if found is None {
                    self.emit(
                        E1320,
                        node_override=annotation,
                        reason="unknown owner '" + source + "'"
                    );
                } elif id(found) not in owners {
                    self.emit(
                        E1320,
                        node_override=annotation,
                        reason="initializer does not depend on '" + source + "'"
                    );
                }
            }
        }
        if not owners {
            continue;
        }
        sid = self._name_sym_id(name);
        meta = BorrowMeta(
            name=name.sym_name, owner=owners[0], is_mut=is_mut_kind(name.sym.ownership)
        );
        meta.extra_owners = owners[1:];
        self.borrow_meta[sid] = meta;
        self.borrow_created_at[sid] = assignment;
        self.view_syms.add(sid);
        self.dependent_syms.add(sid);
    }
}

impl OwnershipCheckPass._lifetime_cotransfer(
    cfg: UniCFGNode, dependent: SymId, owner: SymId
) -> bool {
    for call in cfg.get_all_sub_nodes(FuncCall) {
        if self._cfg_owner(call) is not cfg {
            continue;
        }
        fn = call.target.type;
        if not isinstance(fn, FunctionType) {
            continue;
        }
        arguments = self._lifetime_call_args(call);
        for (index, parameter) in enumerate(fn.parameters) {
            if parameter.ownership != OwnershipKind.OWN
                or index >= len(arguments)
                or self._owned_sym_of(arguments[index]) != dependent {
                continue;
            }
            for source in parameter.lifetime_sources {
                if source < len(arguments)
                    and fn.parameters[source].ownership == OwnershipKind.OWN
                    and self._owned_sym_of(arguments[source]) == owner {
                    return True;
                }
            }
        }
    }
    return False;
}

impl OwnershipCheckPass._emit_lifetime_diagnostics -> None {
    for ret in self.idx_returns {
        scope = self.prog.get_type_evaluator()._get_enclosing_return_scope(ret);
        if scope is None or not isinstance(scope.signature, FuncSignature) {
            continue;
        }
        fn = scope.name_spec.type if isinstance(scope, Ability)
            else self.prog.get_type_evaluator().get_type_of_expression(scope);
        if not isinstance(fn, FunctionType) {
            continue;
        }
        owners = self._lifetime_expr_owners(ret.expr);
        if not owners and not fn.return_sources {
            continue;
        }
        parameters = scope.signature.get_parameters();
        allowed: set[SymId] = set();
        for index in fn.return_sources {
            parameter = parameters[index].name;
            if isinstance(parameter, Name) and parameter.sym is not None {
                source = self._name_sym_id(parameter);
                allowed.add(source);
                allowed.update(self._borrow_owners_of(source));
            }
        }

        if not fn.return_sources and fn.return_ownership != OwnershipKind.OWN {
            candidates = [
                p
                for p in parameters
                if p.type_tag and is_borrow_kind(p.type_tag.ownership)
            ];
            if len(candidates) == 1 and isinstance(candidates[0].name, Name) {
                allowed.add(self._name_sym_id(candidates[0].name));
            }
        }
        for owner in owners {
            roots = self._borrow_owners_of(owner) or [owner];
            # A dependency does not replace the lifetime of the release
            # obligation itself. Borrowing an owned cursor still needs that
            # cursor, even when the cursor also depends on a connection.
            if owner in self.owned_decl and owner not in roots {
                roots.insert(0, owner);
            }
            if not all(source in allowed for source in roots) {
                self.emit(
                    E1320,
                    node_override=ret,
                    reason="returned value depends on an owner absent from the return contract"
                );
                break;
            }
        }
        for index in fn.return_sources {
            if fn.parameters[index].ownership == OwnershipKind.OWN {
                self.emit(
                    E1320,
                    node_override=ret,
                    reason="a returned value cannot depend on a parameter destroyed when the function returns"
                );
            }
        }
    }
    for call in self.ir_in.get_all_sub_nodes(FuncCall) {
        fn = call.target.type;
        if not isinstance(fn, FunctionType) {
            continue;
        }
        arguments = self._lifetime_call_args(call);
        for (index, parameter) in enumerate(fn.parameters) {
            if index >= len(arguments) {
                continue;
            }
            actual = self._lifetime_expr_owners(arguments[index]);
            expected: set[SymId] = set();
            for source in parameter.lifetime_sources {
                if source < len(arguments) {
                    place = self._place_of(arguments[source]);
                    if place is not None and place.sym is not None {
                        expected.add(self._name_sym_id(place));
                    }
                }
            }
            cleanup = False;
            resource_type = parameter.param_type;
            if index == 0 and len(fn.parameters) == 1
                and isinstance(resource_type, ClassType)
                and resource_type.shared.foreign_resource is not None {
                # A declared destructor discharges the obligation before it
                # returns. Its owner's dependencies stay live through the call;
                # they are not transferred into independently owned storage.
                resource = resource_type.shared.foreign_resource;
                drop_symbol = lookup_symtab(resource_type.shared.symbol_table, resource[2], None);
                import from jaclang.compiler.symbol_utils { resolved_callee }
                cleanup = drop_symbol is not None and drop_symbol.decl is not None
                    and resolved_callee(call) is drop_symbol.decl.name_of;
            }
            if parameter.ownership == OwnershipKind.OWN
                and actual
                and not cleanup
                and not all(owner in expected for owner in actual) {
                self.emit(
                    E1320,
                    node_override=call,
                    reason="consuming parameter '"
                        + parameter.name
                        + "' would erase a lifetime dependency"
                );
            }
        }
    }
}


impl OwnershipCheckPass._call_consumes_arg(call: FuncCall, arg: Expr | None) -> bool {
    fn = call.target.type;
    if isinstance(fn, FunctionType) {
        arguments = self._lifetime_call_args(call);
        for (index, actual) in enumerate(arguments) {
            if actual is arg and fn.parameters[index].ownership != OwnershipKind.NONE {
                return fn.parameters[index].ownership == OwnershipKind.OWN;
            }
        }
    }
    return self._call_consumes_args(call);
}


impl OwnershipCheckPass._stamp_dependency_cleanup_order -> None {
    self.ir_in.own_dependency_order = {};
    for ability in self.ir_in.get_all_sub_nodes(Ability) {
        remaining = [
            sid
            for (sid, name) in reversed(list(self.owned_decl.items()))
            if name.find_parent_of_type(Ability) is ability
        ];
        if not any(sid in self.dependent_syms for sid in remaining) {
            continue;
        }
        order: list[str] = [];
        while remaining {
            selected: SymId | None = None;
            for sid in remaining {
                if not any(
                    sid in self._borrow_owners_of(other)
                    for other in remaining
                    if other != sid
                ) {
                    selected = sid;
                    break;
                }
            }
            if selected is None {
                self.emit(
                    E1320,
                    node_override=ability,
                    reason="cyclic ownership dependencies prevent safe cleanup"
                );
                break;
            }
            order.append(self.owned_decl[selected].sym_name);
            remaining.remove(selected);
        }
        self.ir_in.own_dependency_order[id(ability)] = order;
    }
}


impl OwnershipCheckPass._stamp_foreign_effects -> None {
    import from jaclang.compiler.frontend.diagnostics { E1321 }
    abilities = self.ir_in.get_all_sub_nodes(Ability);
    evaluator = self.prog.get_type_evaluator();
    for ability in abilities {
        evaluator.get_type_of_ability(ability);
    }
    import from jaclang.compiler.foreign_refs { is_foreign_ability }
    declared_contracts: list[tuple] = [];
    for ability in abilities {
        fn = ability.name_spec.type;
        if isinstance(fn, FunctionType) and fn.foreign_errors != "jac"
            and not is_foreign_ability(ability) {
            declared_contracts.append((ability, fn, set(fn.required_capabilities), fn.reentrant));
        }
    }
    changed = True;
    while changed {
        changed = False;
        for ability in abilities {
            fn = ability.name_spec.type;
            if not isinstance(fn, FunctionType) {
                continue;
            }
            imported = ability.find_parent_of_type(Import);
            if imported is not None and ability in imported.clib_decls {
                continue;
            }
            required = set(fn.required_capabilities);
            reentrant = fn.reentrant;
            for expression in ability.flatten() {
                if not isinstance(expression, Expr)
                    or expression.find_parent_of_type(Ability) is not ability {
                    continue;
                }
                owned = isinstance(expression, UnaryExpr)
                    and expression.ownership == OwnershipKind.OWN;
                if isinstance(expression.parent, SubTag)
                    and expression.parent.ownership == OwnershipKind.OWN {
                    owned = True;
                }
                if isinstance(expression, FuncCall)
                    and isinstance(expression.target.type, FunctionType) {
                    owned = expression.target.type.return_ownership == OwnershipKind.OWN;
                }
                resource_type = expression.type;
                if not owned or not isinstance(resource_type, ClassType) {
                    continue;
                }
                resource = resource_type.shared.foreign_resource;
                if resource is None {
                    continue;
                }
                drop_symbol = lookup_symtab(
                    resource_type.shared.symbol_table, resource[2], None
                );
                if drop_symbol is not None {
                    drop_type = evaluator.get_type_of_symbol(drop_symbol);
                    if isinstance(drop_type, FunctionType) {
                        required.update(drop_type.required_capabilities);
                        reentrant = reentrant or drop_type.reentrant;
                    }
                }
            }
            for call in ability.get_all_sub_nodes(FuncCall) {
                if call.find_parent_of_type(Ability) is not ability {
                    continue;
                }
                callee = call.target.type;
                if isinstance(callee, FunctionType) {
                    required.update(callee.required_capabilities);
                    reentrant = reentrant or callee.reentrant;
                }
            }
            if required != set(fn.required_capabilities) or reentrant != fn.reentrant {
                fn.required_capabilities = sorted(required);
                fn.reentrant = reentrant;
                changed = True;
            }
        }
    }
    for (ability, fn, required, reentrant) in declared_contracts {
        if not set(fn.required_capabilities).issubset(required) {
            self.emit(E1321, node_override=ability,
                reason="native foreign_call body requires undeclared capabilities");
        }
        if fn.reentrant and not reentrant {
            self.emit(E1321, node_override=ability,
                reason="native foreign_call body can reenter through a call or cleanup");
        }
    }
    for call in self.ir_in.get_all_sub_nodes(FuncCall) {
        fn = call.target.type;
        if not isinstance(fn, FunctionType) or "gil" not in fn.required_capabilities {
            continue;
        }
        if call.find_parent_of_type(ConcurrentExpr) is not None {
            self.emit(
                E1321,
                node_override=call,
                reason="a GIL-requiring call cannot cross a native task boundary"
            );
        }
        loop = call.find_parent_of_type(InForStmt);
        while loop is not None {
            if any(
                isinstance(kid, Token) and kid.name == Tok.KW_FLOW for kid in loop.kid
            ) {
                self.emit(
                    E1321,
                    node_override=call,
                    reason="a GIL-requiring call cannot run in flow for"
                );
                break;
            }
            loop = loop.find_parent_of_type(InForStmt);
        }
    }
}
