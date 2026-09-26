import from jaclang.compiler.frontend.constant { SymbolType }
import from jaclang.compiler.field_semantics { field_initialization }

glob CLASS_CTOR_BUCKETS: int = 256,
     CLASS_CTOR_REGISTRY: str = "__jac_class_ctors",
     CLASS_CTOR_MAX_PARAMS: int = 63,
     CLASS_REFERENCE_SYMBOLS: tuple[SymbolType, ...] = (
         SymbolType.OBJECT_ARCH,
         SymbolType.NODE_ARCH,
         SymbolType.EDGE_ARCH,
         SymbolType.WALKER_ARCH,
         SymbolType.ENUM_ARCH,
         SymbolType.MODULE
     );

impl NaIRGenPass._class_expr_bound(
    expr: (uni.UniNode | None), unbounded: (str | None) = None
) -> (str | None) {
    while isinstance(expr, uni.AtomUnit) {
        expr = expr.value;
    }
    if not isinstance(expr, uni.Expr) or not isinstance(expr.type, ClassType) {
        return None;
    }
    typ = expr.type;
    if typ.is_builtin("type") {
        import from jaclang.compiler.types.types { TypeVarType }
        args = typ.private.type_args or [];
        arg = args[0] if args else None;
        if isinstance(arg, TypeVarType) {
            arg = arg.bound;
        }
        if not isinstance(arg, ClassType) {
            return unbounded;
        }
        typ = arg;
    } elif not typ.is_instantiable() or typ.is_instance() {
        return None;
    }
    import from jaclang.compiler.passes.layout_pass { class_type_native_name }
    return class_type_native_name(typ);
}

impl NaIRGenPass._is_runtime_class_value(target: (uni.UniNode | None)) -> bool {
    while isinstance(target, uni.AtomUnit) {
        target = target.value;
    }
    if isinstance(target, uni.Name) {
        if target.value not in self.local_vars
            and target.value not in self.global_vars {
            return False;
        }
        if self._arch_alias_target(target) is not None {
            return False;
        }
    } elif isinstance(target, uni.AtomTrailer) {
        if target.is_attr {
            attr = target.right;
            sym = attr.sym if isinstance(attr, uni.AstSymbolNode) else None;
            if sym is None or sym.sym_type in CLASS_REFERENCE_SYMBOLS {
                return False;
            }
        } elif self._class_expr_bound(target.target) is not None {
            return False;
        }
    } elif not isinstance(target, uni.FuncCall) {
        return False;
    }
    return self._class_expr_bound(target, unbounded="type") is not None;
}

impl NaIRGenPass._class_value_ctor_bound(target: (uni.UniNode | None)) -> (str | None) {
    if not self._is_runtime_class_value(target) {
        return None;
    }
    bound = self._class_expr_bound(target);
    if bound is None or bound not in self.struct_types or self._is_enum_arch(bound) {
        return None;
    }
    return bound;
}

impl NaIRGenPass._class_ancestors(type_name: str) -> list[str] {
    ancestors: list[str] = [type_name];
    index = 0;
    while index < len(ancestors) {
        for step in self._mro_of(ancestors[index]) {
            if step not in ancestors {
                ancestors.append(step);
            }
        }
        index += 1;
    }
    return ancestors;
}

impl NaIRGenPass._class_init_owner(type_name: str) -> (str | None) {
    for cls in self._mro_of(type_name) {
        for slot in ("init", "__init__") {
            if f"{cls}.{slot}" in self.method_funcs {
                return cls;
            }
        }
    }
    return None;
}

impl NaIRGenPass._class_takes_no_ctor_args(type_name: str) -> bool {
    if self._class_init_owner(type_name) is not None
        or self._pyb_base_of(type_name) is not None
        or self._is_enum_arch(type_name) {
        return False;
    }
    for cls in self._class_ancestors(type_name) {
        arch = self.arch_ast_map.get(cls);
        if not isinstance(arch, uni.Archetype) or arch.arch_type.name != Tok.KW_CLASS {
            return False;
        }
    }
    return True;
}

