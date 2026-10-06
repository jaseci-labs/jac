impl NativeLowering._devirt_closed_world(arch_name: str) -> bool {
    arch = self.arch_ast_map.get(arch_name);
    if arch is None {
        return False;
    }
    return arch.access_type == SymbolAccess.PRIVATE;
}

impl NativeLowering._arch_key(arch: uni.Archetype) -> str {
    import from jaclang.compiler.passes.layout_pass { archetype_native_name }
    return archetype_native_name(arch);
}

impl NativeLowering._arch_ref_key(nd: (uni.UniNode | None)) -> (str | None) {
    import from jaclang.compiler.passes.layout_pass { referenced_native_name }
    return referenced_native_name(nd);
}

impl NativeLowering._arch_display(arch_name: str) -> str {
    import from jaclang.compiler.frontend.codeinfo { native_arch_display }
    return native_arch_display(arch_name);
}

impl NativeLowering._native_archetypes(module: uni.Module) -> list[uni.Archetype] {
    result: dict[(str, uni.Archetype)] = {};

    for stmt in ModuleFacts.iter_context_stmts(module, CodeContext.NATIVE) {
        if isinstance(stmt, uni.Archetype) {
            aname = self._arch_key(stmt);
            if aname not in result or stmt.body is not None {
                result[aname] = stmt;
            }
        }
    }

    for arch in ModuleFacts.shared_archetypes_for_context(module, CodeContext.NATIVE) {
        aname = self._arch_key(arch);
        if aname not in result {
            result[aname] = arch;
        }
    }

    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    layout_reg = get_layout_registry(self.module, self.prog);
    out: list[uni.Archetype] = [];
    for a in result.values() {
        if a.type_params {
            aname = self._arch_key(a);
            if layout_reg.get_layout(aname) is None {
                continue;
            }
        }
        out.append(a);
    }
    return out;
}

impl NativeLowering._constructor_slots -> tuple[str, ...] {
    return ("init", "__init__", "postinit", "__post_init__", );
}

impl NativeLowering._constructor_ability_for(cls: str, slot: str) -> (uni.Ability | None) {
    for _cn in self._mro_of(cls) {
        _arch = self.arch_ast_map.get(_cn);
        if _arch is None or _arch.body is None {
            continue;
        }
        for _st in _arch.body {
            if isinstance(_st, uni.Ability)
                and _st.name_ref is not None
                and _st.name_ref.sym_name == slot {
                return _st;
            }
        }
    }
    return None;
}

impl NativeLowering._derived_field_decls(nd: uni.Archetype) -> dict[str, uni.HasVar] {
    arch_name = nd.name.value if nd.name else "";
    decls: dict[str, uni.HasVar] = {};
    for cls in reversed(self._mro_of(arch_name)) {
        arch = nd if cls == arch_name else self.arch_ast_map.get(cls);
        if arch is None {
            continue;
        }
        for var in arch.get_has_vars() {
            owner = var.find_parent_of_type(uni.ArchHas);
            if var.name is None
                or var.accessors
                or (owner is not None and owner.is_static) {
                continue;
            }
            decls[var.name.value] = var;
        }
    }
    return decls;
}

impl NativeLowering._emit_scalar_type_arg_refusal(
    nd: uni.UniNode, type_name: str, fname: str, tv_name: str, arg: any
) -> bool {
    """Refuse a touch of an erased slot, inside the callable that touches it.

    The slot carries no value the native side put there, so answering with
    its bits would be wrong rather than merely un-lowered. Emitting here puts
    the diagnostic inside the enclosing callable's demotion window, which is
    what turns one un-lowerable declaration into a seam per method that reads
    or writes it instead of a dead module.
    """;
    self.emit(
        E5092,
        node_override=nd,
        kind="type argument",
        name=f"{self._arch_display(type_name)}[{arg}]",
        help_text=(
            f"A generic archetype is type-erased natively: one struct is "
            f"shared by every instantiation, so a slot typed by '{tv_name}' "
            f"-- here '{type_name}.{fname}' -- is a raw pointer. A pointer "
            f"slot cannot carry '{arg}', whose native representation is a "
            f"value rather than a reference, and for an optional slot the "
            f"null that spells None would alias a zero payload. Instantiate "
            f"'{type_name}' at an archetype type, or declare '{fname}' with "
            f"a concrete type."
        )
    );
    return True;
}

