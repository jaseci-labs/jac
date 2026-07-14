import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes { UniPass }
import from jaclang.jac0core.constant { Tokens as Tok }

impl LayoutPass.postinit -> None {
    self.registry = LayoutRegistry();
    super.postinit();
}

impl LayoutPass.transform(ir_in: uni.Module) -> uni.Module {
    module = self.ir_in;

    arch_map = self._collect_archetypes(module);
    if not arch_map {
        module.gen.layout_registry = self.registry;
        return ir_in;
    }

    self._build_hierarchy(arch_map);

    topo_order = self._topo_sort(arch_map);
    self.registry.topo_order = topo_order;

    for name in topo_order {
        if name in arch_map {
            layout = self._build_layout(arch_map[name]);
            self.registry.layouts[name] = layout;
        }
    }

    for name in topo_order {
        if name in arch_map {
            self._build_vtable_layout(name, arch_map);
        }
    }

    for name in topo_order {
        if name in arch_map {
            self._validate_obj_fields(arch_map[name], arch_map);
        }
    }

    module.gen.layout_registry = self.registry;
    return ir_in;
}

impl LayoutPass._collect_archetypes(module: uni.Module) -> dict[str, uni.Archetype] {
    arch_map: dict[str, uni.Archetype] = {};
    for nd in UniPass.get_all_sub_nodes(module, uni.Archetype) {
        aname = nd.name.value if nd.name else None;
        if aname is None {
            continue;
        }

        if aname not in arch_map or nd.body is not None {
            arch_map[aname] = nd;
        }
    }
    return arch_map;
}

impl LayoutPass._build_hierarchy(archetypes: dict[str, uni.Archetype]) -> None {
    reg = self.registry;

    for (aname, arch) in archetypes.items() {
        if arch.base_classes {
            parents: list[str] = [];
            for base_expr in arch.base_classes {
                pname: (str | None) = None;
                if isinstance(base_expr, uni.Name) {
                    pname = base_expr.value;
                } elif isinstance(base_expr, uni.AstSymbolNode) {
                    pname = base_expr.sym_name;
                }
                if pname is not None {
                    parents.append(pname);
                }
            }
            if parents {
                reg.class_parents[aname] = parents;
            }
        }
    }

    for aname in archetypes {
        if aname not in reg.mro_order {
            reg.mro_order[aname] = self._compute_c3_mro(aname);
        }
    }
}

impl LayoutPass._compute_c3_mro(class_name: str) -> list[str] {
    reg = self.registry;

    parents = reg.class_parents.get(class_name);
    if parents is None or not parents {
        return [class_name];
    }

    parent_mros: list[list[str]] = [];
    for p in parents {
        if p not in reg.mro_order {
            reg.mro_order[p] = self._compute_c3_mro(p);
        }
        parent_mros.append(list(reg.mro_order[p]));
    }

    parent_mros.append(list(parents));

    result: list[str] = [class_name];
    while True {
        any_remaining = False;
        for mro_list in parent_mros {
            if len(mro_list) > 0 {
                any_remaining = True;
                break;
            }
        }
        if not any_remaining {
            break;
        }

        candidate: (str | None) = None;
        for mro_list in parent_mros {
            if len(mro_list) == 0 {
                continue;
            }
            head = mro_list[0];

            in_tail = False;
            for other_list in parent_mros {
                if len(other_list) > 1 and head in other_list[1:] {
                    in_tail = True;
                    break;
                }
            }
            if not in_tail {
                candidate = head;
                break;
            }
        }
        if candidate is None {
            self.emit(E5030, name=class_name);
            return result;
        }
        result.append(candidate);

        new_parent_mros: list[list[str]] = [];
        for mro_list in parent_mros {
            if len(mro_list) > 0 and mro_list[0] == candidate {
                mro_list.pop(0);
            }
            new_parent_mros.append(mro_list);
        }
        parent_mros = new_parent_mros;
    }
    return result;
}

impl LayoutPass._topo_sort(arch_map: dict[str, uni.Archetype]) -> list[str] {
    visited: set[str] = set();
    order: list[str] = [];
    reg = self.registry;