impl NaIRGenPass._class_ctor_params(type_name: str) -> (list[NativeCtorParam] | None) {
    if type_name not in self.struct_types
        or self._is_enum_arch(type_name)
        or type_name in self.clib_vtable_structs
        or self.arch_type_params.get(type_name)
        or self._pyb_base_of(type_name) is not None {
        return None;
    }
    owner = self._class_init_owner(type_name);
    if owner is not None {
        init_fn = self.method_funcs.get(f"{owner}.init")
            or self.method_funcs.get(f"{owner}.__init__");
        sig = self._arch_init_sig_of(owner);
        declared = self._arch_init_params_of(owner);
        if init_fn is None
            or sig is None
            or declared is None
            or sig.varargs is not None
            or sig.kwargs is not None
            or len(init_fn.args) != len(declared) + 1 {
            return None;
        }
        keyword_only = [id(p) for p in sig.kwonlyargs];
        return [
            NativeCtorParam(
                name=p.name.sym_name,
                type=init_fn.args[i + 1].type,
                fallback=p.value,
                positional=id(p) not in keyword_only
            ) for (i, p) in enumerate(declared)
        ];
    }
    if self._class_takes_no_ctor_args(type_name) {
        return [];
    }
    layout = self._arch_layout(type_name);
    if layout is None {
        return None;
    }
    field_types = self.struct_field_types.get(type_name, {});
    defaults = self.struct_field_defaults.get(type_name, {});
    foreign = self.struct_field_foreign.get(type_name, set());
    inline = self.struct_field_inline.get(type_name, None) or set();
    positional = self.struct_constructor_order.get(type_name, []);
    params: list[NativeCtorParam] = [];
    for field in layout.fields {
        decl = field.decl_node;
        if not isinstance(decl, uni.HasVar)
            or decl.defer
            or not field_initialization(decl).participates_in_init
            or field.name in foreign {
            continue;
        }
        ftype = field_types.get(field.name);
        if ftype is None or field.name in inline {
            return None;
        }
        params.append(
            NativeCtorParam(
                name=field.name,
                type=ftype,
                fallback=defaults.get(field.name),
                positional=field.name in positional
            )
        );
    }
    return params;
}

impl NaIRGenPass._class_ctor_fn_type(params: list[NativeCtorParam]) -> ir.FunctionType {
    return ir.FunctionType(
        ir.IntType(8).as_pointer(), [ir.IntType(64)] + [p.type for p in params]
    );
}

impl NaIRGenPass._bind_class_ctor_args(
    nd: uni.FuncCall,
    args: list[uni.Expr | uni.KWPair],
    params: list[NativeCtorParam],
    bound: str
) -> (tuple[list[tuple[int, uni.Expr]], uni.Expr | None] | None) {
    positional = [
        i
        for (i, p) in enumerate(params)
        if p.positional
    ];
    bound_args: list[tuple[int, uni.Expr]] = [];
    spread: (uni.Expr | None) = None;
    taken: set[int] = set();
    next_positional = 0;
    problem: (str | None) = None;
    for arg in args {
        index = -1;
        value: (uni.Expr | None) = None;
        if isinstance(arg, uni.KWPair) {
            key = arg.key.sym_name if arg.key is not None else None;
            if key is None {
                if spread is not None {
                    problem = "only one `**` mapping can be unpacked into a class-value constructor";
                    break;
                }
                spread = arg.value;
                continue;
            }
            for (i, p) in enumerate(params) {
                if p.name == key {
                    index = i;
                }
            }
            if index < 0 {
                problem = f"'{self._arch_display(
                    bound
                )}' has no constructor parameter named '{key}'";
                break;
            }
            value = arg.value;
        } elif isinstance(arg, uni.UnaryExpr)
            and isinstance(arg.op, uni.Token)
            and arg.op.name == Tok.STAR_POW {
            if spread is not None {
                problem = "only one `**` mapping can be unpacked into a class-value constructor";
                break;
            }
            spread = arg.operand;
            continue;
        } elif isinstance(arg, uni.UnaryExpr)
            and isinstance(arg.op, uni.Token)
            and arg.op.name == Tok.STAR_MUL {
            problem = "`*` unpacking into a class-value constructor is not lowered natively; pass the arguments explicitly";
            break;
        } else {
            if next_positional >= len(positional) {
                problem = f"too many positional arguments for the '{self._arch_display(
                    bound
                )}' constructor";
                break;
            }
            index = positional[next_positional];
            next_positional += 1;
            value = arg;
        }
        if value is None {
            continue;
        }
        if index in taken {
            problem = f"constructor parameter '{params[index].name}' is given twice";
            break;
        }
        taken.add(index);
        bound_args.append((index, value));
    }
    if problem is None and spread is None {
        for (i, p) in enumerate(params) {
            if p.fallback is None and i not in taken {
                problem = f"missing required '{self._arch_display(
                    bound
                )}' constructor argument '{p.name}'";
                break;
            }
        }
    }
    if problem is not None {
        self.ctx.emit(
            E5092,
            node_override=nd,
            kind="class value construction",
            name=f"type[{self._arch_display(bound)}]",
            help_text=f"Construction through a class value binds its arguments against the '{self._arch_display(
                bound
            )}' constructor signature: {problem}."
        );
        return None;
    }
    return (bound_args, spread);
}