impl NativeLowering._method_slot_name(
    method: uni.Ability, field: (uni.HasVar | None)
) -> str {
    if field is not None {
        _fname = field.name.value if field.name else "field";
        _slot = accessor_slot_name(_fname, method);
        if _slot is not None {
            return _slot;
        }
    }
    return method.name_ref.sym_name if method.name_ref else "unnamed";
}

impl NativeLowering._seam_warnings_on -> bool {
    """Whether a seam this run takes should also be announced on stderr.""";
    if self._na_debug_on() or bool(self.prog.options.native_debug) {
        return True;
    }
    import from jaclang.compiler.frontend.host { active_host }
    defaults = active_host().project_defaults();
    return defaults.check.warn_native_seams if defaults is not None else True;
}

impl NativeLowering._refuse_opaque_field(
    nd: (uni.UniNode | None), type_name: (str | None), fname: str
) -> bool {
    if type_name is None {
        return False;
    }
    for _cn in self._mro_of(type_name) {
        _why = self.struct_field_opaque.get(_cn, {}).get(fname);
        if _why is not None {
            self.emit(
                E5092, node_override=nd, kind="erased field", name=f"{_cn}.{fname}"
            );
            return True;
        }
    }
    return False;
}

impl NativeLowering._unadopted_field_owner(
    arch_name: str, field_name: str
) -> (str | None) {
    """The ancestor that declares a field this class's layout does not hold.

    A subclass whose ancestor lays out in another unit adopts that unit's slot
    assignment, and where the two disagree about the header slots there is no
    assignment to adopt. Naming the ancestor turns the resulting refusal from
    'some attribute did not lower' into the layout fact behind it.
    """;
    _arch = self.arch_ast_map.get(arch_name);
    if _arch is None {
        return None;
    }
    for _base in (_arch.base_classes or []) {
        _bn = self._arch_ref_key(_base) or self._get_name(_base);
        if _bn is None or _bn == arch_name {
            continue;
        }
        _blay = self._arch_layout(_bn);
        if _blay is not None and field_name in _blay.field_index {
            return _bn;
        }
        _up = self._unadopted_field_owner(_bn, field_name);
        if _up is not None {
            return _up;
        }
    }
    return None;
}

impl NativeLowering._emit_field_access_refusal(
    nd: uni.UniNode, arch_name: str, field_name: str
) -> None {
    _owner = self._unadopted_field_owner(arch_name, field_name);
    if _owner is None {
        _decl = self._class_const_declarer(arch_name, field_name);
        if _decl is not None {
            self.emit(
                E5092,
                node_override=nd,
                kind="class-level attribute read",
                name=field_name,
                help_text=(
                    f"'{field_name}' is a class-level attribute of '{_decl}', "
                    f"not an instance field. Reading it through an instance "
                    f"needs every declaring class in the hierarchy to carry "
                    f"the value in one shape the receiver's vtable can select "
                    f"between, and this hierarchy does not. Read it off the "
                    f"class, or move this code to a @sv/Python context."
                )
            );
        }
        return;
    }
    self.emit(
        E5092,
        node_override=nd,
        kind="inherited field access",
        name=field_name,
        help_text=(
            f"'{field_name}' is declared by '{_owner}', which lays out in "
            f"another unit with no vtable slot, while '{arch_name}' needs "
            f"that slot for one. No offset satisfies both units, so the "
            f"field is not reachable from here. Read it through an "
            f"'{_owner}'-typed value, or move this code to a @sv/Python "
            f"context."
        )
    );
}

impl NativeLowering._class_const_declarer(
    arch_name: str, field_name: str
) -> (str | None) {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    _seen: list[str] = list(self._mro_of(arch_name));
    for _cls in get_layout_registry(self.module, self.prog).mro_order {
        if arch_name in self._mro_of(_cls) and _cls not in _seen {
            _seen.append(_cls);
        }
    }
    for _cls in _seen {
        _arch = self.arch_ast_map.get(_cls);
        if _arch is None or _arch.body is None {
            continue;
        }
        for stmt in _arch.body {
            if not isinstance(stmt, uni.ModuleCode) {
                continue;
            }
            for _a in (stmt.body or []) {
                if not isinstance(_a, uni.Assignment) {
                    continue;
                }
                _tg = _a.target
                    if isinstance(_a.target, (list, tuple))
                    else [(_a.target)];
                for _t in _tg {
                    if self._get_name(_t) == field_name {
                        return _cls;
                    }
                }
            }
        }
    }
    return None;
}

