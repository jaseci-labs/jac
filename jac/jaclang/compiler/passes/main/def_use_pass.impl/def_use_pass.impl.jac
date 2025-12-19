impl DefUsePass.enter_expr_as_item(self: DefUsePass, node: uni.ExprAsItem) -> None {
    if node.alias {
        if isinstance(node.alias, uni.AtomTrailer) {
            ((node.alias).sym_tab).chain_def_insert((node.alias).as_attr_list);
        } elif isinstance(node.alias, uni.AstSymbolNode) {
            ((node.alias).sym_tab).def_insert(node.alias);
        } else {
            self.log_error("For expr as target not valid");
        }
    }
}

impl DefUsePass.enter_in_for_stmt(self: DefUsePass, node: uni.InForStmt) -> None {
    if isinstance(node.target, uni.AtomTrailer) {
        ((node.target).sym_tab).chain_def_insert((node.target).as_attr_list);
    } elif isinstance(node.target, uni.AstSymbolNode) {
        ((node.target).sym_tab).def_insert(node.target);
    } else {
        self.log_error("For loop assignment target not valid");
    }
}

impl DefUsePass.enter_name(self: DefUsePass, node: uni.Name) -> None {
    if not isinstance(node.parent, uni.AtomTrailer) {
        (node.sym_tab).use_lookup(node);
    }
}

impl DefUsePass.enter_builtin_type(self: DefUsePass, node: uni.BuiltinType) -> None {
    (node.sym_tab).use_lookup(node);
}

impl DefUsePass.enter_bool(self: DefUsePass, node: uni.Bool) -> None {
    (node.sym_tab).use_lookup(node);
}

impl DefUsePass.enter_string(self: DefUsePass, node: uni.String) -> None {
    (node.sym_tab).use_lookup(node);
}

impl DefUsePass.enter_int(self: DefUsePass, node: uni.Int) -> None {
    (node.sym_tab).use_lookup(node);
}

impl DefUsePass.enter_float(self: DefUsePass, node: uni.Float) -> None {
    (node.sym_tab).use_lookup(node);
}

impl DefUsePass.enter_special_var_ref(
    self: DefUsePass, node: uni.SpecialVarRef
) -> None {
    (node.sym_tab).use_lookup(node);
}

impl DefUsePass.enter_atom_trailer(self: DefUsePass, node: uni.AtomTrailer) -> None {
    chain = node.as_attr_list;
    (node.sym_tab).chain_use_lookup(chain);
}

impl DefUsePass.enter_inner_compr(self: DefUsePass, node: uni.InnerCompr) -> None {
    if isinstance(node.target, uni.AtomTrailer) {
        ((node.target).sym_tab).chain_def_insert((node.target).as_attr_list);
    } elif isinstance(node.target, uni.AstSymbolNode) {
        ((node.target).sym_tab).def_insert(node.target);
    } else {
        self.log_error("Named target not valid");
    }
}

impl DefUsePass.enter_assignment(self: DefUsePass, node: uni.Assignment) -> None {
    for i in node.target {
        if isinstance(i, uni.AtomTrailer) {
            (i.sym_tab).chain_def_insert(i.as_attr_list);
        } elif isinstance(i, uni.AstSymbolNode) {
            (i.sym_tab).def_insert(i);
        } else {
            self.log_error("Assignment target not valid");
        }
    }
}

impl DefUsePass.enter_has_var(self: DefUsePass, node: uni.HasVar) -> None {
    if isinstance(node.parent, uni.ArchHas) {
        (node.sym_tab).def_insert(node, single_decl="has var", access_spec=node.parent);
    } else {
        self.ice("Inconsistency in AST, has var should be under arch has");
    }
}

impl DefUsePass.enter_param_var(self: DefUsePass, node: uni.ParamVar) -> None {
    (node.sym_tab).def_insert(node);
}

impl DefUsePass.enter_type_ref(self: DefUsePass, node: uni.TypeRef) -> None {
    (node.sym_tab).use_lookup(node);
}

"""Jac Ast build pass."""
impl DefUsePass.enter_archetype(self: DefUsePass, node: uni.Archetype) -> None {
    def inform_from_walker(n: uni.UniNode) -> None {
        for i in (
            n.get_all_sub_nodes(uni.VisitStmt) + n.get_all_sub_nodes(uni.DisengageStmt) + n.get_all_sub_nodes(
                uni.EdgeOpRef
            ) + n.get_all_sub_nodes(uni.EventSignature) + n.get_all_sub_nodes(
                uni.TypedCtxBlock
            )
        ) {
            i.from_walker = True;
        }
    }
    if node.arch_type.name == Tok.KW_WALKER {
        inform_from_walker(node);
        for i in self.get_all_sub_nodes(node, uni.Ability) {
            if isinstance(i.body, uni.ImplDef) {
                inform_from_walker(i.body);
            }
        }
    }
}