impl NaIRGenPass._codegen_class_value_call(
    nd: uni.FuncCall, target: uni.Expr, args: list[uni.Expr | uni.KWPair], bound: str
) -> (ir.Value | None) {
    params = self._class_ctor_params(bound);
    if params is None or len(params) > CLASS_CTOR_MAX_PARAMS {
        self.ctx.emit(
            E5092,
            node_override=nd,
            kind="class value construction",
            name=f"type[{self._arch_display(bound)}]",
            help_text=f"Construction through a class value needs a native constructor signature for '{self._arch_display(
                bound
            )}': its layout must be visible, its initializer must not take *args or **kwargs, and it must not be generic or derive from a Python-side base."
        );
        return None;
    }
    binding = self._bind_class_ctor_args(nd, args, params, bound);
    if binding is None {
        return None;
    }
    (bound_args, spread) = binding;
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    cls = self._codegen_expr(target);
    if cls is None or not isinstance(cls.type, ir.PointerType) {
        return None;
    }
    cls = self._coerce_type(cls, i8p);
    values: dict[int, ir.Value] = {};
    mask = 0;
    for (index, expr) in bound_args {
        value = self._codegen_expr(expr);
        if value is None {
            return None;
        }
        values[index] = self._coerce_type(value, params[index].type);
        mask |= 1 << index;
    }
    owned = list(values.values());
    mask_value: ir.Value = ir.Constant(i64, mask);
    mapping: (ir.Value | None) = None;
    if spread is not None {
        mapping = self._codegen_expr(spread);
        if mapping is None {
            return None;
        }
        spread_mask = self._bind_class_ctor_spread(
            nd, mapping, params, values, mask_value, bound
        );
        if spread_mask is None {
            return None;
        }
        mask_value = spread_mask;
        owned = list(values.values());
    }
    ctor_entry = self.builder.call(
        self._emit_class_ctor_lookup_fn(),
        [
            cls,
            self._emit_class_name_const(bound),
            ir.Constant(i64, self._static_str_hash(bound))
        ],
        name="class.ctor"
    );
    self._emit_runtime_raise(
        self.builder.icmp_unsigned(
            "==", ctor_entry, ir.Constant(i8p, None), name="class.ctor.none"
        ),
        "TypeError",
        f"class is not constructible with the {self._arch_display(
            bound
        )} constructor arguments",
        release_on_error=owned
    );
    fnty = self._class_ctor_fn_type(params);
    call_args: list[ir.Value] = [mask_value];
    for (i, p) in enumerate(params) {
        given = values.get(i);
        call_args.append(
            given if given is not None else self._default_arg_fallback(p.type)
        );
    }
    result = self.builder.call(
        self.builder.bitcast(ctor_entry, fnty.as_pointer(), name="class.ctor.fn"),
        call_args,
        name="class.new"
    );
    self._release_owned_args(owned, op="class_ctor_arg");
    self._release_owned_args([cls], op="class_value");
    if mapping is not None {
        self._release_owned_args([mapping], op="class_ctor_kwargs");
    }
    for (_, expr) in bound_args {
        self._nogc_consume_local(expr);
    }
    self._emit_pending_error_check();
    return self._mark_owned(
        self.builder.bitcast(
            result, self.struct_types[bound].as_pointer(), name="class.obj"
        )
    );
}

