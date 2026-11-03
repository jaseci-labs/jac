impl MirLowering.stdlib_module(expr: uni.UniNode) -> (uni.Module | None) {
    if not isinstance(expr, uni.Expr) or not isinstance(expr.type, ModuleType) {
        return None;
    }
    scope = expr.type.symbol_table;
    if scope is None or scope.loc is None {
        return None;
    }
    name = bundled_stdlib_module_of(scope.loc.mod_path);
    if not name {
        return None;
    }
    if name in self.stdlib_units {
        return self.stdlib_units[name];
    }
    found: (uni.Module | None) = None;
    if not scope.loc.mod_path.endswith(".jac") {
        (_, full_path) = resolve_native_module(
            name, os.path.dirname(self.module.loc.mod_path), allow_inferred=False
        );
        if full_path is not None
            and full_path.endswith(".jac")
            and os.path.isfile(full_path)
            and os.path.realpath(full_path)
                != os.path.realpath(self.module.loc.mod_path) {
            found = self.prog.load_dependency_module(
                full_path, importer_path=self.module.loc.mod_path, need_tree=True
            );
        }
    }
    self.stdlib_units[name] = found;
    return found;
}

impl MirLowering.module_member(unit: uni.Module, name: str) -> (uni.UniNode | None) {
    for elem in unit.body {
        if isinstance(elem, uni.Ability) and self.name_of(elem) == name {
            return elem;
        }
        if isinstance(elem, uni.GlobalVars) {
            for assign in elem.assignments {
                for target in assign.target {
                    if isinstance(target, uni.Name) and target.value == name {
                        return assign;
                    }
                }
            }
        }
    }
    return None;
}

impl MirLowering.stdlib_call(
    nd: uni.FuncCall, target: uni.AtomTrailer
) -> (MirValue | None) {
    if not target.is_attr or not isinstance(target.right, uni.Name) {
        return None;
    }
    name = target.right.value;
    unit = self.stdlib_module(target.target);
    if unit is None
        and isinstance(target.target, uni.AtomTrailer)
        and target.target.is_attr
        and isinstance(target.target.right, uni.Name) {
        unit = self.stdlib_module(target.target.target);
        name = f"{target.target.right.value}_{name}";
    }
    if unit is None {
        return None;
    }
    member = self.module_member(unit, name);
    if not isinstance(member, uni.Ability) {
        raise MirRefused(
            mir_refusal(
                "call",
                f"{unit.name}.{name}",
                nd,
                f"The bundled native {os.path.basename(unit.loc.mod_path)} has no '{name}'."
            )
        );
    }
    return self.import_call(nd, member);
}

impl MirLowering.stdlib_attr(nd: uni.AtomTrailer) -> (MirValue | None) {
    if not nd.is_attr or not isinstance(nd.right, uni.Name) {
        return None;
    }
    if isinstance(nd.target, uni.Expr)
        and isinstance(nd.target.type, ModuleType)
        and isinstance(nd.target.type.symbol_table, uni.Module)
        and nd.target.type.symbol_table.loc.mod_path.endswith(".jac") {
        named = self.class_reference(nd);
        if named is not None {
            return self.class_value(named);
        }
        return self.lower_name(nd.right);
    }
    unit = self.stdlib_module(nd.target);
    if unit is None {
        return None;
    }
    member = self.module_member(unit, nd.right.value);
    if isinstance(member, uni.Assignment)
        and isinstance(member.value, (uni.Literal, uni.MultiString)) {
        return self.coerce(self.lower_expr(member.value), self.expr_type(nd), nd);
    }
    if isinstance(member, uni.Assignment)
        and member.target
        and isinstance(member.target[0], uni.Name) {
        place = self.global_place(member.target[0]);
        if place is not None {
            return self.coerce(
                self.builder().load(place, self.place_elem(place)),
                self.expr_type(nd),
                nd
            );
        }
    }
    raise MirRefused(
        mir_refusal(
            "attribute",
            f"{unit.name}.{nd.right.value}",
            nd,
            "Only constant module attributes of a bundled native module are read natively."
        )
    );
}

impl MirLowering.class_constant(arch: uni.Archetype, name: str) -> (uni.Expr | None) {
    for holder in self.lineage(arch) {
        for member in list(ModuleFacts.unwrap_body(holder) or []) {
            if isinstance(member, uni.ArchHas) and member.is_static {
                for var in member.vars {
                    if var.name is not None
                        and var.name.value == name
                        and isinstance(var.value, uni.Expr) {
                        return var.value;
                    }
                }
            }
            if isinstance(member, uni.ModuleCode) {
                for stmt in member.body {
                    if isinstance(stmt, uni.Assignment)
                        and len(stmt.target) == 1
                        and isinstance(stmt.target[0], uni.Name)
                        and stmt.target[0].value == name
                        and isinstance(stmt.value, uni.Expr) {
                        return stmt.value;
                    }
                }
            }
        }
    }
    return None;
}

impl MirLowering.class_attr(nd: uni.AtomTrailer) -> (MirValue | None) {
    if not nd.is_attr
        or not isinstance(nd.right, uni.Name)
        or not isinstance(nd.target, uni.Expr) {
        return None;
    }
    arch = self.class_reference(nd.target);
    if arch is None {
        return None;
    }
    value = self.class_constant(arch, nd.right.value);
    if value is None
        or not (
            isinstance(value, (uni.Literal, uni.MultiString))
            or (
                isinstance(value, uni.AtomTrailer)
                and value.is_attr
                and self.is_enum_class(value.target)
            )
        ) {
        return None;
    }
    return self.coerce(self.lower_expr(value), self.expr_type(nd), nd);
}
