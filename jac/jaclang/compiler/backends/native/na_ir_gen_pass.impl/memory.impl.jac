impl NaIRGenPass._storage_call(nd: uni.FuncCall) -> bool {
    target = nd.target;
    if isinstance(target.type, ClassType) and target.type.is_builtin(["array", "overlay", "packed", "aligned"])
        and target.type.is_instantiable_class() {
        return True;
    }
    if isinstance(target, uni.AtomTrailer) and target.is_attr {
        owner = target.target.type;
        return isinstance(owner, ClassType) and owner.is_builtin(["ptr", "array", "aligned"]);
    }
    if isinstance(target, uni.Name) and target.value in ["addr_of", "size_of", "align_of", "offset_of"] {
        symbol = target.sym;
        return symbol is not None and symbol.decl is not None
            and symbol.decl.loc.mod_path.replace("\\", "/").endswith("/na_builtins.pyi");
    }
    return False;
}

impl NaIRGenPass._codegen_storage_call(nd: uni.FuncCall) -> ir.Value | None {
    if isinstance(nd.target, uni.Name) and nd.target.value in ["size_of", "align_of", "offset_of"] {
        return self._codegen_storage_measure(nd);
    }
    if isinstance(nd.target.type, ClassType) and nd.target.type.is_builtin("aligned")
        and nd.target.type.is_instantiable_class() {
        storage = self._lower_type(nd.type);
        self._resolve_composite_storage_types(required=True);
        if not isinstance(storage, ir.IdentifiedStructType) or storage.elements is None
            or len(nd.params or []) != 1 or not isinstance(nd.params[0], uni.Expr) { return None; }
        value = self._codegen_expr(nd.params[0]);
        if value is None { return None; }
        return self.builder.insert_value(ir.Constant(storage, None),
            self._coerce_type(value, storage.elements[0]), 0, name="aligned.init");
    }
    if isinstance(nd.target.type, ClassType) and nd.target.type.is_builtin(["overlay", "packed"])
        and nd.target.type.is_instantiable_class() {
        storage = self._lower_type(nd.type);
        self._resolve_composite_storage_types(required=True);
        if storage is None or nd.params {
            self.ctx.emit(E5092, node_override=nd, kind="composite storage constructor", name=nd.target.type.shared.class_name);
            return None;
        }
        return ir.Constant(storage, None);
    }
    if isinstance(nd.target.type, ClassType) and nd.target.type.is_builtin("array")
        and nd.target.type.is_instantiable_class() {
        return self._codegen_array_constructor(nd);
    }
    if isinstance(nd.target, uni.AtomTrailer) and nd.target.is_attr {
        owner = nd.target.target.type;
        if isinstance(owner, ClassType) and owner.is_builtin(["array", "aligned"]) {
            if self._get_name(nd.target.right) != "data" or nd.params {
                self.ctx.emit(E5092, node_override=nd, kind="inline storage method",
                    name=self._get_name(nd.target.right) or "<method>");
                return None;
            }
            address = self._codegen_inline_storage_address(nd.target.target);
            result_type = self._lower_type(nd.type);
            if address is None or not isinstance(result_type, RawPointerType) {
                return None;
            }
            zero = ir.Constant(ir.IntType(32), 0);
            first = self.builder.gep(address, [zero, zero], name="array.data");
            return self._coerce_type(first, result_type);
        }
    }
    arguments = list(nd.params or []);
    if any(isinstance(arg, uni.KWPair) for arg in arguments) {
        self.ctx.emit(E5092, node_override=nd, kind="raw pointer call",
            name="keyword arguments", help_text="Raw memory operations use positional arguments.");
        return None;
    }
    target = nd.target;
    if isinstance(target, uni.Name) {
        if len(arguments) != 1 or not isinstance(arguments[0], uni.Expr) {
            self.ctx.emit(E5092, node_override=nd, kind="raw pointer call", name="addr_of");
            return None;
        }
        result_type = self._lower_type(nd.type);
        if isinstance(result_type, RawPointerType) and isinstance(result_type.pointee, ir.FunctionType) {
            function = self._codegen_expr(arguments[0]);
            if not isinstance(function, ir.Function) or function.function_type != result_type.pointee {
                self.ctx.emit(E5092, node_override=nd, kind="C function address", name="addr_of",
                    help_text="Use a named native function with a matching C signature and no captured environment.");
                return None;
            }
            return self._coerce_type(function, result_type);
        }
        place = self._codegen_place_ptr(arguments[0], allow_inline=True);
        if place is None or not isinstance(result_type, RawPointerType) {
            self.ctx.emit(E5092, node_override=nd, kind="addressable storage",
                name="addr_of", help_text="Take the address of a local, global, stored field, or indexed raw pointer.");
            return None;
        }
        return self._coerce_type(place, result_type);
    }
    assert isinstance(target, uni.AtomTrailer);
    method = self._get_name(target.right);
    owner_type = target.target.type;
    pointer_type = self._lower_type(owner_type);
    if not isinstance(owner_type, ClassType) or not isinstance(pointer_type, RawPointerType) {
        self.ctx.emit(E5092, node_override=nd, kind="raw pointer type", name="ptr");
        return None;
    }
    if method is not None and method.startswith("atomic_") {
        return self._codegen_atomic_storage_call(nd, pointer_type);
    }
    if method == "call" {
        if not owner_type.is_class_instance() or not isinstance(pointer_type.pointee, ir.FunctionType) {
            self.ctx.emit(E5092, node_override=nd, kind="C function pointer", name="call");
            return None;
        }
        function_pointer = self._codegen_expr(target.target);
        if function_pointer is None { return None; }
        if len(arguments) != len(pointer_type.pointee.args) {
            self.ctx.emit(E5092, node_override=nd, kind="C function argument count", name="call");
            return None;
        }
        return self._codegen_callable_value(nd, function_pointer, []);
    }
    if isinstance(pointer_type.pointee, ir.FunctionType) and method not in ["null", "from_address", "address"] {
        self.ctx.emit(E5092, node_override=nd, kind="function pointer memory operation", name=method or "<method>");
        return None;
    }
    required = {"null": 0, "from_address": 1, "address": 0,
        "load": 0, "store": 1, "load_unaligned": 0, "store_unaligned": 1,
        "load_volatile": 0, "store_volatile": 1, "offset": 1};
    if method not in required or len(arguments) != required[method] {
        self.ctx.emit(E5092, node_override=nd, kind="raw pointer call", name=method or "<method>");
        return None;
    }
    if method in ("null", "from_address") and owner_type.is_class_instance() {
        if self._codegen_expr(target.target) is None {
            return None;
        }
    }
    if method == "null" {
        return ir.Constant(pointer_type, None);
    }
    if method == "from_address" {
        address = self._codegen_expr(arguments[0]);
        if address is None or not isinstance(address.type, ir.IntType) {
            self.ctx.emit(E5092, node_override=nd, kind="raw pointer address", name="from_address");
            return None;
        }
        return self.builder.inttoptr(self._storage_integer(address, arguments[0]), pointer_type, name="ptr.from_address");
    }
    pointer = self._codegen_expr(target.target);
    if pointer is None {
        return None;
    }
    if method == "address" {
        return self.builder.ptrtoint(pointer, ir.IntType(64), name="ptr.address");
    }
    if method in ["load", "load_unaligned", "load_volatile"] {
        return self.builder.load(pointer, name="ptr.load", align=1 if method == "load_unaligned" else None,
            volatile=method == "load_volatile");
    }
    value = self._codegen_expr(arguments[0]);
    if value is None {
        return None;
    }
    if method in ["store", "store_unaligned", "store_volatile"] {
        self.builder.store(self._coerce_type(value, pointer_type.pointee), pointer,
            align=1 if method == "store_unaligned" else None, volatile=method == "store_volatile");
        return None;
    }
    if not isinstance(value.type, ir.IntType) {
        self.ctx.emit(E5092, node_override=nd, kind="raw pointer offset", name="offset");
        return None;
    }
    advanced = self.builder.gep(pointer, [self._storage_integer(value, arguments[0])], name="ptr.offset");
    return self._coerce_type(advanced, pointer_type);
}