    for aname in arch_map {
        if aname in visited {
            continue;
        }
        stack: list[tuple] = [(aname, False)];
        while stack {
            (name, processed) = stack.pop();
            if name in visited {
                continue;
            }
            if processed {
                visited.add(name);
                order.append(name);
                continue;
            }
            stack.append((name, True));
            mro = reg.mro_order.get(name, [name]);
            for ancestor in reversed(mro[1:]) {
                if ancestor not in visited {
                    stack.append((ancestor, False));
                }
            }
        }
    }
    return order;
}

impl LayoutPass._build_layout(arch: uni.Archetype) -> ArchetypeLayout {
    reg = self.registry;
    aname = arch.name.value if arch.name else "unknown";
    mro = reg.mro_order.get(aname, [aname]);
    parents = reg.class_parents.get(aname, []);

    arch_type_str = arch.arch_kind or "object";

    parents_set: set[str] = set();
    for (_, plist) in reg.class_parents.items() {
        for p in plist {
            parents_set.add(p);
        }
    }
    needs_vtable = bool(parents) or aname in parents_set;

    fields: list[FieldInfo] = [];
    field_index: dict[str, int] = {};
    parent_field_start: dict[str, int] = {};
    seen_fields: set[str] = set();
    current_idx = 0;

    for ancestor_name in mro[1:] {
        ancestor_layout = reg.layouts.get(ancestor_name);
        if ancestor_layout is None {
            continue;
        }
        parent_field_start[ancestor_name] = current_idx;

        for finfo in ancestor_layout.fields {
            if finfo.name in seen_fields {
                continue;
            }
            seen_fields.add(finfo.name);
            new_field = FieldInfo(
                name=finfo.name,
                index=current_idx,
                type_tag=finfo.type_tag,
                type_node=finfo.type_node,
                default_expr=finfo.default_expr,
                owner=finfo.owner
            );
            fields.append(new_field);
            field_index[finfo.name] = current_idx;
            current_idx += 1;
        }
    }

    for var in arch.get_has_vars() {
        fname = var.name.value if var.name else "field";
        if fname in seen_fields {
            continue;
        }
        seen_fields.add(fname);
        type_tag = "";
        type_node: (uni.UniNode | None) = None;
        if var.type_tag and var.type_tag.tag {
            type_node = var.type_tag.tag;
            type_tag = var.type_tag.tag?.unparse() or str(var.type_tag.tag);
        }
        is_fn_ptr = type_node is not None and isinstance(type_node, uni.FuncSignature);
        new_field = FieldInfo(
            name=fname,
            index=current_idx,
            type_tag=type_tag,
            type_node=type_node,
            default_expr=var.value,
            owner=aname,
            is_func_ptr=is_fn_ptr
        );
        fields.append(new_field);
        field_index[fname] = current_idx;
        current_idx += 1;
    }

    return ArchetypeLayout(
        name=aname,
        arch_type=arch_type_str,
        parents=parents,
        mro=mro,
        fields=fields,
        field_index=field_index,
        has_vtable=needs_vtable,
        parent_field_start=parent_field_start
    );
}

impl LayoutPass._build_vtable_layout(
    arch_name: str, arch_map: dict[str, uni.Archetype]
) -> None {
    reg = self.registry;
    layout_obj = reg.layouts.get(arch_name);
    if layout_obj is None or not layout_obj.has_vtable {
        return;
    }
    method_list: list[str] = [];
    seen_methods: set[str] = set();
    mro = reg.mro_order.get(arch_name, [arch_name]);

    for ancestor_name in mro[1:] {
        ancestor_layout = reg.layouts.get(ancestor_name);
        if ancestor_layout is None {
            continue;
        }
        for mslot in ancestor_layout.methods {
            if mslot.name not in seen_methods {
                method_list.append(mslot.name);
                seen_methods.add(mslot.name);
            }
        }
    }

    arch = arch_map.get(arch_name);
    if arch is not None {
        for method in arch.get_methods() {
            method_name = method.name_ref.sym_name if method.name_ref else None;
            if method_name is not None and method_name not in seen_methods {
                method_list.append(method_name);
                seen_methods.add(method_name);
            }
        }
    }

    methods: list[MethodSlot] = [];
    method_index: dict[str, int] = {};
    for (i, mname) in enumerate(method_list) {
        sig_node: (uni.UniNode | None) = None;
        owner = arch_name;
        for check_name in mro {
            check_arch = arch_map.get(check_name);
            if check_arch is not None {
                for method in check_arch.get_methods() {
                    mn = method.name_ref.sym_name if method.name_ref else None;
                    if mn == mname {
                        sig_node = method.signature;
                        owner = check_name;
                        break;
                    }
                }
                if sig_node is not None {
                    break;
                }
            }
        }
        slot = MethodSlot(name=mname, index=i, owner=owner, signature=sig_node);
        methods.append(slot);
        method_index[mname] = i;
    }

    layout_obj.methods = methods;
    layout_obj.method_index = method_index;
}

