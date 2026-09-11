import from jaclang.compiler.ir.identity { RelationFamily }
impl Expr.postinit -> None {
    self._type_sym_tab = None;
    self._type_cache = None;
    self._type_cache_ok = False;
    self.ct_value = None;
    self.coerce_to = None;
    self.fw = None;
    self.fw_safe = False;
    self.attached_tokens = None;
}


impl Expr.type_sym_tab.getter -> (UniScopeNode | None) {
    import from jaclang.compiler.ir.symbols.nodes { UniScopeNode }

    return self._type_sym_tab;
}

impl Expr.type_sym_tab.setter(type_sym_tab: UniScopeNode) {
    import from jaclang.compiler.ir.symbols.nodes { UniScopeNode }

    self._type_sym_tab = type_sym_tab;
}

impl Expr.type.getter -> (TypeBase | None) {
    import from jaclang.compiler.ir.types.nodes { TypeBase }
    import from jaclang.compiler.ir.types.edges { TypeOf }

    if self._type_cache_ok and self._type_generation == self.relation_generation {
        return self._type_cache;
    }
    found = [self->:TypeOf:->];
    self._type_cache = found[0] if found else None;
    self._type_cache_ok = True;
    self._type_generation = self.relation_generation;
    return self._type_cache;
}

impl Expr.type.setter(type: (TypeBase | None)) -> None {
    import from jaclang.compiler.ir.types.nodes { TypeBase }
    for proposed_target in ([] if type is None else [type]) {
        if not isinstance(proposed_target, TypeBase) {
            raise TypeError("TypeOf requires a valid target");
        }
        self.check_connection(proposed_target, RelationFamily.TYPES);
    }

    self.changed_relations();
    import from jaclang.compiler.ir.types.nodes { TypeBase }
    import from jaclang.compiler.ir.types.edges { TypeOf }

    self.changed_relations(RelationFamily.TYPES);
    del [edge self->:TypeOf:->];
    if type is not None {
        import from jaclang.compiler.ir.base { TypedNode }
        import from jaclang.compiler.ir.types.nodes { TypeBase }
        if not isinstance(self, TypedNode) {
            raise TypeError("TypeOf requires a valid source");
        }
        if not isinstance(type, TypeBase) {
            raise TypeError("TypeOf requires a valid target");
        }
        self.prepare_connection(type, RelationFamily.TYPES);
        self +>:TypeOf:+> type;
    }
    self._type_cache = type;
    self._type_cache_ok = True;
    self._type_generation = self.relation_generation;
}

impl Expr.narrowed_type.getter -> (TypeBase | None) {
    import from jaclang.compiler.ir.types.nodes { TypeBase }
    import from jaclang.compiler.ir.types.edges { NarrowedTypeOf }

    found = [self->:NarrowedTypeOf:->];
    return found[0] if found else None;
}

impl Expr.narrowed_type.setter(narrowed_type: (TypeBase | None)) -> None {
    import from jaclang.compiler.ir.types.nodes { TypeBase }
    for proposed_target in ([] if narrowed_type is None else [narrowed_type]) {
        if not isinstance(proposed_target, TypeBase) {
            raise TypeError("NarrowedTypeOf requires a valid target");
        }
        self.check_connection(proposed_target, RelationFamily.TYPES);
    }

    self.changed_relations();
    import from jaclang.compiler.ir.types.nodes { TypeBase }
    import from jaclang.compiler.ir.types.edges { NarrowedTypeOf }

    self.changed_relations(RelationFamily.TYPES);
    del [edge self->:NarrowedTypeOf:->];
    if narrowed_type is not None {
        import from jaclang.compiler.ir.types.syntax { Expr }
        import from jaclang.compiler.ir.types.nodes { TypeBase }
        if not isinstance(self, Expr) {
            raise TypeError("NarrowedTypeOf requires a valid source");
        }
        if not isinstance(narrowed_type, TypeBase) {
            raise TypeError("NarrowedTypeOf requires a valid target");
        }
        self.prepare_connection(narrowed_type, RelationFamily.TYPES);
        self +>:NarrowedTypeOf:+> narrowed_type;
    }
}

impl AstTypedVarNode.type.getter -> (TypeBase | None) {
    import from jaclang.compiler.ir.types.nodes { TypeBase }
    import from jaclang.compiler.ir.types.edges { TypeOf }

    found = [self->:TypeOf:->];
    return found[0] if found else None;
}

impl AstTypedVarNode.type.setter(type: (TypeBase | None)) -> None {
    import from jaclang.compiler.ir.types.nodes { TypeBase }
    for proposed_target in ([] if type is None else [type]) {
        if not isinstance(proposed_target, TypeBase) {
            raise TypeError("TypeOf requires a valid target");
        }
        self.check_connection(proposed_target, RelationFamily.TYPES);
    }

    self.changed_relations();
    import from jaclang.compiler.ir.types.nodes { TypeBase }
    import from jaclang.compiler.ir.types.edges { TypeOf }

    self.changed_relations(RelationFamily.TYPES);
    del [edge self->:TypeOf:->];
    if type is not None {
        import from jaclang.compiler.ir.base { TypedNode }
        import from jaclang.compiler.ir.types.nodes { TypeBase }
        if not isinstance(self, TypedNode) {
            raise TypeError("TypeOf requires a valid source");
        }
        if not isinstance(type, TypeBase) {
            raise TypeError("TypeOf requires a valid target");
        }
        self.prepare_connection(type, RelationFamily.TYPES);
        self +>:TypeOf:+> type;
    }
}
