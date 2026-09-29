import from jaclang.compiler.c_interop { is_ptr_view_type }
import from jaclang.compiler.types.types { ClassType, UnionType }
import from jaclang.compiler.frontend.diagnostics { E1315 }

impl OwnershipCheckPass._is_c_view(expr: (UniNode | None)) -> bool {
    if not isinstance(expr, Expr) or not is_ptr_view_type(expr.type) {
        return False;
    }
    view_type = expr.type;
    return view_type is not None
        and view_type.is_instance()
        and expr.find_parent_of_type(SubTag) is None;
}

impl OwnershipCheckPass._mentions_c_view(t: (TypeBase | None), depth: int = 0) -> bool {
    if depth > 8 or t is None {
        return False;
    }
    if is_ptr_view_type(t) {
        return True;
    }
    if isinstance(t, UnionType) {
        for member in t.types {
            if self._mentions_c_view(member, depth + 1) {
                return True;
            }
        }
    }
    if isinstance(t, ClassType) {
        for arg in (t.private.type_args or []) {
            if self._mentions_c_view(arg, depth + 1) {
                return True;
            }
        }
    }
    return False;
}

impl OwnershipCheckPass._c_view_escape(site: UniNode, what: str) -> None {
    self.ctx.emit(E1315, node_override=site, name=what);
}

impl OwnershipCheckPass._emit_c_view_diagnostics -> None {
    mod = self.module;
    for ret in mod.get_all_sub_nodes(ReturnStmt) {
        if self._is_c_view(ret.expr) {
            self._c_view_escape(ret, "returning a C memory view");
        }
    }
    for yld in mod.get_all_sub_nodes(YieldExpr) {
        if self._is_c_view(yld.expr) {
            self._c_view_escape(yld, "yielding a C memory view");
        }
    }
    for hv in mod.get_all_sub_nodes(HasVar) {
        if self._mentions_c_view(hv.type) {
            self._c_view_escape(hv, "a C memory view as a field");
        }
    }
    for gv in mod.get_all_sub_nodes(GlobalVars) {
        for asg in gv.get_all_sub_nodes(Assignment) {
            for tgt in asg.target {
                if isinstance(tgt, Name) and self._mentions_c_view(tgt.type) {
                    self._c_view_escape(asg, "a C memory view as a module global");
                }
            }
        }
    }
    for nd in mod.get_all_sub_nodes(Assignment) {
        if not self._is_c_view(nd.value) {
            continue;
        }
        if nd.type_tag is not None and nd.type_tag.ownership == OwnershipKind.OWN {
            self._c_view_escape(nd, "an `own` binding of a C memory view");
            continue;
        }
        for tgt in nd.target {
            if isinstance(tgt, AtomTrailer) {
                self._c_view_escape(
                    nd, "storing a C memory view into a field or element"
                );
                break;
            }
            if isinstance(tgt, Name)
                and tgt.sym is not None
                and tgt.sym.storage == SymbolStorage.MODULE_GLOBAL
                and tgt.sym.decl is not None
                and tgt.sym.decl.find_parent_of_type(GlobalVars) is not None {
                self._c_view_escape(nd, "storing a C memory view into a module global");
                break;
            }
        }
    }
    literals: list[UniNode] = mod.get_all_sub_nodes(ListVal)
        + mod.get_all_sub_nodes(SetVal)
        + mod.get_all_sub_nodes(TupleVal);
    for lit in literals {
        if isinstance(lit.parent, Assignment) and lit in lit.parent.target {
            continue;
        }
        for elem in (lit.values or []) {
            if self._is_c_view(elem) {
                self._c_view_escape(elem, "a C memory view in a container");
            }
        }
    }
    for dct in mod.get_all_sub_nodes(DictVal) {
        for kv in (dct.kv_pairs or []) {
            for elem in (kv.key, kv.value) {
                if elem is not None and self._is_c_view(elem) {
                    self._c_view_escape(elem, "a C memory view in a container");
                }
            }
        }
    }
    for call in mod.get_all_sub_nodes(FuncCall) {
        grow = self._nogc_container_grow_method(call);
        if grow is None {
            continue;
        }
        for arg in self._call_params(call) {
            value = arg.value if isinstance(arg, KWPair) else arg;
            if self._is_c_view(value) {
                self._c_view_escape(
                    value, f"storing a C memory view into a container ({grow}())"
                );
            }
        }
    }
    for conc in mod.get_all_sub_nodes(ConcurrentExpr) {
        for sub in conc.get_all_sub_nodes(Name) {
            if self._is_c_view(sub) {
                self._c_view_escape(sub, "sending a C memory view across flow");
                break;
            }
        }
    }
}