impl NativeLowering._mro_of(arch_name: str) -> list[str] {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    mro = get_layout_registry(self.module, self.prog).get_mro(arch_name);
    return mro or [arch_name];
}

impl NativeLowering._arch_layout(arch_name: str) -> (ArchetypeLayout | None) {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }

    _owner = None;
    _arch_nd = self.arch_ast_map.get(arch_name);
    if _arch_nd is not None {
        _owner = _arch_nd.find_parent_of_type(uni.Module);
    }
    for _cand in [_owner, self.module] {
        if _cand is None {
            continue;
        }
        lay = get_layout_registry(_cand, self.prog).get_layout(arch_name);
        if lay is not None {
            return lay;
        }
    }
    return None;
}

impl NativeLowering._event_from_walker(method: uni.Ability) -> bool {
    owner = method.find_parent_of_type(uni.Archetype);
    if owner is not None {
        return owner.arch_kind == "walker";
    }
    sig = method.signature;
    return isinstance(sig, uni.EventSignature) and sig.from_walker;
}

impl NativeLowering._stack_alloc_target_ok(nd: uni.UniNode) -> bool {
    p = nd.parent;
    if not isinstance(p, uni.Assignment) or p.aug_op is not None or p.value is not nd {
        return False;
    }
    targets = p.target if isinstance(p.target, (list, tuple)) else [(p.target)];
    if len(targets) != 1 or not isinstance(targets[0], uni.Name) {
        return False;
    }
    sym = targets[0].sym;
    return sym is not None and sym.na_stack_ok;
}

impl NativeLowering._hasvar_is_own(var: uni.UniNode) -> bool {
    if not isinstance(var, uni.HasVar) {
        return False;
    }
    _tt = var.type_tag;
    if _tt is None {
        return False;
    }
    if _tt.ownership == OwnershipKind.OWN {
        return True;
    }
    _inner = _tt.tag;
    return isinstance(_inner, uni.UnaryExpr) and _inner.ownership == OwnershipKind.OWN;
}

impl NativeLowering._register_archetypes_topo_order(
    archetypes: list[uni.Archetype]
) -> list[str] {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    layout_reg = get_layout_registry(self.module, self.prog);
    for arch in archetypes {
        arch_name = self._arch_key(arch);
        self.arch_ast_map[arch_name] = arch;
    }

    return layout_reg.get_topo_order();
}

impl NativeLowering._register_archetypes_method_shape(stmt: uni.Ability) -> str {
    if stmt.signature is not None and isinstance(stmt.signature, uni.FuncSignature) {
        return "func";
    }
    if stmt.signature is None and stmt.body is not None {
        return "nosig";
    }
    if isinstance(stmt.signature, uni.EventSignature) {
        return "event";
    }
    return "other";
}

impl NativeLowering._register_archetypes_unsupported_name(
    arch_name: str, stmt: uni.Ability
) -> str {
    _sig_kind = (
        type(stmt.signature).__name__
            if stmt.signature is not None
            else "no-signature"
    );
    _m_name = stmt.name_ref.sym_name if stmt.name_ref else "?";
    return f"{arch_name}.{_m_name} ({_sig_kind})";
}

