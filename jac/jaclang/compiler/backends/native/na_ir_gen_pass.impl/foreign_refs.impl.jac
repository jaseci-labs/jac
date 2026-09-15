import from jaclang.compiler.foreign_refs {
    foreign_resource_name,
    contains_foreign_resource,
    borrowed_return_source
}

impl NaIRGenPass._foreign_resource_exprs(origin: uni.UniNode) -> list[uni.Expr] {
    pending: list[uni.UniNode] = [origin];
    if isinstance(origin, uni.Ability) {
        pending.extend(ModuleFacts.unwrap_body(origin) or []);
    }
    seen: set[int] = set();
    expressions: list[uni.Expr] = [];
    while pending {
        current = pending.pop();
        if id(current) in seen {
            continue;
        }
        seen.add(id(current));
        pending.extend(current.kid);
        if isinstance(current, uni.Expr) {
            expressions.append(current);
        }
    }
    return expressions;
}

impl NaIRGenPass._record_foreign_requirement(
    func: ir.Function, decl: uni.Ability
) -> None {
    for expr in self._foreign_resource_exprs(decl) {
        if foreign_resource_name(expr.type) is not None {
            self._foreign_required_functions[func] = decl;
            return;
        }
    }
}

impl NaIRGenPass._validate_foreign_resources -> None {
    for expr in self._foreign_resource_exprs(self.ir_in) {
        typ = expr.type;
        if isinstance(typ, SemanticFunctionType) {
            for param in typ.parameters {
                if foreign_resource_name(param.param_type) is not None
                    and param.ownership
                        not in (OwnershipKind.OWN, OwnershipKind.BORROW) {
                    self.emit(
                        E5120,
                        node_override=expr,
                        reason="foreign callable parameters require own or a shared borrow"
                    );
                }
            }
            if foreign_resource_name(typ.return_type) is not None
                and typ.return_ownership != OwnershipKind.OWN {
                declaration: uni.Ability | None = None;
                if isinstance(expr, uni.NameAtom)
                    and expr.sym is not None
                    and expr.sym.decl is not None
                    and isinstance(expr.sym.decl.name_of, uni.Ability) {
                    declaration = expr.sym.decl.name_of;
                }
                if not (typ.return_ownership == OwnershipKind.BORROW and typ.return_sources)
                    and borrowed_return_source(declaration) is None {
                    self.emit(
                        E5120,
                        node_override=expr,
                        reason="foreign callable returns require an owned result or a trusted loan contract"
                    );
                }
            }
        }
        callable_annotation = False;
        ancestor: uni.UniNode | None = expr;
        while ancestor is not None {
            if isinstance(ancestor, uni.Expr)
                and isinstance(ancestor.type, SemanticFunctionType)
                and not isinstance(ancestor, uni.FuncCall) {
                callable_annotation = True;
                break;
            }
            if isinstance(ancestor, (uni.Ability, uni.Assignment, uni.FuncCall)) {
                break;
            }
            ancestor = ancestor.parent;
        }
        if isinstance(typ, ClassType) and not callable_annotation {
            for arg in (typ.private.type_args or []) {
                if contains_foreign_resource(arg) {
                    self.emit(
                        E5120,
                        node_override=expr,
                        reason="foreign resources cannot be stored in Jac containers"
                    );
                }
            }
        }
        if foreign_resource_name(typ) is None {
            continue;
        }
        enclosing = expr.find_parent_of_type(uni.Ability);
        if enclosing is not None {
            if enclosing.find_parent_of_type(uni.Ability) is not None {
                self.emit(
                    E5120,
                    node_override=expr,
                    reason="foreign resources cannot be captured in Jac closures"
                );
            }
            if enclosing.is_async or self._ability_is_generator(enclosing) {
                self.emit(
                    E5120,
                    node_override=expr,
                    reason="foreign resources require an explicit foreign suspension contract"
                );
            }
        }
        if expr.find_parent_of_type(uni.ConcurrentExpr) is not None {
            self.emit(
                E5120,
                node_override=expr,
                reason="foreign resources require an explicit contract to cross a native task boundary"
            );
        }
        loop = expr.find_parent_of_type(uni.InForStmt);
        while loop is not None {
            if any(
                isinstance(kid, uni.Token) and kid.name == Tok.KW_FLOW
                for kid in loop.kid
            ) {
                self.emit(
                    E5120,
                    node_override=expr,
                    reason="foreign resources require an explicit contract to cross a native task boundary"
                );
                break;
            }
            loop = loop.find_parent_of_type(uni.InForStmt);
        }
        annotation: uni.UniNode = expr;
        while isinstance(annotation.parent, (uni.UnaryExpr, uni.AtomUnit)) {
            annotation = annotation.parent;
        }
        if isinstance(annotation.parent, uni.FuncSignature)
            and annotation.parent.return_type is annotation {
            if (
                not isinstance(annotation, uni.UnaryExpr)
                or annotation.ownership != OwnershipKind.OWN
            )
                and borrowed_return_source(enclosing) is None {
                self.emit(
                    E5120,
                    node_override=expr,
                    reason="foreign resource returns must explicitly transfer ownership"
                );
            }
        }
        field = expr.find_parent_of_type(uni.HasVar);
        signature_annotation = False;
        if field is not None
            and field.type_tag is not None
            and isinstance(field.type_tag.tag.type, SemanticFunctionType) {
            current: uni.UniNode | None = expr;
            while current is not None and current is not field {
                if current is field.type_tag {
                    signature_annotation = True;
                    break;
                }
                current = current.parent;
            }
        }
        if field is not None and not signature_annotation {
            self.emit(
                E5120,
                node_override=expr,
                reason="foreign resource fields require a foreign storage contract"
            );
        }
        arch = expr.find_parent_of_type(uni.Archetype);
        if arch is not None and expr in arch.base_classes {
            self.emit(
                E5120,
                node_override=expr,
                reason="foreign resource types are sealed and cannot be inherited"
            );
        }
        if expr.find_parent_of_type(uni.LambdaExpr) is not None {
            self.emit(
                E5120,
                node_override=expr,
                reason="foreign resources cannot be captured in Jac closures"
            );
        }
        if isinstance(expr.parent, uni.FuncCall) and expr.parent.target is expr {
            self.emit(
                E5120,
                node_override=expr.parent,
                reason="foreign resources can only be created by the typed foreign ABI"
            );
        }
        if isinstance(annotation.parent, uni.FuncCall)
            and annotation in (annotation.parent.params or [])
            and (
                annotation.parent.call_kind == "builtin"
                or (
                    annotation.parent.call_kind == "intrinsic"
                    and not (
                        isinstance(annotation.parent.target, uni.Name)
                        and annotation.parent.target.sym_name == "__musttail"
                    )
                )
            ) {
            self.emit(
                E5120,
                node_override=annotation.parent,
                reason="use the typed foreign ABI to inspect foreign resources"
            );
        }
        if isinstance(expr.parent, (uni.CompareExpr, uni.BinaryExpr)) {
            self.emit(
                E5120,
                node_override=expr.parent,
                reason="use the typed foreign ABI to compare foreign resources"
            );
        }
        if isinstance(expr, uni.Name) and isinstance(expr.parent, uni.ParamVar) {
            tag = expr.parent.type_tag;
            if tag is None
                or tag.ownership not in (OwnershipKind.OWN, OwnershipKind.BORROW) {
                self.emit(
                    E5120,
                    node_override=expr,
                    reason="foreign resource parameters require own or a shared borrow"
                );
            }
        }
        if isinstance(expr, uni.Name)
            and isinstance(expr.parent, uni.Assignment)
            and expr in expr.parent.target {
            sym = expr.sym;
            if sym is None
                or sym.ownership not in (OwnershipKind.OWN, OwnershipKind.BORROW) {
                self.emit(
                    E5120,
                    node_override=expr,
                    reason="foreign resource locals require own or a shared borrow"
                );
            }
            if expr.find_parent_of_type(uni.Ability) is None {
                self.emit(
                    E5120,
                    node_override=expr,
                    reason="foreign resource global references require a foreign storage contract"
                );
            }
        }
    }
}

