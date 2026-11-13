impl NaIRGenPass._osp_static_edge_name(expr: uni.UniNode) -> (str | None) {
    while isinstance(expr, uni.AtomUnit) {
        expr = expr.value;
    }
    if not isinstance(expr, uni.Name)
        or expr.value in self.local_vars
        or expr.value in self.global_vars {
        return None;
    }
    name = self._arch_ref_key(expr) or expr.value;
    model = self.module.gen.native_osp_model;
    return name if model is not None and model.arch_kind.get(name) == "edge" else None;
}

impl NaIRGenPass._osp_edge_class_name(expr: uni.UniNode) -> (str | None) {
    return self._class_expr_bound(expr, unbounded="Edge");
}

impl NaIRGenPass._osp_edge_tag(
    expr: (uni.UniNode | None), nd: uni.UniNode, descriptor: (ir.Value | None) = None
) -> (ir.Value | None) {
    i64 = ir.IntType(64);
    if expr is None {
        return ir.Constant(i64, -1);
    }
    name = self._osp_static_edge_name(expr);
    model = self.module.gen.native_osp_model;
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
    lookup = self.scope.function("osp_edge_type");
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
    existing = self.scope.function(symbol);
    if existing is not None {
        return existing;
    }
    fn = self._define_function(symbol, ir.FunctionType(ir.IntType(64), []));
    fn.linkage = "internal";
    self.scope.bind_function(symbol, fn);
    return fn;
}

impl NaIRGenPass._osp_edge_ctor_args(name: str) -> list[str] {
    required: list[str] = [];
    init_params = self._arch_init_params_of(name);
    if init_params is not None {
        for param in init_params {
            if param.value is None
                and param.unpack is None
                and param.name is not None {
                required.append(param.name.sym_name);
            }
        }
        return required;
    }
    defaults = self.struct_field_defaults.get(name, {});
    for field in self.struct_constructor_order.get(name, []) {
        if field not in defaults {
            required.append(field);
        }
    }
    return required;
}

impl NaIRGenPass._osp_edge_ctor_assigns(
    co: uni.ConnectOp, name: str
) -> list[uni.KWPair] {
    if co.conn_assign is None {
        return [];
    }
    required = self._osp_edge_ctor_args(name);
    if not required {
        return [];
    }
    given: list[uni.KWPair] = [];
    named: set[str] = set();
    for kw in co.conn_assign.assigns {
        key = self._get_name(kw.key) if kw.key is not None else None;
        if key is not None and key in required {
            given.append(kw);
            named.add(key);
        }
    }
    for field in required {
        if field not in named {
            return [];
        }
    }
    return given;
}

impl NaIRGenPass._osp_edge_build_with(
    co: uni.ConnectOp,
    name: str,
    ctor_kws: list[uni.KWPair],
    held: (list[tuple[ir.Value, ir.Value]] | None),
    early: (dict[int, ir.Value] | None),
    nd: uni.UniNode
) -> (ir.Value | None) {
    arch = self.arch_ast_map.get(name);
    assign = co.conn_assign;
    if arch is None or assign is None {
        self.emit(E5092, node_override=nd, kind="binary operator", name="ConnectOp");
        return None;
    }
    errors_before = len(self.ctx.errors_had);
    built: (ir.Value | None) = None;
    if held is None {
        pre: dict[int, ir.Value] = {};
        if early is not None {
            for kw in ctor_kws {
                if id(kw.value) in early {
                    pre[id(kw.value)] = early.pop(id(kw.value));
                }
            }
        }
        built = self._codegen_instantiation(
            arch.name, type_name_override=name, ctor_params=list(ctor_kws), ctor_pre=pre
        );
    } else {
        if self._arch_init_params_of(name) is not None {
            self.emit(
                E5092,
                node_override=assign,
                kind="connect operand",
                name="list",
                help_text=(
                    "A connect with a list of nodes builds every edge from the "
                    "same constructor arguments, which an edge type with its "
                    "own `init` does not take here. Connect in a loop."
                )
            );
            return None;
        }
        ctor_names: set[str] = set();
        for kw in ctor_kws {
            ctor_names.add(self._get_name(kw.key) or "");
        }
        values: dict[str, ir.Value] = {};
        for (position, kw) in enumerate(assign.assigns) {
            key = self._get_name(kw.key) if kw.key is not None else None;
            if key is not None and key in ctor_names {
                values[key] = self.builder.load(
                    held[position][0], name="edge.ctor.held"
                );
            }
        }
        built = self._codegen_instantiation(
            arch.name, type_name_override=name, ctor_values=values
        );
    }
    if built is None {
        if len(self.ctx.errors_had) == errors_before {
            self.emit(
                E5092, node_override=nd, kind="binary operator", name="ConnectOp"
            );
        }
        return None;
    }
    i8p = ir.IntType(8).as_pointer();
    if isinstance(built.type, ir.PointerType) {
        return self.builder.bitcast(built, i8p, name="edge.new");
    }
    return self.builder.inttoptr(built, i8p, name="edge.new");
}

impl NaIRGenPass._emit_osp_edge_factories -> None {
    model = self.module.gen.native_osp_model;
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
            init_params = self._arch_init_params_of(name);
            if init_params is not None {
                for param in init_params {
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