impl NativeLowering._register_archetypes_non_overridden(
    vtable_layouts: dict[str, list[str]]
) -> dict[str, set[str]] {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry as _no_glr }
    _no_reg = _no_glr(self.module, self.prog);
    out: dict[str, set[str]] = {};
    for (base_name, layout) in vtable_layouts.items() {
        if not self._devirt_closed_world(base_name) {
            continue;
        }
        non_overridden: set[str] = set();
        _no_base_lay = _no_reg.get_layout(base_name);
        for method_name in layout {
            defining_class = self._resolve_method_owner(base_name, method_name);
            if defining_class is None {
                continue;
            }
            _no_base_owner = defining_class;
            if _no_base_lay is not None {
                _no_bmi = _no_base_lay.method_index.get(method_name);
                if _no_bmi is not None and _no_bmi < len(_no_base_lay.methods) {
                    _no_base_owner = _no_base_lay.methods[_no_bmi].owner
                        or defining_class;
                }
            }

            overridden = False;
            for child_name in _no_reg.mro_order {
                if child_name == base_name
                    or base_name not in _no_reg.get_mro(child_name) {
                    continue;
                }
                _no_cl = _no_reg.get_layout(child_name);
                if _no_cl is None {
                    continue;
                }
                _no_cmi = _no_cl.method_index.get(method_name);
                if _no_cmi is None or _no_cmi >= len(_no_cl.methods) {
                    continue;
                }
                if _no_cl.methods[_no_cmi].owner != _no_base_owner {
                    overridden = True;
                    break;
                }
                child_arch = self.arch_ast_map.get(child_name);
                if child_arch is not None and child_arch.body is not None {
                    for stmt in child_arch.body {
                        if isinstance(stmt, uni.Ability) {
                            mn = stmt.name_ref.sym_name if stmt.name_ref else None;
                            if mn == method_name {
                                overridden = True;
                                break;
                            }
                        }
                    }
                }
                if not overridden and child_arch is not None {
                    for (_slot, _accvar, _acc) in archetype_accessors(child_arch) {
                        if _slot == method_name {
                            overridden = True;
                            break;
                        }
                    }
                }
                if overridden {
                    break;
                }
            }
            if not overridden {
                non_overridden.add(method_name);
            }
        }
        if non_overridden {
            out[base_name] = non_overridden;
        }
    }
    return out;
}

impl NativeLowering._visit_nonprimary_ancestor_methods_provided(
    arch: uni.Archetype
) -> (tuple[str, list[str], set[str]] | None) {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    import from jaclang.compiler.symbol_utils { collect_method_names }
    layout_reg = get_layout_registry(self.module, self.prog);
    arch_name = self._arch_key(arch);
    mro = self._mro_of(arch_name);
    if len(mro) < 2 {
        return None;
    }
    provided_methods = collect_method_names(arch);
    for anc in mro[1:] {
        if layout_reg.is_primary_ancestor(arch_name, anc) {
            anc_arch = self.arch_ast_map.get(anc);
            if anc_arch is not None {
                provided_methods.update(collect_method_names(anc_arch));
            }
        }
    }
    return (arch_name, mro, provided_methods);
}

impl NativeLowering._visit_nonprimary_ancestor_methods_ancestor(
    arch_name: str, ancestor_name: str
) -> (uni.Archetype | None) {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    layout_reg = get_layout_registry(self.module, self.prog);
    if layout_reg.is_primary_ancestor(arch_name, ancestor_name) {
        return None;
    }
    return self.arch_ast_map.get(ancestor_name);
}

impl NativeLowering._archetype_layout(
    nd: uni.Archetype, arch_name: str
) -> (ArchetypeLayout | None) {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    _owner_mod = nd.find_parent_of_type(uni.Module) or self.module;
    return get_layout_registry(_owner_mod, self.prog).get_layout(arch_name);
}

impl NativeLowering._archetype_field_order(layout: ArchetypeLayout) -> list[str] {
    import from jaclang.compiler.passes.layout_pass { EXC_MESSAGE_FIELD }
    return [
        f.name
        for f in layout.fields
        if f.name != EXC_MESSAGE_FIELD
    ];
}

impl NativeLowering._archetype_constructor_order(layout: ArchetypeLayout) -> list[str] {
    import from jaclang.compiler.field_semantics { positional_field_names }
    constructor_fields: list[uni.HasVar] = [];
    for field in layout.fields {
        declaration = field.decl_node;
        if isinstance(declaration, uni.HasVar) {
            constructor_fields.append(declaration);
        }
    }
    return positional_field_names(constructor_fields);
}

impl NativeLowering._reject_scalar_type_args_none_arg(arg: TypeBase) -> bool {
    if isinstance(arg, ClassType)
        and arg._shared is not None
        and arg.shared.class_name in ("NoneType", "None") {
        return True;
    }
    return False;
}

impl NativeLowering._register_class_consts_owns(nd: uni.Archetype) -> (bool | None) {
    import from jaclang.compiler.passes.layout_pass { class_form_enum_scalar }
    if nd.name is None or class_form_enum_scalar(nd.name.type) is not None {
        return None;
    }
    _owns = nd.find_parent_of_type(uni.Module) is self.module;
    return _owns;
}

impl NativeLowering._register_one_class_const_symbol(
    full_name: str, assign: uni.Assignment, owns: bool
) -> str {
    _owner = None if owns else assign.find_parent_of_type(uni.Module);
    symbol = self._symbol_for(full_name, _owner);
    return symbol;
}