impl NaIRGenPass._storage_integer(value: ir.Value, source: uni.Expr) -> ir.Value {
    # Extend unsigned narrow indices with zeros before LLVM's signed GEP index
    # interpretation. Reuse the fixed-width conversion path for sign handling.
    original = self._scalar_shape(source);
    address = self._scalar_shape_named("i64");
    if original is not None and address is not None {
        return self._emit_wrap_to(value, original, address);
    }
    return self._coerce_type(value, ir.IntType(64));
}

impl NaIRGenPass._codegen_atomic_storage_call(nd: uni.FuncCall, pointer_type: RawPointerType) -> ir.Value | None {
    import from jaclang.compiler.frontend.const_fold { fold_const }
    import from jaclang.compiler.backends.native.abi { storage_layouts }
    assert isinstance(nd.target, uni.AtomTrailer);
    method = self._get_name(nd.target.right) or "";
    arguments = [arg for arg in nd.params if isinstance(arg, uni.Expr)];
    operations = {"atomic_exchange": "xchg", "atomic_fetch_add": "add", "atomic_fetch_sub": "sub",
        "atomic_fetch_and": "and", "atomic_fetch_or": "or", "atomic_fetch_xor": "xor", "atomic_fetch_nand": "nand"};
    count = 1 if method == "atomic_load" else (5 if method == "atomic_compare_exchange" else 2);
    if method not in operations and method not in ["atomic_load", "atomic_store", "atomic_compare_exchange"] {
        self.ctx.emit(E5092, node_override=nd, kind="atomic memory operation", name=method);
        return None;
    }
    if len(arguments) not in [count, count + 1] {
        self.ctx.emit(E5092, node_override=nd, kind="atomic argument count", name=method);
        return None;
    }
    storage = pointer_type.pointee;
    if not ((isinstance(storage, ir.IntType) and storage.width in [8, 16, 32, 64])
        or isinstance(storage, RawPointerType)) or (method.startswith("atomic_fetch_") and not isinstance(storage, ir.IntType)) {
        self.ctx.emit(E5092, node_override=nd, kind="atomic storage", name=method,
            help_text="Atomic memory operations require an 8-, 16-, 32-, or 64-bit integer or raw pointer; arithmetic requires integers.");
        return None;
    }
    volatile = False;
    if len(arguments) > count {
        (known, flag) = fold_const(arguments[count]);
        if not known or not isinstance(flag, bool) {
            self.ctx.emit(E5092, node_override=nd, kind="constant volatile flag", name=method);
            return None;
        }
        volatile = flag;
    }
    orders: list[str] = [];
    order_indices = [2, 3] if method == "atomic_compare_exchange" else [0 if method == "atomic_load" else 1];
    for index in order_indices {
        (known, requested) = fold_const(arguments[index]);
        names = {"relaxed": "monotonic", "consume": "acquire", "acquire": "acquire",
            "release": "release", "acq_rel": "acq_rel", "seq_cst": "seq_cst"};
        if not known or not isinstance(requested, str) or requested not in names {
            self.ctx.emit(E5092, node_override=nd, kind="constant atomic memory ordering", name=method);
            return None;
        }
        ordering = names[requested];
        if (method == "atomic_load" or (method == "atomic_compare_exchange" and index == 3))
            and ordering in ["release", "acq_rel"] or method == "atomic_store" and ordering in ["acquire", "acq_rel"] {
            self.ctx.emit(E5092, node_override=nd, kind="invalid atomic memory ordering", name=method);
            return None;
        }
        orders.append(ordering);
    }
    layout = storage_layouts(self.llvm_module, {"atomic": storage})["atomic"];
    pointer = self._codegen_expr(nd.target.target);
    if pointer is None { return None; }
    if method == "atomic_load" {
        return self.builder.load(pointer, name="atomic.load", align=layout.size, ordering=orders[0], volatile=volatile);
    }
    value = self._codegen_expr(arguments[0]);
    if value is None { return None; }
    if method == "atomic_compare_exchange" {
        desired = self._codegen_expr(arguments[1]);
        (known, weak) = fold_const(arguments[4]);
        if desired is None { return None; }
        if not isinstance(value.type, ir.PointerType) or value.type.pointee != storage or not known or not isinstance(weak, bool) {
            self.ctx.emit(E5092, node_override=nd, kind="compare-exchange expected pointer or constant weak flag", name=method);
            return None;
        }
        expected = self.builder.load(value, name="atomic.expected");
        result = self.builder.cmpxchg(pointer, expected, self._coerce_type(desired, storage), orders[0], orders[1],
            name="atomic.compare", weak=weak, volatile=volatile, align=layout.size);
        success = self.builder.extract_value(result, 1, name="atomic.success");
        failed = self.builder.function.append_basic_block("atomic.failed");
        done = self.builder.function.append_basic_block("atomic.done");
        self.builder.cbranch(success, done, failed);
        self.builder.position_at_end(failed);
        self.builder.store(self.builder.extract_value(result, 0, name="atomic.observed"), value);
        self.builder.branch(done);
        self.builder.position_at_end(done);
        return success;
    }
    value = self._coerce_type(value, storage);
    if method == "atomic_store" {
        self.builder.store(value, pointer, align=layout.size, ordering=orders[0], volatile=volatile);
        return None;
    }
    return self.builder.atomic_rmw(operations[method], pointer, value, orders[0], name="atomic.previous",
        volatile=volatile, align=layout.size);
}