impl LayoutRegistry.get_layout(name: str) -> (ArchetypeLayout | None) {
    return self.layouts.get(name);
}

impl LayoutRegistry.get_mro(name: str) -> list[str] {
    return self.mro_order.get(name, [name]);
}

impl LayoutRegistry.get_topo_order -> list[str] {
    return self.topo_order;
}

impl LayoutRegistry.is_primary_ancestor(child: str, ancestor: str) -> bool {
    current = child;
    while current is not None {
        parents = self.class_parents.get(current);
        if parents is None or not parents {
            return False;
        }
        primary = parents[0];
        if primary == ancestor {
            return True;
        }
        current = primary;
    }
    return False;
}

impl LayoutPass._validate_obj_fields(
    arch: uni.Archetype, arch_map: dict[str, uni.Archetype]
) -> None {
    if arch.arch_type {
        tok_name = arch.arch_type.name;
        if tok_name != Tok.KW_OBJECT.value {
            return;
        }
    }
    aname = arch.name.value if arch.name else "unknown";
    for var in arch.get_has_vars() {
        fname = var.name.value if var.name else "field";

        if not var.type_tag or not var.type_tag.tag {
            self.emit(W5031, node_override=var, arch=aname, field=fname);
            continue;
        }
        type_node = var.type_tag.tag;
        if not self._is_layout_compatible_type(type_node, arch_map) {
            type_str = type_node?.unparse() or str(type_node);
            self.emit(W5032, node_override=var, arch=aname, field=fname, type=type_str);
        }
    }
}

impl LayoutPass._is_layout_compatible_type(
    type_node: (uni.UniNode | None), arch_map: dict[str, uni.Archetype]
) -> bool {
    import from jaclang.compiler.passes.main.layout_pass {
        LAYOUT_COMPATIBLE_PRIMITIVES
    }
    if type_node is None {
        return False;
    }

    if isinstance(type_node, uni.FuncSignature) {
        return True;
    }

    if isinstance(type_node, uni.Name) {
        tname = type_node.value;
        if tname in LAYOUT_COMPATIBLE_PRIMITIVES {
            return True;
        }
        if tname == "None" {
            return True;
        }

        if tname in arch_map {
            return True;
        }

        if tname in self.registry.layouts {
            return True;
        }

        return False;
    }

    if uni?.BuiltinType and isinstance(type_node, uni.BuiltinType) {
        tname = type_node.value;
        return tname in LAYOUT_COMPATIBLE_PRIMITIVES;
    }

    if isinstance(type_node, uni.BinaryExpr) {
        op_val = getattr(type_node.op, 'value', '');
        if op_val == "|" {
            return (
                self._is_layout_compatible_type(type_node.left, arch_map)
                and self._is_layout_compatible_type(type_node.right, arch_map)
            );
        }
    }

    if isinstance(type_node, uni.AtomTrailer) and not type_node.is_attr {
        target_name: (str | None) = None;
        if isinstance(type_node.target, uni.Name) {
            target_name = type_node.target.value;
        }
        if target_name in {"list", "dict", "set", "frozenset", "tuple"} {
            if type_node?.right and type_node.right?.slices {
                for sl in type_node.right.slices {
                    elem = sl.start if sl?.start else sl;
                    if isinstance(elem, uni.TupleVal) and elem.values {
                        for tv in elem.values {
                            if not self._is_layout_compatible_type(tv, arch_map) {
                                return False;
                            }
                        }
                    } else {
                        if not self._is_layout_compatible_type(elem, arch_map) {
                            return False;
                        }
                    }
                }
            }
            return True;
        }
    }

    if type_node?.value and isinstance(type_node?.value, str) {
        tname = type_node.value;
        if tname in LAYOUT_COMPATIBLE_PRIMITIVES {
            return True;
        }
        if tname in arch_map {
            return True;
        }
        if tname in self.registry.layouts {
            return True;
        }
    }
    return False;
}