impl NativeLowering._forward_declare_method_params(
    method: uni.Ability
) -> tuple[bool, list[uni.ParamVar]] {
    sig = method.signature;
    _is_static = method.is_static or method.is_classmethod;

    _m_params = sig.get_parameters() if isinstance(sig, uni.FuncSignature) else [];
    if (
        not _is_static
        and _m_params
        and _m_params[0].name
        and _m_params[0].name.value == "self"
    ) {
        _m_params = _m_params[1:];
    }
    if (
        method.is_classmethod
        and _m_params
        and _m_params[0].name
        and _m_params[0].name.value == "cls"
    ) {
        _m_params = _m_params[1:];
    }
    return (_is_static, _m_params);
}

impl NativeLowering._forward_declare_method_symbol(
    full_name: str, method: uni.Ability, imported: bool
) -> str {
    _owner = method.find_parent_of_type(uni.Module) if imported else None;
    return self._symbol_for(full_name, _owner);
}

impl NativeLowering._method_scan_closure_escapes(method: uni.Ability) -> None {
    _scan_body = ModuleFacts.unwrap_body(method);
    if _scan_body is not None {
        _scan_owner = method.body
            if isinstance(method.body, uni.ImplDef)
            else method;
        self._scan_closure_escapes(_scan_owner, _scan_body);
    }
}

impl NativeLowering._method_self_param(
    method: uni.Ability
) -> tuple[bool, list[uni.ParamVar], bool] {
    _is_static = method.is_static or method.is_classmethod;
    sig = method.signature;
    _body_params = sig.get_parameters()
        if isinstance(sig, uni.FuncSignature)
        else [];
    _self_param: (uni.ParamVar | None) = None;
    if (
        not _is_static
        and _body_params
        and _body_params[0].name
        and _body_params[0].name.value == "self"
    ) {
        _self_param = _body_params[0];
        _body_params = _body_params[1:];
    }
    _self_owned = _self_param is not None
        and self._nogc_owned_param(_self_param);
    return (_is_static, _body_params, _self_owned);
}

impl NativeLowering._method_bound_params(
    method: uni.Ability, body_params: list[uni.ParamVar]
) -> list[tuple[str, bool]] {
    _body_params = body_params;
    if (
        method.is_classmethod
        and _body_params
        and _body_params[0].name
        and _body_params[0].name.value == "cls"
    ) {
        _body_params = _body_params[1:];
    }

    _bound_params: list[tuple[(str, bool)]] = [
        (
            (p.name.value if p.name else f"arg{i}"),
            bool(p.name?.sym?.param_rebound),

        ) for (i, p) in enumerate(_body_params)
    ];
    return _bound_params;
}

impl NativeLowering._forward_declare_event_method_symbol(
    full_name: str, method: uni.Ability
) -> tuple[str, bool] {
    _owner = method.find_parent_of_type(uni.Module);
    _imported = _owner is not None and _owner is not self.module;
    return (self._symbol_for(full_name, _owner if _imported else None), _imported);
}

impl NativeLowering._instantiation_type_name(
    nd: (uni.FuncCall | uni.Name), type_name_override: (str | None)
) -> (str | None) {
    _ctor_ref = nd.target if isinstance(nd, uni.FuncCall) else nd;
    type_name = type_name_override
        if type_name_override is not None
        else (self._arch_ref_key(_ctor_ref) or self._get_name(_ctor_ref));
    return type_name;
}

impl NativeLowering._instantiation_stack_target(
    nd: (uni.FuncCall | uni.Name)
) -> (uni.Name | None) {
    _tgt_asgn = nd.find_parent_of_type(uni.Assignment);
    if _tgt_asgn is not None
        and len(_tgt_asgn.target) == 1
        and isinstance(_tgt_asgn.target[0], uni.Name) {
        return _tgt_asgn.target[0];
    }
    return None;
}

impl NativeLowering._instantiation_erased_ctor_type(
    nd: (uni.FuncCall | uni.Name)
) -> (TypeBase | None) {
    _ctor_t = nd.type;
    _ctor_asg = nd.parent;
    if isinstance(_ctor_asg, uni.Assignment)
        and _ctor_asg.value is nd
        and _ctor_asg.type_tag is not None
        and len(_ctor_asg.target) == 1 {
        _ctor_decl = _ctor_asg.target[0].type;
        if isinstance(_ctor_decl, ClassType)
            and isinstance(_ctor_t, ClassType)
            and _ctor_decl._shared is not None
            and _ctor_t._shared is not None
            and _ctor_decl.shared.class_name == _ctor_t.shared.class_name {
            _ctor_t = _ctor_decl;
        }
    }
    return _ctor_t;
}

