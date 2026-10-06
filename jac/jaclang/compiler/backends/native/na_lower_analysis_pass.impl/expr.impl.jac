impl NativeLowering._is_root_walker_operand(nd: uni.UniNode) -> bool {
    typ = nd.type if isinstance(nd, uni.Expr) else None;
    return isinstance(typ, ClassType)
        and typ.is_instance()
        and typ.shared.class_name == "Walker";
}

impl NativeLowering._is_walker_arch(name: str) -> bool {
    _model = self.module.gen.native_osp_model;
    return (_model is not None) and (_model.arch_kind.get(name) == "walker");
}

impl NativeLowering._ct_type_param_owner(nd: uni.Name) -> (str | None) {
    sym = nd.sym;
    if sym is None {
        return None;
    }
    owner = sym.decl.name_of;
    if not (isinstance(owner, uni.TypeParam) and owner.is_comptime) {
        return None;
    }
    arch = owner.find_parent_of_type(uni.Archetype);
    return self._arch_key(arch) if arch is not None else None;
}

impl NativeLowering._reads_unlowered_local_names(nd: uni.UniNode) -> list[uni.Name] {
    return [nd] if isinstance(nd, uni.Name) else nd.get_all_sub_nodes(uni.Name);
}

impl NativeLowering._lambda_inferred_return(nd: uni.LambdaExpr) -> (TypeBase | None) {
    if isinstance(nd.type, SemanticFunctionType) and nd.type.return_type is not None {
        return nd.type.return_type;
    }
    return None;
}

impl NativeLowering._lambda_free_var_names(nd: uni.LambdaExpr) -> list[str] {
    free_var_names: list[str] = [];
    for cap_sym in nd.captures {
        if cap_sym.sym_name not in free_var_names {
            free_var_names.append(cap_sym.sym_name);
        }
    }
    return free_var_names;
}

impl NativeLowering._name_sized_type_ref(nd: uni.Name, var_name: str) -> bool {
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    _np = nd.parent;
    _is_call_target = isinstance(_np, uni.FuncCall) and _np.target is nd;
    return JAC_TYPE_REGISTRY.is_sized(var_name) and not _is_call_target;
}

impl NativeLowering._walrus_target_name(nd: uni.BinaryExpr) -> (str | None) {
    var_name = self._get_name(nd.left);
    if var_name is None {
        self.emit(E5092, node_override=nd, kind="binary operator", name="WALRUS_EQ");
        return None;
    }
    return var_name;
}

impl NativeLowering._spawn_walker_side(
    nd: uni.BinaryExpr, left_name: (str | None), right_name: (str | None)
) -> str {
    left_is_walker = left_name is not None and self._is_walker_arch(left_name);
    right_is_walker = right_name is not None and self._is_walker_arch(right_name);
    if left_name is not None and left_is_walker {
        return "left";
    } elif right_name is not None and right_is_walker {
        return "right";
    } elif self._is_root_walker_operand(nd.right)
        or self._is_root_walker_operand(nd.left) {
        _root_right = self._is_root_walker_operand(nd.right);
        return "root_right" if _root_right else "root_left";
    }
    return "none";
}

impl NativeLowering._spawn_walker_in_model(walker_name: str) -> bool {
    _spawn_model = self.module.gen.native_osp_model;
    return (_spawn_model is not None) and (walker_name in _spawn_model.tags);
}

impl NativeLowering._compare_link_membership_shape(
    left_node: uni.UniNode, right_node: uni.UniNode
) -> tuple[uni.UniNode, uni.UniNode, str, bool] {
    _in_key_nd = left_node.expr
        if isinstance(left_node, uni.CfgExpr)
        else left_node;
    _in_hay_nd = right_node.expr
        if isinstance(right_node, uni.CfgExpr)
        else right_node;
    _in_hay_tk = self._type_key_of(_in_hay_nd) or "";
    _in_hay_cont = (
        _in_hay_tk.startswith("list[")
        or _in_hay_tk.startswith("dict[")
        or _in_hay_tk.startswith("set[")
        or _in_hay_tk.startswith("frozenset[")
        or _in_hay_tk.startswith("tuple[")
    );
    return (_in_key_nd, _in_hay_nd, _in_hay_tk, _in_hay_cont);
}

impl NativeLowering._compare_link_list_str_elems(
    left_node: uni.UniNode, right_node: uni.UniNode
) -> bool {
    _lin_left_tk = self._type_key_of(left_node);
    _lin_coll_tk = self._type_key_of(right_node) or "";
    return _lin_left_tk == "str" or _lin_coll_tk.startswith("list[str");
}