impl NaIRGenPass._foreign_resource_kind(typ: ir.Type) -> str | None {
    if isinstance(typ, ir.PointerType)
        and not typ.is_opaque
        and isinstance(typ.pointee, ir.IdentifiedStructType) {
        name = typ.pointee.name;
        if name in self._foreign_resource_specs {
            return name;
        }
    }
    return None;
}

impl NaIRGenPass._foreign_resource_close(value: ir.Value) -> bool {
    kind = self._foreign_resource_kind(value.type);
    if kind is None {
        return False;
    }
    spec = self._foreign_resource_specs.get(kind);
    if spec is not None {
        nonempty = self.builder.icmp_unsigned("!=", value, self._zero_const(value.type), name="foreign.nonempty");
        close_block = self.builder.function.append_basic_block("foreign.drop");
        done_block = self.builder.function.append_basic_block("foreign.drop.done");
        self.builder.cbranch(nonempty, close_block, done_block);
        self.builder.position_at_end(close_block);
        if spec[0] == "word" {
            value = self.builder.ptrtoint(value, ir.IntType(64), name="foreign.drop.word");
        }
        close = self._get_or_declare_extern(spec[2], ir.VoidType(), [value.type]);
        self.builder.call(close, [value]);
        self.builder.branch(done_block);
        self.builder.position_at_end(done_block);
        return True;
    }
    return False;
}


impl NaIRGenPass._foreign_resource_type(typ: ClassType) -> ir.Type {
    spec = typ.shared.foreign_resource;
    assert spec is not None;
    if not self._nogc_owned_world() {
        self.emit(E5120, reason="foreign resources require native nogc ownership");
    }
    triple = str(self.llvm_module.triple).lower();
    if not any(arch in triple for arch in ("x86_64", "aarch64", "arm64")) {
        self.emit(E5120, reason="foreign resource ABI requires a supported 64-bit target");
    }
    key = "JacForeign." + str(typ.shared.canonical_key());
    import from jaclang.compiler.types.type_utils { lookup_symtab }
    drop_symbol = lookup_symtab(typ.shared.symbol_table, spec[2], None);
    declaration = drop_symbol.decl.name_of
        if drop_symbol is not None and drop_symbol.decl is not None else None;
    drop_name = declaration.name_ref.sym_name
        if isinstance(declaration, uni.Ability) and declaration.name_ref is not None
        else spec[2];
    # Keep the source-level binding in semantic metadata for lifetime/effect
    # checking, and use its resolved C symbol for emitted cleanup calls.
    self._foreign_resource_specs[key] = (spec[0], spec[1], drop_name, spec[3], spec[4]);
    return self.llvm_module.context.get_identified_type(key).as_pointer();
}

impl NaIRGenPass._foreign_word_type(typ: ir.Type) -> bool {
    kind = self._foreign_resource_kind(typ);
    spec = self._foreign_resource_specs.get(kind) if kind is not None else None;
    return spec is not None and spec[0] == "word";
}