impl NativeLowering._instantiation_init_owner_primary(
    type_name: str, init_owner: str
) -> bool {
    import from jaclang.compiler.passes.layout_pass {
        get_layout_registry as _ci_glr
    }
    return _ci_glr(self.module, self.prog).is_primary_ancestor(
        type_name, init_owner
    );
}

impl NativeLowering._instantiation_postinit_auto(type_name: str, no_init: bool) -> bool {
    _pi_auto = no_init;
    for _pi_cls in self._mro_of(type_name) {
        _pi_arch = self.arch_ast_map.get(_pi_cls);
        if _pi_arch is None {
            continue;
        }
        _pi_own_init = False;
        if _pi_arch.body is not None {
            for _pi_stmt in _pi_arch.body {
                if isinstance(_pi_stmt, uni.Ability)
                    and _pi_stmt.name_ref is not None
                    and _pi_stmt.name_ref.sym_name in ("init", "__init__") {
                    _pi_own_init = True;
                    break;
                }
            }
        }
        if _pi_own_init {
            _pi_auto = False;
            break;
        }
        _pi_fielded = False;
        for _pi_var in _pi_arch.get_has_vars() {
            if not _pi_var.accessors {
                _pi_fielded = True;
                break;
            }
        }
        if _pi_fielded {
            _pi_auto = True;
            break;
        }
    }
    return _pi_auto;
}

impl NativeLowering._unregistered_class_target_foreign(
    target: uni.UniNode, name: str
) -> (str | None) {
    if not isinstance(target, uni.Expr) {
        return None;
    }
    import from jaclang.compiler.symbol_utils { resolve_expr_symbol }
    sym = resolve_expr_symbol(target);
    decl = sym.decl if sym is not None else None;
    if decl is None {
        return None;
    }
    arch = decl.find_parent_of_type(uni.Archetype);
    if arch is None or arch.name is None or arch.name.value != name {
        return None;
    }
    decl_mod = decl.find_parent_of_type(uni.Module);
    path = decl_mod.loc.mod_path if decl_mod is not None else None;
    if not path or not path.endswith(".jac") {
        return None;
    }
    own_path = os.path.realpath(self.module.loc.mod_path) if self.module?.loc else "";
    if os.path.realpath(path) == own_path {
        return None;
    }
    return name;
}

impl NativeLowering._method_call_inner_names(
    trailer: uni.AtomTrailer
) -> tuple[str | None, str | None, str | None] {
    import from jaclang.compiler.symbol_utils { imported_module_name }
    module_name = imported_module_name(trailer.target);
    target_name = module_name or self._get_name(trailer.target);
    if module_name is None and target_name != "super" {
        target_name = self._arch_ref_key(trailer.target) or target_name;
    }
    method_name = self._get_name(trailer.right);
    return (module_name, target_name, method_name);
}

impl NativeLowering._method_call_inner_ctor_aliases(method_name: str) -> list[str] {
    _mnames = [method_name];
    if method_name == "postinit" {
        _mnames.append("__post_init__");
    } elif method_name == "init" {
        _mnames.append("__init__");
    }
    return _mnames;
}

impl NativeLowering._method_call_inner_region_partition(
    trailer: uni.AtomTrailer, method_name: str
) -> bool {
    if method_name == "partition" {
        import from jaclang.compiler.types.type_utils { is_builtin_region_type }
        if is_builtin_region_type(trailer.target.type) {
            return True;
        }
    }
    return False;
}

impl NativeLowering._method_call_inner_any_dict_receiver(
    trailer: uni.AtomTrailer, method_name: str
) -> bool {
    if (
        method_name in ("get", "keys", "values", "items", "setdefault", "update", "pop")
        and self._type_key_of(trailer.target) in ("any", "Any")
    ) {
        return True;
    }
    return False;
}

impl NativeLowering._method_call_inner_sys_exit(
    target_name: (str | None), method_name: str
) -> bool {
    if (
        target_name == "sys"
        and self._native_stdlib_modules
        and "sys" in self._native_stdlib_modules
    ) {
        if method_name == "exit" {
            return True;
        }
    }
    return False;
}

