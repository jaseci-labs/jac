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
        return None;
    }
    made = self.import_call(nd, member);
    if made is None {
        return None;
    }
    wanted = self.expr_type(nd);
    if made.type is wanted
        or wanted.kind == MirKind.NONE
        or made.type.kind == MirKind.NONE {
        return made;
    }
    return self.coerce(made, wanted, nd);
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
        return self.class_value(named) if named is not None else None;
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
    return None;
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

impl MirLowering.constant_value(value: (uni.Expr | None)) -> bool {
    return isinstance(value, (uni.Literal, uni.MultiString))
        or (
            isinstance(value, uni.AtomTrailer)
            and value.is_attr
            and self.is_enum_class(value.target)
        )
        or (
            isinstance(value, uni.Name)
            and value.sym is not None
            and self.global_declaration(value.sym) is not None
        );
}

impl MirLowering.subclass_archetypes(arch: uni.Archetype) -> list[uni.Archetype] {
    name = archetype_native_name(arch);
    owner = arch.find_parent_of_type(uni.Module) or self.module;
    registry = get_layout_registry(owner, self.prog);
    found: list[tuple[int, uni.Archetype]] = [];
    for lay in registry.layouts.values() {
        if lay.name == name or name not in list(lay.mro or []) {
            continue;
        }
        home = self.prog.mod.hub.get(lay.decl_mod) if lay.decl_mod else None;
        if home is None {
            continue;
        }
        for candidate in home.get_all_sub_nodes(uni.Archetype) {
            if archetype_native_name(candidate) == lay.name {
                found.append((len(list(lay.mro or [])), candidate));
            }
        }
    }
    ordered: list[uni.Archetype] = [];
    for depth in sorted({pair[0] for pair in found}, reverse=True) {
        for pair in found {
            if pair[0] == depth {
                ordered.append(pair[1]);
            }
        }
    }
    return ordered;
}

impl MirLowering.instance_class_attr(nd: uni.AtomTrailer) -> (MirValue | None) {
    if not nd.is_attr
        or not isinstance(nd.right, uni.Name)
        or not isinstance(nd.target, uni.Expr) {
        return None;
    }
    arch = self.holder_arch(nd.target);
    name = nd.right.value;
    if arch is None or self.nearest_has_var(arch, name) is not None {
        return None;
    }
    if self.object_def(arch).field(name) is not None {
        return None;
    }
    base_value = self.class_constant(arch, name);
    subclasses = self.subclass_archetypes(arch);
    overrides = [
        (sub, self.class_constant(sub, name))
        for sub in subclasses
        if self.class_constant(sub, name) is not base_value
    ];
    if base_value is None and not overrides {
        return None;
    }
    for (_, value) in overrides {
        if not self.constant_value(value) {
            return None;
        }
    }
    if base_value is not None and not self.constant_value(base_value) {
        return None;
    }
    b = self.builder();
    fn = self.st().fn;
    wanted = self.expr_type(nd);
    held = self.spill(self.lower_expr(nd.target));
    result = self.temp_slot(wanted);
    done = fn.new_block("clsattr.done");
    for (sub, value) in overrides {
        hit = fn.new_block("clsattr.hit");
        miss = fn.new_block("clsattr.miss");
        b.cond_branch(self.isinstance_check(held, sub), hit, miss);
        b.position(hit);
        if isinstance(value, uni.Expr) {
            b.store(result, self.coerce(self.lower_expr(value), wanted, nd));
        }
        b.branch(done);
        b.position(miss);
    }
    if base_value is None {
        b.raise_builtin(
            "AttributeError",
            f"'{archetype_native_name(arch).split('$')[0]}' object has no attribute '{name}'"
        );
    } else {
        b.store(result, self.coerce(self.lower_expr(base_value), wanted, nd));
        b.branch(done);
    }
    b.position(done);
    return b.load(result, wanted);
}
