impl MirLowering.stdlib_module(expr: uni.UniNode) -> (uni.Module | None) {
    if not isinstance(expr, uni.Expr) or not isinstance(expr.type, ModuleType) {
        return None;
    }
    return self.stdlib_unit(expr.type.symbol_table);
}

impl MirLowering.stdlib_item_call(nd: uni.FuncCall) -> (MirValue | None) {
    callee = nd.callee_decl;
    if not isinstance(nd.target, uni.Name)
        or not isinstance(callee, uni.Ability)
        or not isinstance(callee.parent, uni.Module)
        or callee.loc.mod_path.endswith(".jac") {
        return None;
    }
    unit = self.stdlib_unit(callee.parent);
    member = self.module_member(unit, self.name_of(callee))
        if unit is not None
        else None;
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

impl MirLowering.stdlib_unit(scope: (uni.UniScopeNode | None)) -> (uni.Module | None) {
    if scope is None or scope.loc is None {
        return None;
    }
    return self.stdlib_unit_at(scope.loc.mod_path);
}

impl MirLowering.stdlib_member(nd: uni.Name) -> (uni.Ability | None) {
    sym = nd.sym;
    if sym is None or sym.decl is None or sym.decl.loc is None {
        return None;
    }
    unit = self.stdlib_unit_at(sym.decl.loc.mod_path);
    named = sym.decl.value if isinstance(sym.decl, uni.Name) else nd.value;
    found = self.module_member(unit, named) if unit is not None else None;
    return found if isinstance(found, uni.Ability) else None;
}

impl MirLowering.stdlib_unit_at(path: str) -> (uni.Module | None) {
    name = bundled_stdlib_module_of(path);
    if not name {
        return None;
    }
    scope_path = path;
    if name in self.stdlib_units {
        return self.stdlib_units[name];
    }
    found: (uni.Module | None) = None;
    if not scope_path.endswith(".jac") {
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
        if isinstance(elem, uni.Import) and elem.clib_decls {
            for decl in elem.clib_decls {
                if isinstance(decl, uni.Ability) and self.name_of(decl) == name {
                    return decl;
                }
            }
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

impl MirLowering.class_attr_entry(
    arch: uni.Archetype, name: str
) -> (tuple[uni.Archetype, uni.Name, uni.Expr] | None) {
    if self.arch_is_enum(arch) {
        return None;
    }
    for holder in self.lineage(arch) {
        for member in list(ModuleFacts.unwrap_body(holder) or []) {
            if isinstance(member, uni.ArchHas) and member.is_static {
                for var in member.vars {
                    if var.name is not None
                        and var.name.value == name
                        and isinstance(var.value, uni.Expr) {
                        return (holder, var.name, var.value);
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
                        return (holder, stmt.target[0], stmt.value);
                    }
                }
            }
        }
    }
    return None;
}

impl MirLowering.arch_is_enum(arch: uni.Archetype) -> bool {
    sym = arch.name.sym if arch.name is not None else None;
    made = self.prog.get_type_evaluator().get_type_of_symbol(sym)
        if sym is not None
        else None;
    return is_enum_class_type(made);
}

impl MirLowering.class_constant(arch: uni.Archetype, name: str) -> (uni.Expr | None) {
    found = self.class_attr_entry(arch, name);
    return found[2] if found is not None else None;
}

impl MirLowering.class_global(
    holder: uni.Archetype, target: uni.Name, value: uni.Expr
) -> MirGlobal {
    owner = holder.find_parent_of_type(uni.Module) or self.module;
    path = owner.loc.mod_path;
    symbol = native_symbol_name(
        native_unit_prefix(path),
        native_unit_spelling(
            f"{archetype_native_name(holder)}.{target.value}.__cls", path
        )
    );
    refused = self.class_global_refusals.get(symbol);
    if refused is not None {
        raise refused;
    }
    held = self.mir.globals.get(symbol);
    if held is not None {
        return held;
    }
    held_type = self.symbol_type(target.sym, target)
        if target.sym is not None
        else self.expr_type(value);
    local = owner is self.module;
    held = MirGlobal(
        name=symbol, symbol=symbol, type=held_type, linkage="" if local else "external"
    );
    self.mir.globals[symbol] = held;
    if local {
        self.class_global_init(
            held, f"{archetype_native_name(holder)}.{target.value}", value
        );
    } else {
        self.add_dep(path, symbol, target);
    }
    return held;
}

impl MirLowering.class_global_init(
    held: MirGlobal, label: str, value: uni.Expr
) -> None {
    fn = MirFunction(
        name="__cls_init",
        symbol=held.symbol + "_init",
        ret=mir_none(),
        linkage="internal"
    );
    first = fn.new_block("entry");
    (outer_state, outer_current) = (self.state, self.current);
    self.state = MirFnState(fn=fn, b=MirBuilder(fn=fn, block=first));
    self.current = label;
    try {
        for used in value.get_all_sub_nodes(uni.Name) {
            self.declare_global(used);
        }
        b = self.builder();
        place = self.emit_value(
            MirOp.GLOBAL_ADDR, mir_c_ptr(held.type), [], str_value=held.symbol
        );
        b.store(place, self.coerce(self.lower_expr(value), held.type, value));
        b.ret(None);
        self.mir.functions.append(fn);
        self.class_inits.append((value.loc.pos_start, fn.symbol));
    } except MirRefused as err {
        del self.mir.globals[held.symbol];
        self.class_global_refusals[held.symbol] = err;
        raise err;
    } finally {
        (self.state, self.current) = (outer_state, outer_current);
    }
}

impl MirLowering.declare_class_globals {
    for arch in self.module_archetypes() {
        if self.arch_is_enum(arch) {
            continue;
        }
        for member in list(ModuleFacts.unwrap_body(arch) or []) {
            entries: list[tuple[uni.Name, uni.Expr]] = [];
            if isinstance(member, uni.ArchHas) and member.is_static {
                for var in member.vars {
                    if var.name is not None and isinstance(var.value, uni.Expr) {
                        entries.append((var.name, var.value));
                    }
                }
            }
            if isinstance(member, uni.ModuleCode) {
                for stmt in member.body {
                    if isinstance(stmt, uni.Assignment)
                        and len(stmt.target) == 1
                        and isinstance(stmt.target[0], uni.Name)
                        and isinstance(stmt.value, uni.Expr) {
                        entries.append((stmt.target[0], stmt.value));
                    }
                }
            }
            for (target, value) in entries {
                if self.constant_value(value) {
                    continue;
                }
                try {
                    self.class_global(arch, target, value);
                } except MirRefused {
                    continue;
                }
            }
        }
    }
}

impl MirLowering.class_value_of(
    arch: uni.Archetype, name: str, wanted: MirType, site: uni.UniNode
) -> (MirValue | None) {
    found = self.class_attr_entry(arch, name);
    if found is None {
        return None;
    }
    (holder, target, value) = found;
    if self.constant_value(value) {
        return self.coerce(self.lower_expr(value), wanted, site);
    }
    held = self.class_global(holder, target, value);
    place = self.emit_value(
        MirOp.GLOBAL_ADDR, mir_c_ptr(held.type), [], str_value=held.symbol
    );
    return self.coerce(self.builder().load(place, held.type), wanted, site);
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
    return self.class_value_of(arch, nd.right.value, self.expr_type(nd), nd);
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
    layouts = list(get_layout_registry(owner, self.prog).layouts.values());
    for named in self.named_classes() {
        home = named.find_parent_of_type(uni.Module);
        if home is not None and home is not owner {
            found_layout = get_layout_registry(home, self.prog).get_layout(
                archetype_native_name(named)
            );
            if found_layout is not None {
                layouts.append(found_layout);
            }
        }
    }
    found: list[tuple[int, uni.Archetype]] = [];
    seen: set[str] = set();
    for lay in layouts {
        if lay.name == name or lay.name in seen or name not in list(lay.mro or []) {
            continue;
        }
        seen.add(lay.name);
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

impl MirLowering.named_classes -> list[uni.Archetype] {
    if self.class_names_seen is not None {
        return self.class_names_seen;
    }
    found: list[uni.Archetype] = [];
    marks: set[int] = set();
    for nd in self.module.get_all_sub_nodes(uni.Name) {
        t = nd.type;
        if not isinstance(t, ClassType)
            or t._shared is None
            or t.is_instance()
            or not t.is_instantiable() {
            continue;
        }
        scope = t.shared.symbol_table;
        if isinstance(scope, uni.Archetype)
            and not stub_archetype(scope)
            and id(scope) not in marks {
            marks.add(id(scope));
            found.append(scope);
        }
    }
    self.class_names_seen = found;
    return found;
}

impl MirLowering.class_dispatch(
    arch: uni.Archetype,
    name: str,
    wanted: MirType,
    site: uni.UniNode,
    matches: Callable[[uni.Archetype], MirValue]
) -> (MirValue | None) {
    base = self.class_attr_entry(arch, name);
    overrides = self.class_attr_overrides(arch, name);
    if base is None and not overrides {
        return None;
    }
    b = self.builder();
    fn = self.st().fn;
    result = self.temp_slot(wanted);
    done = fn.new_block("clsattr.done");
    for sub in overrides {
        hit = fn.new_block("clsattr.hit");
        miss = fn.new_block("clsattr.miss");
        b.cond_branch(matches(sub), hit, miss);
        b.position(hit);
        made = self.class_value_of(sub, name, wanted, site);
        if made is not None {
            b.store(result, made);
        }
        b.branch(done);
        b.position(miss);
    }
    if base is None {
        b.raise_builtin(
            "AttributeError",
            f"'{archetype_native_name(arch).split('$')[0]}' object has no attribute '{name}'"
        );
    } else {
        made = self.class_value_of(arch, name, wanted, site);
        if made is not None {
            b.store(result, made);
        }
        b.branch(done);
    }
    b.position(done);
    return b.load(result, wanted);
}

impl MirLowering.class_attr_overrides(
    arch: uni.Archetype, name: str
) -> list[uni.Archetype] {
    base = self.class_attr_entry(arch, name);
    return [
        sub
        for sub in self.subclass_archetypes(arch)
        if self.class_attr_entry(sub, name) is not None
            and (base is None or self.class_attr_entry(sub, name)[2] is not base[2])
    ];
}

impl MirLowering.has_class_attr(arch: uni.Archetype, name: str) -> bool {
    return self.class_attr_entry(arch, name) is not None
        or bool(self.class_attr_overrides(arch, name));
}

impl MirLowering.instance_class_attr(nd: uni.AtomTrailer) -> (MirValue | None) {
    if not nd.is_attr
        or not isinstance(nd.right, uni.Name)
        or not isinstance(nd.target, uni.Expr)
        or not isinstance(nd.target.type, (ClassType, UnionType)) {
        return None;
    }
    target_type = self.expr_type(nd.target);
    if target_type.kind == MirKind.CLASS {
        bound = self.class_bound(nd.target.type)
            if isinstance(nd.target.type, ClassType)
            else None;
        if bound is None or not self.has_class_attr(bound, nd.right.value) {
            return None;
        }
        word = self.spill(self.lower_expr(nd.target));
        return self.class_dispatch(
            bound,
            nd.right.value,
            self.expr_type(nd),
            nd,
            lambda (sub: uni.Archetype) -> MirValue { self.builder().compare(
                "eq", self.address_of(word), self.address_of(self.class_value(sub))
            ); }
        );
    }
    arch = self.holder_arch(nd.target);
    name = nd.right.value;
    if arch is None {
        return None;
    }
    var = self.nearest_has_var(arch, name);
    group = var.find_parent_of_type(uni.ArchHas) if var is not None else None;
    if var is not None and not (group is not None and group.is_static) {
        return None;
    }
    if self.object_def(arch).field(name) is not None
        or not self.has_class_attr(arch, name) {
        return None;
    }
    held = self.spill(self.lower_expr(nd.target));
    return self.class_dispatch(
        arch,
        name,
        self.expr_type(nd),
        nd,
        lambda (sub: uni.Archetype) -> MirValue { self.member_test(
            held, held, sub, nd
        ); }
    );
}

impl MirLowering.environ_unit(target: uni.UniNode) -> (uni.Module | None) {
    while isinstance(target, uni.AtomUnit) {
        target = target.value;
    }
    if not isinstance(target, uni.AtomTrailer)
        or not target.is_attr
        or not isinstance(target.right, uni.Name)
        or target.right.value != "environ" {
        return None;
    }
    return self.stdlib_module(target.target);
}

impl MirLowering.environ_call(
    unit: uni.Module, name: str, args: list[MirValue], site: uni.UniNode
) -> MirValue {
    member = self.module_member(unit, f"environ_{name}");
    if not isinstance(member, uni.Ability) {
        raise MirRefused(mir_refusal("os.environ", name, site));
    }
    decl = self.foreign_function_decl(member, site);
    if len(args) != len(decl.params) {
        raise MirRefused(mir_refusal("os.environ", name, site));
    }
    values = [self.coerce(arg, param, site) for (arg, param) in zip(args, decl.params)];
    result = self.builder().call(decl.symbol, values, decl.ret);
    if result is None {
        return self.builder().const_bool(False);
    }
    return result;
}

impl MirLowering.environ_key(slice: uni.IndexSlice, site: uni.UniNode) -> MirValue {
    if slice.is_range or len(slice.slices) != 1 or slice.slices[0].start is None {
        raise MirRefused(mir_refusal("os.environ", "slice", site));
    }
    return self.lower_expr(slice.slices[0].start);
}
