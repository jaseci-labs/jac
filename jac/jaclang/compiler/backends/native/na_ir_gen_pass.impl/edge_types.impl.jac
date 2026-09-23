impl NaIRGenPass._osp_static_edge_name(expr: uni.UniNode) -> (str | None) {
    while isinstance(expr, uni.AtomUnit) {
        expr = expr.value;
    }
    if not isinstance(expr, uni.Name)
        or expr.value in self.local_vars
        or expr.value in self.global_vars {
        return None;
    }
    name = self._arch_alias_target(expr) or expr.value;
    model = self.module.gen.osp_model;
    return name if model is not None and model.arch_kind.get(name) == "edge" else None;
}

impl NaIRGenPass._osp_edge_class_name(expr: uni.UniNode) -> (str | None) {
    while isinstance(expr, uni.AtomUnit) {
        expr = expr.value;
    }
    if not isinstance(expr, uni.Expr) or not isinstance(expr.type, ClassType) {
        return None;
    }
    typ = expr.type;
    if typ.is_builtin("type") {
        args = typ.private.type_args or [];
        if not args or not isinstance(args[0], ClassType) {
            return "Edge";
        }
        typ = args[0];
    } elif not typ.is_instantiable() or typ.is_instance() {
        return None;
    }
    return typ.shared.class_name;
}

impl NaIRGenPass._osp_edge_tag(
    expr: (uni.UniNode | None), nd: uni.UniNode, descriptor: (ir.Value | None) = None
) -> (ir.Value | None) {
    i64 = ir.IntType(64);
    if expr is None {
        return ir.Constant(i64, -1);
    }
    name = self._osp_static_edge_name(expr);
    model = self.module.gen.osp_model;
    if name is not None and model is not None {
        return ir.Constant(i64, model.tags[name]);
    }
    desc = descriptor
        if descriptor is not None
        else self._osp_edge_descriptor(expr, nd);
    if desc is None {
        return None;
    }
    tag = self.builder.load(
        self._field_slot_ptr(desc, "tag", "OspEdgeTypeDesc"), name="edge.tag"
    );
    if descriptor is None {
        self._emit_rc_release_simple(desc, op="edge_type");
    }
    return tag;
}

impl NaIRGenPass._osp_edge_descriptor(
    expr: uni.UniNode, nd: uni.UniNode
) -> (ir.Value | None) {
    if self._osp_edge_class_name(expr) is None {
        self.emit(
            E5092, node_override=nd, kind="edge type", name="non-class expression"
        );
        return None;
    }
    lookup = self.func_symtab.get("osp_edge_type");
    value = self._codegen_expr(expr);
    if lookup is None or value is None {
        self.emit(
            E5092,
            node_override=nd,
            kind="edge type",
            name=self._get_name(expr) or "expression"
        );
        return None;
    }
    if self._osp_ensure_fn is not None {
        self.builder.call(self._osp_ensure_fn, []);
    }
    descriptor = self.builder.call(
        lookup,
        [self._coerce_type(value, lookup.function_type.args[0])],
        name="edge.type"
    );
    self._emit_pending_error_check();
    return descriptor;
}

impl NaIRGenPass._osp_edge_factory(name: str) -> ir.Function {
    symbol = f"__osp_edge_new.{name}";
    existing = self.func_symtab.get(symbol);
    if existing is not None {
        return existing;
    }
    fn = self._define_function(symbol, ir.FunctionType(ir.IntType(64), []));
    fn.linkage = "internal";
    self.func_symtab[symbol] = fn;
    return fn;
}

impl NaIRGenPass._emit_osp_edge_factories -> None {
    model = self.module.gen.osp_model;
    if model is None or self._osp_setup_fn is None {
        return;
    }
    for name in model.order {
        if model.arch_kind.get(name) != "edge" {
            continue;
        }
        fn = self._osp_edge_factory(name);
        if fn.blocks {
            continue;
        }
        state = self._enter_function(fn);
        try {
            arch = self.arch_ast_map.get(name);
            constructible = arch is not None and self._demoted_init_of(name) is None;
            init_sig: uni.FuncSignature | None = None;
            for owner in self._mro_of(name) {
                init_sig = self._arch_init_sig_of(owner);
                if init_sig is not None {
                    break;
                }
            }
            if init_sig is not None {
                for param in init_sig.get_parameters() {
                    if param.value is None {
                        constructible = False;
                    }
                }
            } else {
                defaults = self.struct_field_defaults.get(name, {});
                for field in self.struct_constructor_order.get(name, []) {
                    if field not in defaults {
                        constructible = False;
                    }
                }
            }
            result: ir.Value = ir.Constant(ir.IntType(64), 0);
            if constructible and arch is not None {
                value = self._codegen_instantiation(arch.name, type_name_override=name);
                if value is not None {
                    result = self.builder.ptrtoint(value, ir.IntType(64));
                }
            }
            self.builder.ret(result);
        } finally {
            self._leave_function(state);
        }
    }
}