impl NativeLowering._compare_link_list_key(
    hay_nd: uni.UniNode, left_node: uni.UniNode
) -> (TypeBase | None) {
    _lin_args = self._agg_key_args(hay_nd.type, "list")
        if isinstance(hay_nd, uni.Expr)
        else None;
    _lin_key = _lin_args[0] if _lin_args else None;
    if _lin_key is not None
        and _lin_key.is_any_type()
        and isinstance(left_node, uni.Expr)
        and left_node.type is not None
        and not left_node.type.is_any_type() {
        _lin_key = left_node.type;
    }
    return _lin_key;
}

impl NativeLowering._compare_link_tuple_args(hay_nd: uni.UniNode) -> list[TypeBase] {
    return (
        self._agg_key_args(hay_nd.type, "tuple")
            if isinstance(hay_nd, uni.Expr)
            else None
    )
        or [];
}

impl NativeLowering._atom_trailer_class_form_enum(
    nd: uni.AtomTrailer, right_name: (str | None)
) -> tuple[str, (str | None)] {
    if right_name == "value" or right_name == "name" {
        import from jaclang.compiler.passes.layout_pass {
            class_form_enum_member,
            class_form_enum_scalar
        }
        _cf_owner = class_form_enum_member(
            nd.target.type if isinstance(nd.target, uni.Expr) else None
        );
        if _cf_owner is not None {
            if right_name == "value" {
                return ("member", None);
            }
            return ("name", _cf_owner[2]);
        }
        if right_name == "value"
            and isinstance(nd.target, uni.Expr)
            and class_form_enum_scalar(nd.target.type) is not None {
            return ("scalar", None);
        }
    }
    return ("", None);
}

impl NativeLowering._atom_trailer_alias_origin(nd: uni.UniNode) -> (str | None) {
    if isinstance(nd, uni.Name) and nd.sym is not None and nd.sym.decl is not None {
        _al_of = nd.sym.decl.name_of;
        if _al_of is not None
            and isinstance(_al_of.parent, uni.ModuleItem)
            and isinstance(_al_of.parent.name, uni.Name) {
            return _al_of.parent.name.value;
        }
    }
    return None;
}

impl NativeLowering._atom_trailer_enum_key(nd: uni.AtomTrailer) -> (str | None) {
    _re_tk = self._type_key_of(nd.target);
    if _re_tk is not None {
        _re_tk = _re_tk.replace(" ", "").split(".")[-1];
    }
    return _re_tk;
}

impl NativeLowering._atom_trailer_type_member_name(
    nd: uni.AtomTrailer, right_name: (str | None)
) -> (str | None) {
    if right_name is not None and (right_name == "value" or right_name == "name") {
        _mt_tk = self._type_key_of(nd.target);
        if _mt_tk is not None {
            _mt_tk = _mt_tk.replace(" ", "");
        }
        if _mt_tk is not None and _mt_tk.startswith("type[") and "]." in _mt_tk {
            _mt_cls = _mt_tk[5:_mt_tk.index("]")];
            _mt_mem = _mt_tk.split("].", 1)[1];
            if right_name == "name" {
                return _mt_mem;
            }
        }
    }
    return None;
}

impl NativeLowering._atom_trailer_type_alias_class(nd: uni.AtomTrailer) -> (str | None) {
    _tk_alias = self._type_key_of(nd.target);
    if _tk_alias is not None {
        _tk_alias = _tk_alias.replace(" ", "");
    }
    if _tk_alias is not None
        and _tk_alias.startswith("type[")
        and _tk_alias.endswith("]") {
        return _tk_alias[5:-1];
    }
    return None;
}

impl NativeLowering._atom_trailer_imported_module(
    nd: uni.AtomTrailer, target_name: (str | None)
) -> tuple[(str | None), (str | None)] {
    import from jaclang.compiler.symbol_utils { imported_module_name }
    module_name = imported_module_name(nd.target);
    if module_name is not None {
        target_name = module_name;
    }
    return (module_name, target_name);
}

impl NativeLowering._atom_trailer_native_stdlib_is(
    module_name: (str | None), wanted: str
) -> bool {
    if (
        module_name == wanted
        and self._native_stdlib_modules
        and wanted in self._native_stdlib_modules
    ) {
        return True;
    }
    return False;
}