impl NaIRGenPass._codegen_storage_measure(nd: uni.FuncCall) -> ir.Constant | None {
    import from jaclang.compiler.backends.native.abi { storage_layouts, is_sized_storage }
    arguments = list(nd.params or []);
    query = self._get_name(nd.target);
    count = 2 if query == "offset_of" else 1;
    if len(arguments) != count or not isinstance(arguments[0], uni.Expr) {
        self.ctx.emit(E5033, node_override=nd, name="storage query", details="storage measurement requires one native value type");
        return None;
    }
    typ = arguments[0].type;
    if not isinstance(typ, ClassType) or not typ.is_instantiable_class() or not typ.has_native_value_storage() {
        self.ctx.emit(E5033, node_override=nd, name="storage query", details="storage measurement requires a complete unmanaged value type");
        return None;
    }
    storage = self._lower_type(typ);
    self._resolve_composite_storage_types(required=True);
    if storage is None or not is_sized_storage(storage) {
        self.ctx.emit(E5033, node_override=nd, name="storage query", details="storage measurement requires a complete native layout");
        return None;
    }
    layout = storage_layouts(self.llvm_module, {"measured": storage})["measured"];
    size = layout.size if query == "size_of" else layout.alignment;
    if query == "offset_of" {
        import from jaclang.compiler.frontend.const_fold { fold_const }
        (known, field_value) = fold_const(arguments[1]);
        if not typ.is_value_struct() or not known or not isinstance(field_value, str) {
            self.ctx.emit(E5033, node_override=nd, name="offset_of", details="field offsets require a value struct type and a constant field name");
            return None;
        }
        fields = self.struct_field_indices.get(typ.shared.class_name, {});
        field = field_value;
        if field not in fields or fields[field] >= len(layout.field_offsets) {
            self.ctx.emit(E5033, node_override=nd, name="offset_of", details="unknown stored field " + field);
            return None;
        }
        size = layout.field_offsets[fields[field]];
    }
    return ir.Constant(ir.IntType(64), size);
}