impl NaIRGenPass._bind_class_ctor_spread(
    nd: uni.FuncCall,
    mapping: ir.Value,
    params: list[NativeCtorParam],
    values: dict[int, ir.Value],
    mask: ir.Value,
    bound: str
) -> (ir.Value | None) {
    helpers = self._str_dict_helpers_of(mapping);
    if helpers is None {
        self.ctx.emit(
            E5092,
            node_override=nd,
            kind="class value construction",
            name="**",
            help_text=f"A `**` mapping unpacked into a type[{self._arch_display(
                bound
            )}] constructor must lower to a native str-keyed dict."
        );
        return None;
    }
    i64 = ir.IntType(64);
    records: list[tuple[int, dict[str, any]]] = [];
    for (i, p) in enumerate(params) {
        rec = self._prep_kwbind_record(
            p.name,
            p.type,
            i,
            values[i] if i in values else self._default_arg_fallback(p.type),
            "kw" if i in values else None,
            None
        );
        rec["dup_msg"] = f"{self._arch_display(bound)}() {rec['dup_msg']}";
        records.append((i, rec));
    }
    matched = self._bind_kw_spread(mapping, helpers, [r for (_, r) in records], "");
    for (i, rec) in records {
        if rec["alloca"] is None {
            continue;
        }
        value = self.builder.load(rec["alloca"], name=f"kwargs.{rec['name']}.value");
        if self._elem_kind(value.type) != "raw" {
            self._mark_owned(value);
        }
        values[i] = value;
        mask = self.builder.or_(
            mask,
            self.builder.select(
                self.builder.load(rec["flag"], name="kwargs.given"),
                ir.Constant(i64, 1 << i),
                ir.Constant(i64, 0)
            ),
            name="kwargs.mask"
        );
    }
    self._emit_runtime_raise(
        self.builder.icmp_signed(
            "!=",
            self.builder.call(helpers["len"], [mapping], name="kwargs.len"),
            matched,
            name="kwargs.extra"
        ),
        "TypeError",
        f"{self._arch_display(bound)}() got an unexpected keyword argument"
    );
    return mask;
}

impl NaIRGenPass._class_ctor_registry -> ir.GlobalVariable {
    existing = self.llvm_module.globals.get(CLASS_CTOR_REGISTRY);
    if isinstance(existing, ir.GlobalVariable) {
        return existing;
    }
    table = ir.ArrayType(ir.IntType(8).as_pointer(), CLASS_CTOR_BUCKETS);
    registry = ir.GlobalVariable(self.llvm_module, table, name=CLASS_CTOR_REGISTRY);
    registry.linkage = "weak";
    registry.initializer = ir.Constant(table, None);
    return registry;
}

impl NaIRGenPass._class_record_type -> ir.LiteralStructType {
    i64 = ir.IntType(64);
    i8p = ir.IntType(8).as_pointer();
    return ir.LiteralStructType([i8p, i64, i8p, i64, i8p, i64]);
}

impl NaIRGenPass._class_ctor_entry_type -> ir.LiteralStructType {
    i8p = ir.IntType(8).as_pointer();
    return ir.LiteralStructType([ir.IntType(64), i8p, i8p]);
}