impl NativeLowering._method_call_inner_ospath(
    trailer: uni.AtomTrailer, module_name: (str | None)
) -> bool {
    import from jaclang.compiler.symbol_utils { imported_module_name }
    if module_name == "os.path"
        or (
            isinstance(trailer.target, uni.AtomTrailer)
            and trailer.target.is_attr
            and imported_module_name(trailer.target.target) == "os"
            and self._get_name(trailer.target.right) == "path"
            and self._native_stdlib_modules
            and "os" in self._native_stdlib_modules
        ) {
        return True;
    }
    return False;
}

impl NativeLowering._method_call_inner_os_environ(trailer: uni.AtomTrailer) -> bool {
    import from jaclang.compiler.symbol_utils { imported_module_name }
    if (
        isinstance(trailer.target, uni.AtomTrailer)
        and trailer.target.is_attr
        and imported_module_name(trailer.target.target) == "os"
        and self._get_name(trailer.target.right) == "environ"
        and self._native_stdlib_modules
        and "os" in self._native_stdlib_modules
    ) {
        return True;
    }
    return False;
}

impl NativeLowering._subclass_str_candidates -> dict[str, list[str]] {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    registry = get_layout_registry(self.module, self.prog);
    return registry.mro_order;
}

impl NativeLowering._subclass_str_is_descendant(cls: str, type_name: str) -> bool {
    if cls == type_name or type_name not in self._mro_of(cls) {
        return False;
    }
    return True;
}

impl NativeLowering._field_assign_static_target(
    target: uni.AtomTrailer
) -> (str | None) {
    _sa_target = self._arch_ref_key(target.target) or self._get_name(target.target);
    if _sa_target is None {
        _sa_tk = self._type_key_of(target.target);
        if _sa_tk is not None {
            _sa_tkn = _sa_tk.replace(" ", "");
            if _sa_tkn.startswith("type[") and _sa_tkn.endswith("]") {
                _sa_target = _sa_tkn[5:-1];
            }
        }
    }
    return _sa_target;
}

impl NativeLowering._receiver_routed_method_fn_primary(
    recv_cls: str, owner_cls: str
) -> bool {
    import from jaclang.compiler.passes.layout_pass {
        get_layout_registry as _sc_glr
    }
    _sc_reg = _sc_glr(self.module, self.prog);
    return _sc_reg.is_primary_ancestor(recv_cls, owner_cls);
}

impl NativeLowering._receiver_routed_method_fn_ancestor_method(
    owner_cls: str, mnames: list[str]
) -> (uni.Ability | None) {
    _anc_arch = self.arch_ast_map.get(owner_cls);
    _anc_meth: (uni.Ability | None) = None;
    if _anc_arch is not None and _anc_arch.body is not None {
        for _ab in _anc_arch.body {
            if isinstance(_ab, uni.Ability)
                and _ab.name_ref is not None
                and _ab.name_ref.sym_name in mnames
                and _ab.signature is not None {
                _anc_meth = _ab;
                break;
            }
        }
    }
    return _anc_meth;
}

impl NativeLowering._class_routed_call_defaults(
    sfull: str, mnames: list[str]
) -> dict[str, uni.UniNode] {
    _sdefaults: dict[str, uni.UniNode] = {};
    _sarch_nd = self.arch_ast_map.get(sfull.split(".")[0]);
    if _sarch_nd is not None and _sarch_nd.body is not None {
        for _sb in _sarch_nd.body {
            if isinstance(_sb, uni.Ability)
                and _sb.name_ref is not None
                and _sb.name_ref.sym_name in mnames
                and isinstance(_sb.signature, uni.FuncSignature) {
                for _sprm in _sb.signature.get_parameters() {
                    if isinstance(_sprm, uni.ParamVar)
                        and _sprm.name is not None
                        and _sprm.value is not None {
                        _sdefaults[_sprm.name.value] = _sprm.value;
                    }
                }
                break;
            }
        }
    }
    return _sdefaults;
}

impl NativeLowering._jc_reference_schema_semantic(
    semantic: (TypeBase | None)
) -> tuple[list[TypeBase], str] {
    args = semantic.private.type_args or [] if isinstance(semantic, ClassType) else [];
    import from jaclang.compiler.passes.layout_pass { class_type_native_name }
    semantic_name = (class_type_native_name(semantic) or "")
        if isinstance(semantic, ClassType)
        else "";
    return (args, semantic_name);
}