impl NaIRGenPass._codegen_storage_index(expr: uni.Expr) -> ir.Value | None {
    if not isinstance(expr, uni.AtomTrailer) or expr.is_attr {
        return None;
    }
    owner_type = expr.target.type;
    if not isinstance(owner_type, ClassType) or not owner_type.is_builtin(["ptr", "array"]) {
        return None;
    }
    index = expr.right;
    if not isinstance(index, uni.IndexSlice) or index.is_range or len(index.slices or []) != 1 {
        self.ctx.emit(E5092, node_override=expr, kind="native storage index", name="subscript");
        return None;
    }
    is_array = owner_type.is_builtin("array");
    subscript = index.slices[0];
    pointer = self._codegen_inline_storage_address(expr.target) if is_array
        else self._codegen_expr(expr.target);
    offset = self._codegen_expr(subscript.start);
    if pointer is None or offset is None {
        return None;
    }
    if not isinstance(pointer.type, ir.PointerType) or not isinstance(offset.type, ir.IntType) {
        self.ctx.emit(E5092, node_override=expr, kind="native storage index", name="subscript");
        return None;
    }
    if isinstance(pointer.type.pointee, ir.FunctionType) {
        self.ctx.emit(E5092, node_override=expr, kind="function pointer indexing", name="subscript");
        return None;
    }
    assert subscript.start is not None;
    offset = self._storage_integer(offset, subscript.start);
    if is_array {
        length = owner_type.fixed_array_length();
        assert length is not None;
        outside = self.builder.icmp_unsigned(">=", offset,
            ir.Constant(ir.IntType(64), length), name="array.outside");
        self._emit_runtime_raise(outside, "IndexError", "fixed array index out of range");
        return self.builder.gep(pointer, [ir.Constant(ir.IntType(32), 0), offset],
            name="array.element");
    }
    return self.builder.gep(pointer, [offset], name="ptr.element");
}