impl NaIRGenPass._emit_class_record_lookup_fn -> ir.Function {
    if self._class_record_lookup_fn is not None {
        return self._class_record_lookup_fn;
    }
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i8p = ir.IntType(8).as_pointer();
    record_ty = self._class_record_type();
    zero = ir.Constant(i32, 0);
    registry = self._class_ctor_registry();
    strcmp = self._get_or_declare_extern("strcmp", i32, [i8p, i8p]);
    fn = self._define_function("__jac_class_record", ir.FunctionType(i8p, [i8p]));
    fn.linkage = "private";
    fn.args[0].name = "cls";
    cls = fn.args[0];
    head = fn.append_basic_block("entry");
    hashed = fn.append_basic_block("hash");
    walk = fn.append_basic_block("walk");
    record_hash = fn.append_basic_block("record.hash");
    record_name = fn.append_basic_block("record.name");
    advance = fn.append_basic_block("advance");
    found = fn.append_basic_block("found");
    miss = fn.append_basic_block("miss");

    b = ir.IRBuilder(head);
    b.cbranch(
        b.icmp_unsigned("==", cls, ir.Constant(i8p, None), name="cls.null"),
        miss,
        hashed
    );

    b = ir.IRBuilder(hashed);
    hc = b.call(self._emit_cstr_hash_fn(), [cls], name="cls.hash");
    bucket = b.gep(
        registry,
        [
            ir.Constant(i64, 0),
            b.and_(hc, ir.Constant(i64, CLASS_CTOR_BUCKETS - 1), name="bucket.i")
        ],
        name="bucket"
    );
    first = b.load(bucket, name="record.first");
    b.branch(walk);

    b = ir.IRBuilder(walk);
    cursor = b.phi(i8p, name="record.cur");
    b.cbranch(
        b.icmp_unsigned("==", cursor, ir.Constant(i8p, None), name="record.end"),
        miss,
        record_hash
    );

    b = ir.IRBuilder(record_hash);
    record = b.bitcast(cursor, record_ty.as_pointer(), name="record");
    b.cbranch(
        b.icmp_unsigned(
            "==",
            b.load(b.gep(record, [zero, ir.Constant(i32, 1)]), name="record.h"),
            hc,
            name="record.hit"
        ),
        record_name,
        advance
    );

    b = ir.IRBuilder(record_name);
    self._emit_isa_name_match(
        b,
        None,
        b.load(b.gep(record, [zero, ir.Constant(i32, 2)]), name="record.name"),
        cls,
        strcmp,
        found,
        advance
    );

    b = ir.IRBuilder(advance);
    after = b.load(b.gep(record, [zero, zero]), name="record.next");
    b.branch(walk);
    cursor.add_incoming(first, hashed);
    cursor.add_incoming(after, advance);

    ir.IRBuilder(found).ret(cursor);
    ir.IRBuilder(miss).ret(ir.Constant(i8p, None));
    self._class_record_lookup_fn = fn;
    return fn;
}

impl NaIRGenPass._emit_class_ctor_lookup_fn -> ir.Function {
    if self._class_ctor_lookup_fn is not None {
        return self._class_ctor_lookup_fn;
    }
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i8p = ir.IntType(8).as_pointer();
    entry_ty = self._class_ctor_entry_type();
    record_ty = self._class_record_type();
    zero = ir.Constant(i32, 0);
    strcmp = self._get_or_declare_extern("strcmp", i32, [i8p, i8p]);
    find_record = self._emit_class_record_lookup_fn();
    fn = self._define_function(
        "__jac_class_ctor", ir.FunctionType(i8p, [i8p, i8p, i64])
    );
    fn.linkage = "private";
    fn.args[0].name = "cls";
    fn.args[1].name = "bound";
    fn.args[2].name = "bh";
    head = fn.append_basic_block("entry");
    found = fn.append_basic_block("found");
    scan = fn.append_basic_block("scan");
    entry_hash = fn.append_basic_block("entry.hash");
    entry_name = fn.append_basic_block("entry.name");
    hit = fn.append_basic_block("hit");
    next_entry = fn.append_basic_block("entry.next");
    miss = fn.append_basic_block("miss");

    b = ir.IRBuilder(head);
    raw = b.call(find_record, [fn.args[0]], name="record.raw");
    b.cbranch(
        b.icmp_unsigned("==", raw, ir.Constant(i8p, None), name="record.none"),
        miss,
        found
    );