impl NaIRGenPass._codegen_inline_storage_address(expr: uni.Expr) -> ir.Value | None {
    place = self._codegen_place_ptr(expr, allow_inline=True);
    if place is not None {
        return place;
    }
    value = self._codegen_expr(expr);
    if value is None {
        return None;
    }
    aligned_value = isinstance(expr.type, ClassType) and expr.type.is_builtin("aligned");
    if not isinstance(value.type, ir.ArrayType) and not aligned_value {
        self.ctx.emit(E5092, node_override=expr, kind="inline value storage", name="array or aligned");
        return None;
    }
    temporary = self._entry_alloca(value.type, "storage.temporary");
    self.builder.store(value, temporary);
    return temporary;
}

impl NaIRGenPass._codegen_array_constructor(nd: uni.FuncCall) -> ir.Value | None {
    storage = self._lower_type(nd.target.type);
    if not isinstance(storage, ir.ArrayType) {
        self.ctx.emit(E5092, node_override=nd, kind="fixed array type", name="array");
        return None;
    }
    arguments = list(nd.params or []);
    items: list[uni.Expr] = [];
    if arguments {
        initial = arguments[0];
        if len(arguments) != 1 or not isinstance(initial, (uni.ListVal, uni.TupleVal)) {
            self.ctx.emit(E5092, node_override=nd, kind="fixed array initializer", name="array",
                help_text="Use an element list or tuple for inline initialization.");
            return None;
        }
        items = list(initial.values or []);
    }
    if len(items) > storage.count {
        self.ctx.emit(E5092, node_override=nd, kind="fixed array initializer", name="array",
            help_text="The initializer contains more elements than the declared array length.");
        return None;
    }
    constant = self._codegen_const_expr(nd, storage);
    if constant is not None { return constant; }
    value: ir.Value = ir.Constant(storage, None);
    for (index, item) in enumerate(items) {
        element = self._codegen_expr(item);
        if element is None {
            return None;
        }
        value = self.builder.insert_value(value, self._coerce_type(element, storage.element),
            index, name="array.init");
    }
    return value;
}

impl NaIRGenPass._lower_composite_storage_type(t: ClassType) -> ir.Type | None {
    import hashlib;
    if len(t.private.type_args or []) != 2 { return None; }
    alternatives: list[ir.Type] = [];
    alignment = 0;
    if t.is_builtin("aligned") {
        bound = t.private.type_args[1];
        if not isinstance(bound, ClassType) { return None; }
        requested = bound.get_literal_value();
        if not isinstance(requested, int) or isinstance(requested, bool) or requested <= 0 { return None; }
        alignment = requested;
    }
    for alternative in (t.private.type_args[:1] if alignment else t.private.type_args) {
        if not isinstance(alternative, ClassType) or not alternative.has_native_value_storage() { return None; }
        storage = self._lower_type(alternative);
        if storage is None { return None; }
        alternatives.append(storage);
    }
    key = "|".join(str(storage) for storage in alternatives) + ":" + str(alignment);
    name = "__jac_" + t.shared.class_name + "_" + hashlib.sha256(key.encode()).hexdigest();
    if name not in self.composite_storage_types {
        result = self.llvm_module.context.get_identified_type(name);
        self.composite_storage_types[name] = CompositeStorage(result, alternatives, t.shared.class_name, alignment);
    }
    self._resolve_composite_storage_types();
    return self.composite_storage_types[name].storage;
}

impl NaIRGenPass._resolve_composite_storage_types(required: bool = False) -> None {
    import from jaclang.compiler.backends.native.abi { is_sized_storage, overlapping_storage, aligned_storage }
    while True {
        progressed = False;
        for definition in self.composite_storage_types.values() {
            storage = definition.storage; alternatives = definition.components;
            is_packed = definition.kind == "packed";
            if not storage.is_opaque or not all(is_sized_storage(typ) for typ in alternatives) { continue; }
            layout = ir.LiteralStructType(alternatives, packed=True) if is_packed
                else (aligned_storage(self.llvm_module, alternatives[0], definition.alignment) if definition.kind == "aligned"
                    else overlapping_storage(self.llvm_module, alternatives));
            storage.packed = is_packed;
            storage.set_body(*layout.elements);
            progressed = True;
        }
        if not progressed { break; }
    }
    if required {
        for (name, definition) in self.composite_storage_types.items() {
            if definition.storage.is_opaque {
                self.ctx.emit(E5033, name="composite storage", details="storage has an incomplete or recursive component: " + name);
            }
        }
    }
}