    b = ir.IRBuilder(found);
    record = b.bitcast(raw, record_ty.as_pointer(), name="record");
    count = b.load(b.gep(record, [zero, ir.Constant(i32, 3)]), name="entries.n");
    entries = b.bitcast(
        b.load(b.gep(record, [zero, ir.Constant(i32, 4)]), name="entries.raw"),
        entry_ty.as_pointer(),
        name="entries"
    );
    b.branch(scan);

    b = ir.IRBuilder(scan);
    index = b.phi(i64, name="entry.i");
    slot = b.gep(entries, [index], name="entry");
    b.cbranch(b.icmp_unsigned("<", index, count, name="entry.more"), entry_hash, miss);

    b = ir.IRBuilder(entry_hash);
    b.cbranch(
        b.icmp_unsigned(
            "==", b.load(b.gep(slot, [zero, zero]), name="entry.h"), fn.args[2]
        ),
        entry_name,
        next_entry
    );

    b = ir.IRBuilder(entry_name);
    self._emit_isa_name_match(
        b,
        None,
        b.load(b.gep(slot, [zero, ir.Constant(i32, 1)]), name="entry.bound"),
        fn.args[1],
        strcmp,
        hit,
        next_entry
    );

    b = ir.IRBuilder(hit);
    b.ret(b.load(b.gep(slot, [zero, ir.Constant(i32, 2)]), name="entry.fn"));

    b = ir.IRBuilder(next_entry);
    following = b.add(index, ir.Constant(i64, 1), name="entry.in");
    b.branch(scan);
    index.add_incoming(ir.Constant(i64, 0), found);
    index.add_incoming(following, next_entry);

    ir.IRBuilder(miss).ret(ir.Constant(i8p, None));
    self._class_ctor_lookup_fn = fn;
    return fn;
}

impl NaIRGenPass._codegen_class_osp_tag(instance: ir.Value) -> (ir.Value | None) {
    cls = self._codegen_runtime_class_name(instance);
    if cls is None {
        return None;
    }
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i8p = ir.IntType(8).as_pointer();
    raw = self.builder.call(
        self._emit_class_record_lookup_fn(), [cls], name="class.record"
    );
    known = self.builder.icmp_unsigned(
        "!=", raw, ir.Constant(i8p, None), name="class.record.known"
    );
    record = self.builder.bitcast(
        self.builder.select(
            known, raw, self.builder.bitcast(self._class_tagless_record(), i8p)
        ),
        self._class_record_type().as_pointer(),
        name="class.record.p"
    );
    tag = self.builder.load(
        self.builder.gep(record, [ir.Constant(i32, 0), ir.Constant(i32, 5)]),
        name="class.osp_tag"
    );
    self._emit_runtime_raise(
        self.builder.icmp_unsigned(
            "==", tag, ir.Constant(i64, 0), name="class.untagged"
        ),
        "TypeError",
        "spawn requires a walker whose class is registered natively"
    );
    return tag;
}

impl NaIRGenPass._class_tagless_record -> ir.GlobalVariable {
    existing = self.llvm_module.globals.get("__jac_class_tagless");
    if isinstance(existing, ir.GlobalVariable) {
        return existing;
    }
    record_ty = self._class_record_type();
    record = ir.GlobalVariable(self.llvm_module, record_ty, name="__jac_class_tagless");
    record.linkage = "private";
    record.global_constant = True;
    record.initializer = ir.Constant(record_ty, None);
    return record;
}

impl NaIRGenPass._emit_class_ctor(
    arch: uni.Archetype, params: list[NativeCtorParam]
) -> (ir.Function | None) {
    name = self._arch_key(arch);
    i64 = ir.IntType(64);
    i8p = ir.IntType(8).as_pointer();
    fn = self._define_function(f"{name}.__ctor", self._class_ctor_fn_type(params));
    fn.linkage = "internal";
    mark = len(self.ctx.errors_had);
    warning_mark = len(self.ctx.warnings_had);
    built = False;
    state = self._enter_function(fn);
    try {
        mask = fn.args[0];
        required = [
            i
            for (i, p) in enumerate(params)
            if p.fallback is None
        ];
        if required {
            required_mask = ir.Constant(i64, sum([1 << i for i in required]));
            missing = ", ".join([f"'{params[i].name}'" for i in required]);
            self._emit_runtime_raise(
                self.builder.icmp_unsigned(
                    "!=",
                    self.builder.and_(mask, required_mask),
                    required_mask,
                    name="ctor.missing"
                ),
                "TypeError",
                f"{name}() missing required arguments among: {missing}"
            );
        }
        values: dict[str, ir.Value] = {};
        for (i, p) in enumerate(params) {
            arg = fn.args[i + 1];
            if p.fallback is None {
                values[p.name] = arg;
                continue;
            }
            given = self.builder.icmp_unsigned(
                "!=",
                self.builder.and_(mask, ir.Constant(i64, 1 << i)),
                ir.Constant(i64, 0),
                name=f"given.{p.name}"
            );
            slot = self._entry_alloca(p.type, f"ctor.{p.name}");
            use_given = self.builder.append_basic_block(f"ctor.{p.name}.given");
            use_default = self.builder.append_basic_block(f"ctor.{p.name}.fallback");
            chosen = self.builder.append_basic_block(f"ctor.{p.name}.done");
            self.builder.cbranch(given, use_given, use_default);
            self.builder.position_at_end(use_given);
            self._emit_take_ref(arg, op="ctor_arg");
            self.builder.store(arg, slot);
            self.builder.branch(chosen);
            self.builder.position_at_end(use_default);
            fallback = self._codegen_expr(p.fallback);
            if fallback is None {
                raise ValueError(f"default for '{p.name}' did not lower");
            }
            fallback = self._coerce_type(fallback, p.type);
            self._emit_take_ref(fallback, op="ctor_default");
            self.builder.store(fallback, slot);
            self.builder.branch(chosen);
            self.builder.position_at_end(chosen);
            values[p.name] = self._mark_owned(
                self.builder.load(slot, name=f"ctor.{p.name}")
            );
        }
        instance = self._codegen_instantiation(
            arch.name, type_name_override=name, ctor_values=values
        );
        if instance is not None and not self.builder.block.is_terminated {
            self.builder.ret(self.builder.bitcast(instance, i8p, name="ctor.obj"));
            built = True;
        }
    } except Exception {
        built = False;
    } finally {
        self._leave_function(state);
    }
    if built and len(self.ctx.errors_had) == mark {
        return fn;
    }
    del self.ctx.errors_had[mark:];
    del self.ctx.warnings_had[warning_mark:];
    self.llvm_module.globals.pop(fn.name, None);
    return None;
}

impl NaIRGenPass._emit_class_ctor_bridge(
    name: str, bound: str, signature: list[NativeCtorParam], fn: ir.Function
) -> (ir.Function | None) {
    params = self._class_ctor_params(bound);
    if params is None or len(params) > CLASS_CTOR_MAX_PARAMS {
        return None;
    }
    if [(p.name, p.type) for p in params] == [(p.name, p.type) for p in signature] {
        return fn;
    }
    positions: dict[str, int] = {};
    for (j, p) in enumerate(signature) {
        positions[p.name] = j;
    }
    routes: list[tuple[int, int]] = [];
    for (i, p) in enumerate(params) {
        j = positions.get(p.name, -1);
        if j < 0 {
            if p.fallback is None {
                return None;
            }
        } elif signature[j].type != p.type
            and not (
                isinstance(signature[j].type, ir.PointerType)
                and isinstance(p.type, ir.PointerType)
            ) {
            return None;
        }
        routes.append((i, j));
    }
    reached = [j for (_, j) in routes];
    for (j, p) in enumerate(signature) {
        if p.fallback is None and j not in reached {
            return None;
        }
    }
    i64 = ir.IntType(64);
    bridge = self._define_function(
        f"{name}.__ctor.{self._arch_display(bound)}", self._class_ctor_fn_type(params)
    );
    bridge.linkage = "internal";
    state = self._enter_function(bridge);
    try {
        mask: ir.Value = ir.Constant(i64, 0);
        forwarded: list[ir.Value] = [
            self._default_arg_fallback(p.type) for p in signature
        ];
        for (i, j) in routes {
            given = self.builder.icmp_unsigned(
                "!=",
                self.builder.and_(bridge.args[0], ir.Constant(i64, 1 << i)),
                ir.Constant(i64, 0),
                name=f"given.{params[i].name}"
            );
            if j < 0 {
                self._emit_runtime_raise(
                    given,
                    "TypeError",
                    f"{name}() got an unexpected keyword argument '{params[i].name}'"
                );
                continue;
            }
            mask = self.builder.or_(
                mask,
                self.builder.select(
                    given, ir.Constant(i64, 1 << j), ir.Constant(i64, 0)
                ),
                name=f"mask.{signature[j].name}"
            );
            forwarded[j] = self._coerce_type(bridge.args[i + 1], signature[j].type);
        }
        self.builder.ret(
            self.builder.call(fn, [mask] + forwarded, name=f"ctor.{name}")
        );
    } finally {
        self._leave_function(state);
    }
    return bridge;
}

impl NaIRGenPass._emit_class_ctor_entries(archetypes: list[uni.Archetype]) -> None {
    i64 = ir.IntType(64);
    i8p = ir.IntType(8).as_pointer();
    entry_ty = self._class_ctor_entry_type();
    record_ty = self._class_record_type();
    for arch in archetypes {
        if arch.name is None {
            continue;
        }
        name = self._arch_key(arch);
        if name not in self.struct_types or self._is_enum_arch(name) {
            continue;
        }
        entries: list[ir.Constant] = [];
        signature = self._class_ctor_params(name);
        fn = self._emit_class_ctor(arch, signature)
            if signature is not None and len(signature) <= CLASS_CTOR_MAX_PARAMS
            else None;
        if signature is not None and fn is not None {
            for bound in self._class_ancestors(name) {
                target = fn
                    if bound == name
                    else self._emit_class_ctor_bridge(name, bound, signature, fn);
                if target is None {
                    continue;
                }
                entries.append(
                    ir.Constant(
                        entry_ty,
                        [
                            ir.Constant(i64, self._static_str_hash(bound)),
                            self._emit_class_name_const(bound),
                            target.bitcast(i8p)
                        ]
                    )
                );
            }
        }
        tag = stable_osp_tag(name) if name in self.osp_type_tag_field else 0;
        if not entries and tag == 0 {
            continue;
        }
        table: ir.Value = ir.Constant(i8p, None);
        if entries {
            table_ty = ir.ArrayType(entry_ty, len(entries));
            table_gv = ir.GlobalVariable(
                self.llvm_module, table_ty, name=f"{name}.__ctors"
            );
            table_gv.linkage = "private";
            table_gv.global_constant = True;
            table_gv.initializer = ir.Constant(table_ty, entries);
            table = table_gv.bitcast(i8p);
        }
        record = ir.GlobalVariable(
            self.llvm_module, record_ty, name=f"{name}.__classrec"
        );
        record.linkage = "internal";
        record.initializer = ir.Constant(
            record_ty,
            [
                ir.Constant(i8p, None),
                ir.Constant(i64, self._static_str_hash(name)),
                self._emit_class_name_const(name),
                ir.Constant(i64, len(entries)),
                table,
                ir.Constant(i64, tag)
            ]
        );
        self._class_ctor_records.append((record, self._static_str_hash(name)));
    }
}

impl NaIRGenPass._emit_class_ctor_registrations -> None {
    if not self._class_ctor_records {
        return;
    }
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i8p = ir.IntType(8).as_pointer();
    registry = self._class_ctor_registry();
    for (record, hashed) in self._class_ctor_records {
        bucket = self.builder.gep(
            registry,
            [ir.Constant(i64, 0), ir.Constant(i64, hashed & (CLASS_CTOR_BUCKETS - 1))],
            name="class.bucket"
        );
        self.builder.store(
            self.builder.load(bucket, name="class.bucket.head"),
            self.builder.gep(record, [ir.Constant(i32, 0), ir.Constant(i32, 0)])
        );
        self.builder.store(record.bitcast(i8p), bucket);
    }
}
