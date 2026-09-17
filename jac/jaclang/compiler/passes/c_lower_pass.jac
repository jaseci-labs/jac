"""C semantic lowering to standard Jac UniTree; no Jac source concatenation."""
import os;
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.c.control_flow { CFlowGraph, CSwitchTargets }
import from jaclang.compiler.frontend.c.parser { CParseResult }
import from jaclang.compiler.frontend.c.declarators { declarator_name, derived_operators }
import from jaclang.compiler.frontend.c.semantics { CEmitConfig, CType, CScalar, CQualified, CAttributed, CFunctionType, CPointer, CArray, CRecord, CField,
    compatible, promote, common, unqualified, qualifiers_of, attributes_of, lowering_attributes, integer_literal, character_literal, string_bytes, is_floating_literal, floating_literal }
import from jaclang.compiler.frontend.c.jac_ast { CJacAst }
import from jaclang.compiler.frontend.c.declarations { CTypeResolver }
import from jaclang.compiler.frontend.c.tokens { CDiagnostic }
import from jaclang.compiler.frontend.c.constants { CInteger }
import from jaclang.compiler.frontend.unitree_c { CNode }
import from jaclang.compiler.frontend.srcloc { Span }
import from jaclang.compiler.frontend.diagnostics { E0090, W0090, E2290 }
import from jaclang.compiler.passes.context { Alert, PassResult, CompileContext }

obj CLowerResult(PassResult) {
    has module: uni.Module | None = None,
        origins: dict[int, Span] = {};
    has ok: bool { getter { return not self.errors_had; } }
}

def frontend_alert(diagnostic: CDiagnostic, owner: type) -> Alert {
    return Alert(msg=diagnostic.message, loc=Span.from_loc(diagnostic.token.as_unitree().loc),
        from_pass=owner, code=E0090 if diagnostic.severity == "error" else W0090);
}

obj CValue {
    has expr: uni.Expr,
        typ: CType,
        constant: bool = False,
        integer_value: int | None = None,
        address_constant: bool = False,
        null_pointer_constant: bool = False,
        # Keep an unaligned lvalue address separate from its load expression.
        unaligned_address: uni.Expr | None = None,
        bitfield_address: uni.Expr | None = None,
        bit_shift: int = 0,
        bit_width: int = 0;
}

obj CBinding {
    has name: str,
        typ: CType,
        static_storage: bool = False,
        alignment: int = 0;
}

obj CGlobal(CBinding) {
    has declarations: list[CNode] = [],
        definitions: list[CNode] = [],
        initializer: CNode | None = None,
        internal: bool = False,
        tentative: bool = False,
        thread_local: bool = False,
        referenced: bool = False,
        context_external: bool = False;

    has defined: bool { getter { return not self.context_external and (self.tentative or self.initializer is not None); } }
}

obj CFunction {
    has name: str,
        signature: CFunctionType,
        declarations: list[CType] = [],
        definition: CNode | None = None,
        referenced: bool = False,
        internal: bool = False,
        requires_retention: bool = False,
        inline_only: bool = False,
        address_referenced: bool = False,
        external_name: str = "",
        context_external: bool = False;

    has address_name: str { getter { return (self.external_name or self.name) if self.inline_only else self.emitted_name; } }
    has emitted_name: str { getter { return "c_" + self.name if self.definition is not None and not self.context_external else (self.external_name or self.name); } }
}

obj CAssignmentHelper {
    has name: str,
        target_type: CType,
        value_type: CType,
        operation: str,
        postfix: bool,
        unaligned: bool = False,
        atomic: bool = False,
        volatile: bool = False,
        bit_shift: int = 0,
        bit_width: int = 0;
}

obj CUnionInitializerHelper {
    has name: str,
        record: CRecord,
        field: CField;
}

obj CLowerPass {
    has config: CEmitConfig,
        ast: CJacAst,
        ctx: CompileContext,
        result: CLowerResult = CLowerResult(),
        types: CTypeResolver postinit,
        emitted_aliases: set[str] = set(),
        globals: dict[str, CGlobal] = {},
        emitted_globals: set[str] = set(),
        functions: dict[str, CFunction] = {},
        scopes: list[dict[str, CBinding]] = [],
        control_graph: CFlowGraph | None = None,
        serial: int = 0,
        input_path: str = "",
        selected_paths: set[str] = set(),
        current_function: str = "",
        function_strings: dict[str, CBinding] = {},
        current: CNode | None = None,
        return_type: CType = CScalar(category="void"),
        # Each loop supplies the statements a continue must execute first.
        continue_actions: list[list[uni.CodeBlockStmt]] = [],
        helpers: dict[str, CScalar] = {},
        assignment_helpers: list[CAssignmentHelper] = [],
        union_initializer_helpers: list[CUnionInitializerHelper] = [],
        storage_nodes: list[uni.ElementStmt] = [];

    def postinit {
        self.ast.config = self.config;
        self.types = CTypeResolver(config=self.config, expression_type=self.expression_type);
    }

    def source_owned(nd: uni.UniNode) -> bool {
        return os.path.realpath(nd.loc.mod_path) in self.selected_paths if self.selected_paths
            else nd.loc.mod_path == self.input_path;
    }

    def expression_type(nd: CNode) -> CType {
        # typeof preserves array types and never emits evaluation of its operand.
        return self.expression(nd, decay=False).typ;
    }

    def fail(nd: CNode, message: str) {
        self.current = nd;
        raise ValueError(message);
    }

    def report_error(nd: CNode, message: str) {
        self.ctx.emit(E2290, node_override=nd, details=message);
    }

    def declared_type(spec: CNode, decl: CNode | None = None) -> CType {
        self.current = spec;
        try {
            return self.types.resolve(spec, decl) if decl is not None else self.types.specifiers(spec, standalone=True);
        } except ValueError {
            self.current = self.types.current or spec;
            raise;
        }
    }

    def scalar_type(typ: CType, nd: CNode, integer_only: bool = False) -> CScalar {
        if lowering_attributes(attributes_of(typ)) {
            self.fail(nd, "C type attributes require ABI-aware source lowering");
        }
        scalar = unqualified(typ);
        if not isinstance(scalar, CScalar) {
            self.fail(nd, "Declared C storage type requires further expression lowering");
            return CScalar();
        }
        if scalar.category not in ["integer", "bool", "floating"] {
            self.fail(nd, "Expression requires a supported C arithmetic type");
        }
        if scalar.category == "floating" and (integer_only or scalar.width not in [32, 64]) {
            self.fail(nd, "Operation requires an integer or a supported floating representation");
        }
        return scalar;
    }

    def storage(spec: CNode) -> list[str] {
        return [p.value for p in spec.operands if p.kind == "storage"];
    }

    def name_of(decl: CNode) -> str {
        return declarator_name(decl);
    }

    def operators(decl: CNode) -> list[CNode] {
        return derived_operators(decl);
    }

    def is_void(typ: CType) -> bool {
        base = unqualified(typ);
        return isinstance(base, CScalar) and base.category == "void";
    }

    def variable(spec: CNode, decl: CNode) -> CType {
        typ = self.declared_type(spec, decl);
        if self.is_void(typ) { self.fail(decl, "Object cannot have void type"); }
        return typ;
    }

    def object_storage(typ: CType) -> tuple[CType, int] {
        if isinstance(typ, CQualified) {
            (base, alignment) = self.object_storage(typ.base);
            return (CQualified(base, typ.qualifiers), alignment);
        }
        if not isinstance(typ, CAttributed) { return (typ, 0); }
        (base, alignment) = self.object_storage(typ.base);
        remaining: list[CNode] = [];
        for attribute in typ.attributes {
            if attribute.kind != "attribute" { remaining.append(attribute); continue; }
            names: list[CNode] = [];
            for part in attribute.operands {
                if part.kind != "attribute_name" or part.value != "aligned" { names.append(part); continue; }
                if len(part.operands) != 1 { self.fail(part, "Object alignment requires an explicit constant byte count"); }
                requested = self.types.constant_bound(part.operands[0]);
                if requested is None or requested <= 0 or (requested & (requested - 1)) != 0 {
                    self.fail(part, "Object alignment must be a positive power of two");
                    continue;
                }
                alignment = max(alignment, requested);
            }
            if names {
                anchor = attribute.kid[0]; assert isinstance(anchor, uni.Token);
                remaining.append(CNode("attribute", anchor, names, attribute.value));
            }
        }
        return (CAttributed(base, remaining) if remaining else base, alignment);
    }

    def binding_type(binding: CBinding) -> uni.Expr {
        typ = self.ast.type_node(binding.typ);
        return self.ast.generic_type("aligned", [typ, self.ast.integer(binding.alignment)]) if binding.alignment else typ;
    }

    def binding_place(binding: CBinding) -> uni.Expr {
        value: uni.Expr = self.ast.name(binding.name);
        if binding.alignment {
            value = self.ast.index(self.ast.invoke(self.ast.member(value, "data"), []), self.ast.integer(0));
        }
        return value;
    }

    def binding_initial(binding: CBinding, value: uni.Expr) -> uni.Expr {
        return self.ast.invoke(self.binding_type(binding), [value]) if binding.alignment else value;
    }

    def signature(spec: CNode, decl: CNode) -> CFunction {
        declared = self.declared_type(spec, decl);
        function = unqualified(declared);
        if not isinstance(function, CFunctionType) {
            self.fail(decl, "Declarator does not declare a function");
            return CFunction("", CFunctionType(CScalar()));
        }
        return CFunction(self.name_of(decl), function, [declared]);
    }

    def remember_function(spec: CNode, decl: CNode, definition: CNode | None = None) {
        if "_Thread_local" in self.storage(spec) { self.fail(decl, "Function cannot have thread-local storage"); }
        fn = self.signature(spec, decl);
        for attribute in attributes_of(fn.declarations[0]) {
            if attribute.kind != "asm_label" { continue; }
            if len(attribute.operands) != 1 { self.fail(attribute, "Malformed assembler symbol label"); }
            symbol = string_bytes(attribute.operands[0]).decode("ascii");
            if not symbol or not (symbol[0].isalpha() or symbol[0] == "_")
                or not all(char.isalnum() or char == "_" for char in symbol) {
                self.fail(attribute, "Assembler symbol requires a Jac-representable identifier");
            }
            if fn.external_name and fn.external_name != symbol { self.fail(attribute, "Conflicting assembler symbol labels"); }
            fn.external_name = symbol;
        }
        storage = self.storage(spec);
        fn.internal = "static" in storage;
        attribute_names: set[str] = set();
        # Constructors and explicitly retained symbols remain roots even without
        # C references. Their unsupported attributes must still be diagnosed.
        for part in spec.operands + self.operators(decl) {
            if part.kind == "attribute" {
                names = {name.value for name in part.operands if name.kind == "attribute_name"};
                attribute_names.update(names);
                if lowering_attributes([part], handled={"gnu_inline"}) {
                    fn.requires_retention = True;
                }
            } elif part.kind == "asm_label" { fn.requires_retention = True; }
        }
        fn.inline_only = definition is not None and "extern" in storage and "inline" in storage
            and "gnu_inline" in attribute_names;
        self.types.declare_ordinary(fn.name, decl);
        if fn.name in self.globals or fn.name in self.types.aliases { self.fail(decl, "Conflicting ordinary identifier " + fn.name); }
        previous = self.functions.get(fn.name);
        if previous is not None {
            if fn.external_name {
                if previous.external_name and previous.external_name != fn.external_name {
                    self.fail(decl, "Conflicting assembler symbol labels for " + fn.name);
                }
                previous.external_name = fn.external_name;
            }
            if fn.internal and not previous.internal { self.fail(decl, "Function changes from external to internal linkage: " + fn.name); }
            if not compatible(previous.signature, fn.signature) {
                self.fail(decl, "Conflicting function declarations for " + fn.name);
            }
            previous.declarations.extend(fn.declarations);
            previous.requires_retention = previous.requires_retention or fn.requires_retention;
            if previous.definition is not None and definition is not None { self.fail(decl, "Duplicate function definition " + fn.name); }
            if definition is not None { previous.definition = definition; previous.inline_only = fn.inline_only; }
        } else { fn.definition = definition; self.functions[fn.name] = fn; }
    }

    def collect(nd: CNode) {
        if nd.kind == "preprocessing_unit" { return; }
        if nd.kind not in ["declaration", "function_definition"] { self.fail(nd, "Top-level " + nd.kind + " is not supported yet"); }
        children = nd.operands; spec = children[0]; storage = self.storage(spec);
        if any(s not in ["typedef", "static", "extern", "inline", "_Thread_local"] for s in storage) { self.fail(spec, "Unsupported storage or function specifier"); }
        if nd.kind == "function_definition" { self.remember_function(spec, children[1], nd); return; }
        if len(children) == 1 { self.declared_type(spec); }
        for item in children[1:] {
            decl = item.operands[0]; name = self.name_of(decl); ops = self.operators(decl);
            if "typedef" in storage {
                if "_Thread_local" in storage { self.fail(item, "Typedef cannot have thread-local storage"); }
                if len(item.operands) > 1 { self.fail(item, "Typedef cannot have an initializer"); }
                typ = self.declared_type(spec, decl);
                if name in self.functions or name in self.globals { self.fail(decl, "Conflicting typedef " + name); }
                self.types.declare_alias(name, typ, decl);
            } elif ops and ops[0].kind == "function" {
                if len(item.operands) > 1 { self.fail(item, "Function declaration cannot have an initializer"); }
                self.remember_function(spec, decl);
            }
            else {
                self.remember_global(spec, item);
            }
        }
    }

    def remember_global(spec: CNode, item: CNode) {
        decl = item.operands[0]; name = self.name_of(decl);
        if name in self.functions or name in self.types.aliases { self.fail(item, "Conflicting ordinary identifier " + name); }
        typ = self.variable(spec, decl); storage = self.storage(spec);
        self.types.declare_ordinary(name, decl);
        initializer = item.operands[1] if len(item.operands) > 1 else None;
        typ = self.types.complete_array(typ, initializer);
        (typ, alignment) = self.object_storage(typ);
        internal = "static" in storage;
        previous = self.globals.get(name);
        if previous is None {
            previous = CGlobal(name, typ, static_storage=True, internal=internal, thread_local="_Thread_local" in storage);
            self.globals[name] = previous;
        } else {
            if previous.thread_local != ("_Thread_local" in storage) { self.fail(item, "Conflicting thread-local storage for " + name); }
            if not compatible(previous.typ, typ) { self.fail(item, "Conflicting object declarations for " + name); }
            prior_array = unqualified(previous.typ); next_array = unqualified(typ);
            if isinstance(prior_array, CArray) and isinstance(next_array, CArray)
                and prior_array.length is None and next_array.length is not None { previous.typ = typ; }
            if internal and not previous.internal { self.fail(item, "Object changes from external to internal linkage: " + name); }
            if initializer is not None and previous.initializer is not None { self.fail(item, "Duplicate object definition " + name); }
            # A later declaration can complete a previously unknown array bound.
            prior_base = unqualified(previous.typ); current_base = unqualified(typ);
            if isinstance(prior_base, CArray) and isinstance(current_base, CArray) and current_base.length is not None {
                previous.typ = typ;
            }
        }
        previous.alignment = max(previous.alignment, alignment);
        previous.declarations.append(item);
        if initializer is not None or "extern" not in storage { previous.definitions.append(item); }
        if initializer is not None { previous.initializer = initializer; }
        if "extern" not in storage { previous.tentative = True; }
        if previous.defined { previous.name = "c_" + name; }
    }

    def converted(value: CValue, typ: CType, explicit: bool = False) -> uni.Expr {
        target = unqualified(typ); source = unqualified(value.typ);
        if self.is_void(target) or self.is_void(source) { raise ValueError("A void expression cannot be converted to a value"); }
        if isinstance(target, CScalar) and target.category == "bool" { return self.ast.call("bool", [value.expr]); }
        if compatible(value.typ, typ, ignore_qualifiers=True) { return value.expr; }
        if isinstance(target, CScalar) and isinstance(source, CScalar) {
            scalar_constructor = target.jac if "floating" in [target.category, source.category] else target.jac + ".wrap";
            return self.ast.call(scalar_constructor, [value.expr]);
        }
        if isinstance(target, CPointer) {
            if value.null_pointer_constant {
                return self.ast.invoke(self.ast.member(self.ast.type_node(typ), "null"), []);
            }
            constructor = self.ast.member(self.ast.type_node(typ), "from_address");
            if isinstance(source, CScalar) and source.category in ["integer", "bool"] {
                if value.constant and value.integer_value == 0 {
                    return self.ast.invoke(self.ast.member(self.ast.type_node(typ), "null"), []);
                }
                if explicit { return self.ast.invoke(constructor, [value.expr]); }
            }
            if isinstance(source, CPointer) {
                keep_qualifiers = qualifiers_of(source.pointee).issubset(qualifiers_of(target.pointee));
                same_object = compatible(source.pointee, target.pointee, ignore_qualifiers=True);
                void_object = (self.is_void(source.pointee) and not isinstance(unqualified(target.pointee), CFunctionType))
                    or (self.is_void(target.pointee) and not isinstance(unqualified(source.pointee), CFunctionType));
                function_void = self.config.function_pointer_interop and (
                    (self.is_void(source.pointee) and isinstance(unqualified(target.pointee), CFunctionType))
                    or (self.is_void(target.pointee) and isinstance(unqualified(source.pointee), CFunctionType)));
                if explicit or (keep_qualifiers and (same_object or void_object or function_void)) {
                    address = self.ast.invoke(self.ast.member(value.expr, "address"), []);
                    return self.ast.invoke(constructor, [address]);
                }
            }
        }
        if explicit and isinstance(source, CPointer) and isinstance(target, CScalar) and target.category == "integer" {
            address = self.ast.invoke(self.ast.member(value.expr, "address"), []);
            return self.ast.call(target.jac + ".wrap", [address]);
        }
        raise ValueError("C conversion requires additional pointer or aggregate conversion rules");
    }

    def byte_array(typ: CArray, contents: bytes) -> CValue {
        element = unqualified(typ.element);
        if not isinstance(element, CScalar) or element.category != "integer" or element.width != 8 or element.rank != 1 {
            raise ValueError("String initializer requires a character array");
        }
        if typ.length is None { raise ValueError("String initializer requires a complete character array"); }
        if len(contents) > typ.length { raise ValueError("String initializer exceeds character array length"); }
        elements: list[uni.Expr] = [self.ast.call(element.jac + ".wrap", [self.ast.integer(byte)]) for byte in contents];
        initializer = self.ast.invoke(self.ast.type_node(typ), [self.ast.list_value(elements)]);
        return CValue(initializer, typ, True);
    }

    def string_storage(contents: bytes, constant_elements: bool = False) -> CBinding {
        terminated = contents + b"\x00";
        element: CType = CScalar(8, self.config.char_signed, 1);
        if constant_elements { element = CQualified(element, ("const",)); }
        typ = CArray(element, len(terminated));
        name = "_c2jac_literal_" + str(len(self.storage_nodes));
        value = self.byte_array(typ, terminated);
        self.storage_nodes.append(self.ast.global_var(name, self.ast.type_node(typ), value.expr, internal=True));
        return CBinding(name, typ, static_storage=True);
    }

    def initial_value(nd: CNode, typ: CType) -> CValue {
        base = unqualified(typ);
        if nd.kind == "initializer_list" { return self.aggregate_initial_value(nd, typ); }
        if nd.kind == "string" and isinstance(base, CArray) {
            contents = string_bytes(nd);
            # C permits omitting the terminating byte when the declared size is
            # exactly the number of string characters. Remaining slots zero-fill.
            if base.length != len(contents) { contents += b"\x00"; }
            return self.byte_array(base, contents);
        }
        value = self.expression(nd);
        value_type = unqualified(value.typ);
        if value.constant and value.integer_value is not None and isinstance(value_type, CScalar)
            and value_type.category in ["integer", "bool"] {
            value.expr = self.ast.call(value_type.jac, [self.ast.integer(value.integer_value)]);
        }
        return value;
    }

    def aggregate_initial_value(nd: CNode, typ: CType) -> CValue {
        base = unqualified(typ);
        if isinstance(base, CRecord) and base.is_packed() {
            self.fail(nd, "Packed aggregate initializer requires field-wise storage construction");
        }
        if isinstance(base, CRecord) and base.kind == "union" {
            return self.union_initial_value(nd, base);
        }
        if isinstance(base, CRecord) and base.byte_bitfields() is None and any(field.bit_width is not None for field in base.fields) {
            self.fail(nd, "Bitfield initializer requires packed field writes");
        }
        if not isinstance(base, (CArray, CRecord)) {
            if len(nd.operands) != 1 or nd.operands[0].kind == "designated_initializer" {
                self.fail(nd, "Scalar initializer must contain exactly one value");
            }
            return self.initial_value(nd.operands[0], typ);
        }
        if isinstance(base, CArray) and len(nd.operands) == 1 and nd.operands[0].kind == "string" {
            return self.initial_value(nd.operands[0], typ);
        }
        if isinstance(base, CArray) {
            if base.length is None or base.variable { self.fail(nd, "Array initializer requires a complete fixed bound"); }
            count = base.length or 0;
        } else {
            if base.kind != "struct" or not base.complete { self.fail(nd, "Initializer requires complete struct storage"); }
            count = len(base.fields);
        }
        values: dict[int, CValue] = {};
        cursor = 0;
        for item in nd.operands {
            source = item;
            if item.kind == "designated_initializer" {
                if len(item.operands) != 2 { self.fail(item, "Nested designators require subobject initialization planning"); }
                designator = item.operands[0]; source = item.operands[1];
                if isinstance(base, CArray) {
                    if designator.kind != "index_designator" { self.fail(designator, "Array initializer requires an index designator"); }
                    index = self.types.constant_bound(designator.operands[0]);
                    if index is None { self.fail(designator, "Array designator requires an integer constant"); }
                    assert index is not None;
                    cursor = index;
                } else {
                    if designator.kind != "field_designator" { self.fail(designator, "Struct initializer requires a member designator"); }
                    path = base.member_paths().get(designator.value);
                    if path is None { self.fail(designator, "Unknown initializer member " + designator.value); }
                    assert path is not None;
                    if len(path) != 1 { self.fail(designator, "Promoted member designators require subobject initialization planning"); }
                    cursor = path[0].ordinal;
                }
            }
            if cursor < 0 or cursor >= count { self.fail(item, "Initializer exceeds aggregate bounds"); }
            element = base.element if isinstance(base, CArray) else base.fields[cursor].typ;
            value = self.initial_value(source, element);
            # An unbraced aggregate expression must initialize the whole member.
            # Brace elision across scalar leaves needs a separate subobject cursor.
            converted = self.converted(value, element);
            values[cursor] = CValue(converted, element, value.constant);
            cursor += 1;
        }
        elements: list[uni.Expr] = [];
        constant = True;
        for index in range(count) {
            initialized = values.get(index);
            element = base.element if isinstance(base, CArray) else base.fields[index].typ;
            elements.append(initialized.expr if initialized is not None else self.zero(element));
            constant = constant and (initialized is None or initialized.constant);
        }
        if isinstance(base, CRecord) {
            bits = base.byte_bitfields();
            if bits is not None {
                combined: list[uni.Expr] = [];
                for field in base.fields {
                    if field.bit_width is None { combined.append(elements[field.ordinal]); continue; }
                    plan = next(bit for bit in bits if bit.field is field);
                    if plan.storage_ordinal != field.ordinal { continue; }
                    unit: uni.Expr = self.ast.call("u8", [self.ast.integer(0)]);
                    for member in bits {
                        if member.storage_ordinal != plan.storage_ordinal { continue; }
                        masked = self.bit_value(elements[member.field.ordinal], 0, member.width);
                        shifted = self.ast.binary("<<", masked, self.ast.integer(member.shift));
                        unit = self.ast.binary("|", unit, shifted);
                    }
                    combined.append(unit);
                }
                elements = combined;
            }
        }
        arguments = [self.ast.list_value(elements)] if isinstance(base, CArray) else elements;
        return CValue(self.ast.invoke(self.ast.type_node(typ), arguments), typ, constant);
    }

    def union_value(record: CRecord, field: CField, value: CValue) -> CValue {
        selected: CUnionInitializerHelper | None = None;
        for helper in self.union_initializer_helpers {
            if helper.record.identity == record.identity and helper.field.ordinal == field.ordinal {
                selected = helper; break;
            }
        }
        if selected is None {
            selected = CUnionInitializerHelper(self.fresh("union", "_c2jac_"), record, field);
            self.union_initializer_helpers.append(selected);
        }
        return CValue(self.ast.call(selected.name, [self.converted(value, field.typ)]), record, value.constant);
    }

    def union_initial_value(nd: CNode, record: CRecord) -> CValue {
        if not record.complete or not record.fields { self.fail(nd, "Union initializer requires complete nonempty storage"); }
        field = record.fields[0];
        selected: CValue | None = None;
        for (index, item) in enumerate(nd.operands) {
            source = item;
            if item.kind == "designated_initializer" {
                if len(item.operands) != 2 { self.fail(item, "Nested designators require subobject initialization planning"); }
                designator = item.operands[0]; source = item.operands[1];
                if designator.kind != "field_designator" { self.fail(item, "Union initializer requires a member designator"); }
                path = record.member_paths().get(designator.value);
                if path is None { self.fail(item, "Unknown initializer member " + designator.value); }
                assert path is not None;
                if len(path) != 1 { self.fail(item, "Promoted member designators require subobject initialization planning"); }
                field = path[0];
            } elif index != 0 { self.fail(item, "Initializer exceeds union bounds"); }
            if field.bit_width is not None { self.fail(item, "Bitfield initializer requires packed storage lowering"); }
            selected = self.initial_value(source, field.typ);
        }
        if selected is None { selected = CValue(self.zero(field.typ), field.typ, True); }
        return self.union_value(record, field, selected);
    }

    def zero(typ: CType) -> uni.Expr {
        base = unqualified(typ);
        if isinstance(base, CScalar) {
            return self.ast.boolean(False) if base.category == "bool" else self.ast.call(base.jac, [self.ast.integer(0)]);
        }
        annotation = self.ast.type_node(typ);
        if isinstance(base, CPointer) {
            return self.ast.invoke(self.ast.member(annotation, "null"), []);
        }
        if isinstance(base, CRecord) {
            if base.is_packed() {
                return self.ast.invoke(annotation, [self.ast.invoke(self.ast.packed_storage_type(base), [])]);
            }
            if base.kind == "union" {
                if not base.complete or not base.fields { raise ValueError("Union initializer requires complete nonempty storage"); }
                field = base.fields[0];
                return self.union_value(base, field, CValue(self.zero(field.typ), field.typ, True)).expr;
            }
            bit_units = base.full_bitfield_units();
            if bit_units is not None {
                return self.ast.invoke(annotation, [self.ast.call("u32", [self.ast.integer(0)])
                    for index in range(bit_units)]);
            }
            byte_fields = base.byte_bitfields();
            if byte_fields is not None {
                elements: list[uni.Expr] = [];
                for field in base.fields {
                    if field.bit_width is None { elements.append(self.zero(field.typ)); }
                    else {
                        bit = next(plan for plan in byte_fields if plan.field is field);
                        if bit.storage_ordinal == field.ordinal { elements.append(self.ast.call("u8", [self.ast.integer(0)])); }
                    }
                }
                return self.ast.invoke(annotation, elements);
            }
            return self.ast.invoke(annotation, [self.zero(field.typ) for field in base.fields]);
        }
        return self.ast.invoke(annotation, []);
    }

    def binding(nd: CNode) -> CBinding {
        if nd.kind == "parenthesized" { return self.binding(nd.operands[0]); }
        if nd.kind != "identifier" { self.fail(nd, "Only scalar identifier lvalues are supported"); }
        for scope in reversed(self.scopes) {
            found = scope.get(nd.value);
            if found is not None { return found; }
        }
        found = self.globals.get(nd.value);
        if found is not None { found.referenced = True; return found; }
        self.fail(nd, "Unknown scalar identifier " + nd.value);
        return CBinding("", CScalar());
    }

    def named_function(nd: CNode) -> CFunction | None {
        if nd.kind != "identifier" or any(nd.value in scope for scope in self.scopes)
            or self.types.constant(nd.value) is not None { return None; }
        return self.functions.get(nd.value);
    }

    def integer(nd: CNode) -> CValue {
        (number, typ) = integer_literal(nd.value, self.config);
        return CValue(self.ast.call(typ.jac, [self.ast.integer(number)]), typ, True, number);
    }

    def binary(op: str, left: CValue, right: CValue, nd: CNode) -> CValue {
        self.ast.origin = nd;
        if self.is_void(left.typ) or self.is_void(right.typ) { self.fail(nd, "Void operand in integer expression"); }
        constant = left.constant and right.constant;
        if op in ["&&", "||"] {
            value = self.ast.binary("and" if op == "&&" else "or",
                self.ast.call("bool", [left.expr]), self.ast.call("bool", [right.expr]));
            return CValue(self.ast.call("i32", [value]), CScalar(), constant);
        }
        left_base = unqualified(left.typ); right_base = unqualified(right.typ);
        if op in ["==", "!="] {
            if left.null_pointer_constant and isinstance(right_base, CPointer) {
                left = CValue(self.converted(left, right.typ), right.typ, True);
                left_base = right_base;
            } elif right.null_pointer_constant and isinstance(left_base, CPointer) {
                right = CValue(self.converted(right, left.typ), left.typ, True);
                right_base = left_base;
            }
        }
        if isinstance(right_base, CPointer) and op == "+" and isinstance(left_base, CScalar) {
            return self.binary(op, right, left, nd);
        }
        if op in ["==", "!="] and isinstance(right_base, CPointer) and isinstance(left_base, CScalar) {
            return self.binary(op, right, left, nd);
        }
        if isinstance(left_base, CPointer) {
            if op in ["==", "!="] and isinstance(right_base, CScalar) {
                if not right.constant or right.integer_value != 0 {
                    self.fail(nd, "Pointer comparison requires a pointer or null pointer constant");
                }
                null = self.converted(right, left.typ);
                lhs = self.ast.invoke(self.ast.member(left.expr, "address"), []);
                rhs = self.ast.invoke(self.ast.member(null, "address"), []);
                return CValue(self.ast.call("i32", [self.ast.binary(op, lhs, rhs)]), CScalar());
            }
            if op in ["+", "-"] and isinstance(right_base, CScalar) {
                self.scalar_type(right.typ, nd, integer_only=True);
                pointee = unqualified(left_base.pointee);
                if self.is_void(pointee) { self.fail(nd, "Void-pointer arithmetic requires an explicit byte-pointer extension"); }
                if isinstance(pointee, CFunctionType) { self.fail(nd, "Function pointers do not support arithmetic"); }
                if isinstance(pointee, CRecord) and not pointee.complete { self.fail(nd, "Pointer arithmetic requires a complete object type"); }
                self.ast.type_node(pointee);
                # Negate in the pointer-width domain: the index may be
                # unsigned or the minimum signed value of a narrower type.
                displacement = right.expr if op == "+" else self.ast.call("wrapping_neg", [
                    self.ast.call(self.config.size_type().jac + ".wrap", [right.expr])]);
                return CValue(self.ast.invoke(self.ast.member(left.expr, "offset"), [displacement]),
                    left.typ, left.constant and right.constant);
            }
            if op == "-" and isinstance(right_base, CPointer) {
                pointee = unqualified(left_base.pointee);
                if not compatible(left_base.pointee, right_base.pointee, ignore_qualifiers=True)
                    or self.is_void(pointee) or isinstance(pointee, CFunctionType) {
                    self.fail(nd, "Pointer subtraction requires compatible complete object types");
                }
                if isinstance(pointee, CRecord) and not pointee.complete {
                    self.fail(nd, "Pointer subtraction requires complete object storage");
                }
                annotation = self.ast.type_node(pointee);
                size_type = self.config.size_type();
                difference_type = CScalar(size_type.width, True, size_type.rank);
                addresses = [self.ast.call(size_type.jac + ".wrap", [
                    self.ast.invoke(self.ast.member(value.expr, "address"), [])]) for value in [left, right]];
                # Subtract in the unsigned address domain before interpreting
                # the representable C ptrdiff_t result as signed.
                distance = self.ast.call(difference_type.jac + ".wrap", [self.ast.call("wrapping_sub", addresses)]);
                extent = self.types.storage_size(pointee);
                size = self.ast.integer(extent) if extent is not None else self.ast.call("size_of", [annotation]);
                divisor = self.ast.call(difference_type.jac, [size]);
                return CValue(self.ast.call(difference_type.jac, [self.ast.binary("//", distance, divisor)]), difference_type);
            }
            if op in ["==", "!=", "<", ">", "<=", ">="] and isinstance(right_base, CPointer) {
                left_pointee = unqualified(left_base.pointee);
                right_pointee = unqualified(right_base.pointee);
                same_type = compatible(left_pointee, right_pointee);
                object_void = (self.is_void(left_pointee) and not isinstance(right_pointee, CFunctionType))
                    or (self.is_void(right_pointee) and not isinstance(left_pointee, CFunctionType));
                if op in ["==", "!="] {
                    if not same_type and not object_void { self.fail(nd, "Equality comparison requires compatible object or function pointers"); }
                } elif not same_type or isinstance(left_pointee, CFunctionType) {
                    self.fail(nd, "Ordered comparison requires pointers to compatible object types");
                }
                # Native addresses have an unsigned ordering. This also covers
                # GNU comparisons between compatible void pointers.
                lhs = self.ast.call(self.config.size_type().jac + ".wrap", [self.ast.invoke(self.ast.member(left.expr, "address"), [])]);
                rhs = self.ast.call(self.config.size_type().jac + ".wrap", [self.ast.invoke(self.ast.member(right.expr, "address"), [])]);
                return CValue(self.ast.call("i32", [self.ast.binary(op, lhs, rhs)]), CScalar());
            }
            self.fail(nd, "Pointer operation requires additional C conversion or pointer-difference lowering");
        }
        integer_only = op in ["%", "<<", ">>", "&", "|", "^"];
        left_scalar = self.scalar_type(left.typ, nd, integer_only);
        right_scalar = self.scalar_type(right.typ, nd, integer_only);
        typ = promote(left_scalar) if op in ["<<", ">>"] else common(left_scalar, right_scalar);
        a = self.converted(left, typ);
        # Jac fixed-width shifts use matching operand types. Every defined C
        # shift count fits the promoted left type, so this conversion preserves
        # valid counts while retaining C's left-operand result width.
        b = self.converted(right, typ);
        if op in ["==", "!=", "<", ">", "<=", ">="] {
            return CValue(self.ast.call("i32", [self.ast.binary(op, a, b)]), CScalar(), constant);
        }
        wrapping = {"+": "wrapping_add", "-": "wrapping_sub", "*": "wrapping_mul", "<<": "wrapping_shl"};
        expr: uni.Expr;
        if typ.category == "floating" { expr = self.ast.call(typ.jac, [self.ast.binary(op, a, b)]); }
        elif not typ.signed and op in wrapping { expr = self.ast.call(wrapping[op], [a, b]); }
        elif op in ["/", "%"] and typ.signed {
            helper = "_c2jac_" + ("div_" if op == "/" else "rem_") + typ.jac;
            self.helpers[helper] = typ;
            if op == "%" { self.helpers["_c2jac_div_" + typ.jac] = typ; }
            expr = self.ast.call(helper, [a, b]);
        } else { expr = self.ast.binary("//" if op == "/" else op, a, b); }
        return CValue(expr, typ, constant);
    }

    def expression(nd: CNode, decay: bool = True) -> CValue {
        value = self.lower_expression(nd);
        if value.constant {
            constant = self.types.integer_constant(nd);
            if constant is not None { value.integer_value = constant.value; }
        }
        base = unqualified(value.typ);
        if decay and isinstance(base, CArray) {
            if value.unaligned_address is not None { self.fail(nd, "Packed array decay requires unaligned element views"); }
            qualifiers = qualifiers_of(value.typ);
            element = CQualified(base.element, tuple(sorted(qualifiers))) if qualifiers else base.element;
            value = CValue(self.ast.invoke(self.ast.member(value.expr, "data"), []), CPointer(element), value.constant or value.address_constant);
        } elif decay {
            qualifiers = qualifiers_of(value.typ);
            if value.bit_width { value.typ = base; }
            elif "_Atomic" in qualifiers or "volatile" in qualifiers {
                if value.unaligned_address is not None { self.fail(nd, "Qualified unaligned memory accesses require combined memory operations"); }
                self.ast.type_node(value.typ);
                address = self.ast.call("addr_of", [value.expr]);
                args: list[uni.Expr] = [self.ast.string("seq_cst"), self.ast.boolean("volatile" in qualifiers)]
                    if "_Atomic" in qualifiers else [];
                method = "atomic_load" if "_Atomic" in qualifiers else "load_volatile";
                value = CValue(self.ast.invoke(self.ast.member(address, method), args), base);
            } else { value.typ = base; }
        }
        self.ast.origin = nd;
        self.ast.mark(value.expr);
        return value;
    }

    def lower_expression(nd: CNode) -> CValue {
        self.current = nd; self.ast.origin = nd; children = nd.operands; kind = nd.kind;
        if kind == "compound_literal" {
            literal_type = self.variable(children[0].operands[0], children[0].operands[1]);
            if not isinstance(unqualified(literal_type), CRecord) {
                self.fail(nd, "Compound literal storage requires record value semantics");
            }
            return self.initial_value(children[1], literal_type);
        }
        if kind == "comma" {
            self.check_expression_block(children[0]);
            effects = self.effect(children[0]);
            value = self.expression(children[1]);
            if self.is_void(value.typ) { self.fail(nd, "Void comma values require a discarded-expression context"); }
            return CValue(self.ast.evaluated_block(effects, value.expr, value.typ), value.typ);
        }
        if kind == "statement_expression" {
            block = children[0]; self.check_expression_block(block);
            if not block.operands or block.operands[-1].kind != "expression" {
                self.fail(nd, "A value-producing statement expression must end with an expression");
            }
            self.scopes.append({}); self.types.enter_scope();
            try {
                statements: list[uni.CodeBlockStmt] = [];
                for child in block.operands[:-1] {
                    statements.extend(self.local_declaration(child) if child.kind == "declaration"
                        else self.statement(child));
                }
                result = self.expression(block.operands[-1].operands[0]);
                if self.is_void(result.typ) { self.fail(nd, "Void statement expression requires a discarded-expression context"); }
                return CValue(self.ast.evaluated_block(statements, result.expr, result.typ), result.typ);
            } finally { self.scopes.pop(); self.types.leave_scope(); }
        }
        if kind == "assignment" or (kind in ["unary", "postfix"] and nd.value in ["++", "--"]) {
            return self.assignment_value(nd);
        }
        if kind == "number" {
            if is_floating_literal(nd.value) {
                (number, float_type) = floating_literal(nd.value);
                return CValue(self.ast.call(float_type.jac, [self.ast.floating(number)]), float_type, True);
            }
            return self.integer(nd);
        }
        if kind == "string" {
            literal = self.string_storage(string_bytes(nd));
            return CValue(self.ast.name(literal.name), literal.typ, True, address_constant=True);
        }
        if kind == "char" {
            character = character_literal(nd.value);
            return CValue(self.ast.call("i32", [self.ast.integer(character)]), CScalar(), True, character);
        }
        if kind == "identifier" {
            if nd.value in ["__func__", "__FUNCTION__", "__PRETTY_FUNCTION__"] and self.current_function
                and not any(nd.value in scope for scope in self.scopes) {
                key = self.current_function + ":" + nd.value;
                function_literal = self.function_strings.get(key);
                if function_literal is None {
                    function_literal = self.string_storage(self.current_function.encode("ascii"), constant_elements=True);
                    self.function_strings[key] = function_literal;
                }
                return CValue(self.ast.name(function_literal.name), function_literal.typ, True, address_constant=True);
            }
            constant = self.types.constant(nd.value);
            if constant is not None {
                return CValue(self.ast.call(constant.typ.jac, [self.ast.integer(constant.value)]),
                    constant.typ, True, constant.value);
            }
            function = self.named_function(nd);
            if function is not None {
                function.referenced = True;
                function.address_referenced = True;
                return CValue(self.ast.call("addr_of", [self.ast.name(function.address_name)]), CPointer(function.signature), True);
            }
            bound = self.binding(nd);
            return CValue(self.binding_place(bound), bound.typ, address_constant=bound.static_storage);
        }
        if kind in ["parenthesized", "extension"] { return self.expression(children[0], decay=False); }
        if kind == "subscript" {
            pointer = self.expression(children[0]); index = self.expression(children[1]);
            pointer_type = unqualified(pointer.typ);
            if not isinstance(pointer_type, CPointer) {
                (pointer, index) = (index, pointer);
                pointer_type = unqualified(pointer.typ);
            }
            if not isinstance(pointer_type, CPointer) { self.fail(nd, "Subscript requires a pointer and an integer"); return index; }
            self.scalar_type(index.typ, nd, integer_only=True);
            if self.is_void(pointer_type.pointee) { self.fail(nd, "Cannot subscript a void pointer"); }
            self.ast.type_node(pointer_type.pointee);
            return CValue(self.ast.index(pointer.expr, index.expr), pointer_type.pointee, address_constant=pointer.constant and index.constant);
        }
        if kind == "member" {
            indirect = nd.value.startswith("->");
            owner = self.expression(children[0], decay=indirect);
            owner_type = unqualified(owner.typ); owner_expr = owner.expr;
            unaligned_address = owner.unaligned_address;
            inherited_qualifiers = qualifiers_of(owner.typ);
            if indirect {
                if not isinstance(owner_type, CPointer) { self.fail(nd, "Arrow access requires a pointer"); return owner; }
                inherited_qualifiers = qualifiers_of(owner_type.pointee);
                owner_type = unqualified(owner_type.pointee);
                owner_expr = self.ast.index(owner_expr, self.ast.integer(0));
                unaligned_address = None;
            }
            if not isinstance(owner_type, CRecord) { self.fail(nd, "Member access requires a record"); return owner; }
            member_name = nd.value[2:] if indirect else nd.value[1:];
            path = owner_type.member_paths().get(member_name);
            if path is None { self.fail(nd, "Unknown C record field " + member_name); return owner; }
            member_type: CType = owner_type;
            for field in path {
                container = unqualified(member_type);
                assert isinstance(container, CRecord);
                if field.bit_width is not None {
                    plans = container.byte_bitfields();
                    if plans is None or container.is_packed() or unaligned_address is not None {
                        self.fail(nd, "Bitfield access requires a supported target allocation unit");
                    }
                    assert plans is not None;
                    bit = next(plan for plan in plans if plan.field is field);
                    inherited_qualifiers.update(qualifiers_of(field.typ));
                    if "_Atomic" in inherited_qualifiers { self.fail(nd, "Atomic bitfields are not supported by C"); }
                    self.ast.type_node(container);
                    unit = self.ast.member(owner_expr, bit.storage_name);
                    address = self.ast.call("addr_of", [self.ast.clone(unit)]);
                    loaded: uni.Expr = self.ast.invoke(self.ast.member(address, "load_volatile"), [])
                        if "volatile" in inherited_qualifiers else unit;
                    result_type = CQualified(field.typ, tuple(sorted(inherited_qualifiers))) if inherited_qualifiers else field.typ;
                    return CValue(self.bit_value(loaded, bit.shift, bit.width), result_type,
                        bitfield_address=address, bit_shift=bit.shift, bit_width=bit.width);
                }
                inherited_qualifiers.update(qualifiers_of(field.typ));
                if container.is_packed() or unaligned_address is not None {
                    self.ast.type_node(container);
                    base_address = unaligned_address or self.ast.call("addr_of", [owner_expr]);
                    integer_address = self.ast.call(self.config.size_type().jac + ".wrap", [
                        self.ast.invoke(self.ast.member(base_address, "address"), [])]);
                    displacement = self.ast.call(self.config.size_type().jac, [self.ast.field_offset(container, field)]);
                    unaligned_address = self.ast.invoke(self.ast.member(self.ast.type_node(CPointer(field.typ)), "from_address"),
                        [self.ast.call("wrapping_add", [integer_address, displacement])]);
                    owner_expr = self.ast.invoke(self.ast.member(unaligned_address, "load_unaligned"), []);
                } else {
                    owner_expr = self.ast.field_access(owner_expr, container, field);
                }
                member_type = field.typ;
            }
            if inherited_qualifiers { member_type = CQualified(member_type, tuple(sorted(inherited_qualifiers))); }
            return CValue(owner_expr, member_type, address_constant=owner.constant if indirect else owner.address_constant,
                unaligned_address=unaligned_address);
        }
        if kind == "cast" {
            type_parts = children[0].operands;
            cast_type = self.declared_type(type_parts[0], type_parts[1]); value = self.expression(children[1]);
            if self.is_void(cast_type) { return CValue(value.expr, cast_type, value.constant); }
            cast_expr = self.converted(value, cast_type, explicit=True);
            cast_base = unqualified(cast_type); source_base = unqualified(value.typ);
            converted_integer: int | None = None;
            if value.integer_value is not None and isinstance(cast_base, CScalar) and isinstance(source_base, CScalar)
                and cast_base.category in ["integer", "bool"] and source_base.category in ["integer", "bool"] {
                converted_integer = CInteger(value.integer_value, source_base).converted(cast_base).value;
            }
            null_constant = isinstance(cast_base, CPointer) and self.is_void(cast_base.pointee)
                and isinstance(source_base, CScalar) and source_base.category in ["integer", "bool"]
                and value.constant and value.integer_value == 0;
            return CValue(cast_expr, cast_type, value.constant, converted_integer, null_pointer_constant=null_constant);
        }
        if kind == "unary" {
            op = nd.value;
            if op == "&" {
                addressed = children[0];
                while addressed.kind == "parenthesized" { addressed = addressed.operands[0]; }
                if self.named_function(addressed) is not None { return self.expression(addressed); }
                if addressed.kind == "unary" and addressed.value == "*" {
                    dereferenced = self.expression(addressed.operands[0]);
                    dereferenced_type = unqualified(dereferenced.typ);
                    if isinstance(dereferenced_type, CPointer) and isinstance(unqualified(dereferenced_type.pointee), CFunctionType) {
                        return dereferenced;
                    }
                }
                if addressed.kind not in ["identifier", "subscript", "member"] and not (addressed.kind == "unary" and addressed.value == "*") {
                    self.fail(nd, "Address-of requires an addressable C expression");
                }
                referent = self.place(children[0]);
                if referent.bit_width { self.fail(nd, "Cannot take the address of a bitfield"); }
                return CValue(referent.unaligned_address or self.ast.call("addr_of", [referent.expr]),
                    CPointer(referent.typ), referent.address_constant);
            }
            if op == "*" {
                pointer_value = self.expression(children[0]); pointed = unqualified(pointer_value.typ);
                if not isinstance(pointed, CPointer) { self.fail(nd, "Dereference requires a pointer"); return pointer_value; }
                if self.is_void(pointed.pointee) { self.fail(nd, "Cannot dereference a void pointer"); }
                if isinstance(unqualified(pointed.pointee), CFunctionType) { return pointer_value; }
                self.ast.type_node(pointed.pointee);
                return CValue(self.ast.index(pointer_value.expr, self.ast.integer(0)), pointed.pointee, address_constant=pointer_value.constant);
            }
            if op not in ["+", "-", "~", "!"] { self.fail(nd, "Expression-valued " + op + " is not emitted yet"); }
            value = self.expression(children[0]);
            if self.is_void(value.typ) { self.fail(nd, "Void operand in unary expression"); }
            if op == "!" { return CValue(self.ast.call("i32", [self.ast.unary("not", self.ast.call("bool", [value.expr]))]), CScalar(), value.constant); }
            typ = promote(self.scalar_type(value.typ, nd, integer_only=op == "~")); code = self.converted(value, typ);
            if op == "-" and not typ.signed { code = self.ast.call("wrapping_neg", [code]); }
            else { code = self.ast.unary(op, code); }
            return CValue(code, typ, value.constant);
        }
        if kind == "binary" { return self.binary(nd.value, self.expression(children[0]), self.expression(children[1]), nd); }
        if kind == "conditional" {
            condition = self.expression(children[0]); yes = self.expression(children[1]); no = self.expression(children[2]);
            if self.is_void(condition.typ) or self.is_void(yes.typ) or self.is_void(no.typ) { self.fail(nd, "Void conditional expressions are not emitted yet"); }
            selected_type = self.conditional_type(yes, no, nd);
            return CValue(self.ast.conditional(self.ast.call("bool", [condition.expr]), self.converted(yes, selected_type), self.converted(no, selected_type)), selected_type, condition.constant and yes.constant and no.constant);
        }
        if kind == "call" {
            if children[0].kind == "identifier" and children[0].value.startswith("__atomic_") {
                return self.atomic_call(nd);
            }
            if children[0].kind == "identifier" and children[0].value in ["__builtin_clz", "__builtin_clzl", "__builtin_clzll"] {
                if len(children) != 2 { self.fail(nd, "Leading-zero builtin requires one integer argument"); }
                spelling = children[0].value;
                words = ["unsigned", "int"] if spelling == "__builtin_clz" else
                    (["unsigned", "long"] if spelling == "__builtin_clzl" else ["unsigned", "long", "long"]);
                integer_type = self.scalar_type(self.types.scalar_words(nd, words), nd);
                value = self.expression(children[1]); self.scalar_type(value.typ, nd, integer_only=True);
                # Shift first so even an unsigned 64-bit value fits Jac's native
                # signed int. This reuses the existing bit_length primitive,
                # evaluates the operand once, and is exact for every nonzero C
                # argument (the C builtin is undefined for zero).
                shifted = self.ast.binary(">>", self.converted(value, integer_type), self.ast.integer(1));
                length = self.ast.invoke(self.ast.member(self.ast.call("int", [shifted]), "bit_length"), []);
                leading_count = self.ast.binary("-", self.ast.integer(integer_type.width - 1), length);
                return CValue(self.ast.call("i32", [leading_count]), CScalar());
            }
            if children[0].kind == "identifier" and children[0].value == "__builtin_assume_aligned" {
                if len(children) not in [3, 4] { self.fail(nd, "Alignment promise requires a pointer, alignment and optional offset"); }
                alignment = self.types.constant_bound(children[2]);
                if alignment is None or alignment <= 0 or (alignment & (alignment - 1)) != 0 {
                    self.fail(nd, "Alignment promise requires a positive constant power of two");
                }
                if len(children) == 4 and self.types.constant_bound(children[3]) is None {
                    self.fail(nd, "Alignment promise offset requires a constant integer");
                }
                value = self.expression(children[1]);
                promised_pointer = CPointer(CScalar(category="void"));
                return CValue(self.converted(value, promised_pointer), promised_pointer, value.constant);
            }
            if children[0].kind == "identifier" and children[0].value == "__builtin_expect" {
                if len(children) != 3 or self.types.integer_constant(children[2]) is None {
                    self.fail(nd, "__builtin_expect requires a value and an integer constant expectation");
                }
                expected_value = self.expression(children[1]);
                long_type = self.scalar_type(self.types.scalar_words(nd, ["long"]), nd);
                return CValue(self.converted(expected_value, long_type), long_type, expected_value.constant);
            }
            callee = children[0]; function = self.named_function(callee);
            call_target: uni.Expr;
            signature: CFunctionType;
            if function is not None {
                function.referenced = True;
                signature = function.signature;
                call_target = self.ast.name(function.emitted_name);
            } else {
                called = self.expression(callee); called_type = unqualified(called.typ);
                if not isinstance(called_type, CPointer) or not isinstance(unqualified(called_type.pointee), CFunctionType) {
                    self.fail(callee, "Call target is not a C function or function pointer");
                    return called;
                }
                signature_type = unqualified(called_type.pointee);
                assert isinstance(signature_type, CFunctionType);
                signature = signature_type;
                call_target = self.ast.member(called.expr, "call");
            }
            if not signature.prototype { self.fail(callee, "Call requires a function prototype"); }
            count = len(children) - 1;
            fixed = len(signature.parameters);
            if count < fixed or (not signature.variadic and count != fixed) { self.fail(nd, "Incorrect C argument count"); }
            args: list[uni.Expr] = [];
            for i in range(len(signature.parameters)) { args.append(self.converted(self.expression(children[i + 1]), signature.parameters[i])); }
            for child in children[fixed + 1:] {
                argument = self.expression(child);
                argument_type = unqualified(argument.typ);
                if isinstance(argument_type, CScalar) and argument_type.category != "void" {
                    promoted = CScalar(64, True, 2, "floating")
                        if argument_type.category == "floating" and argument_type.width == 32 else promote(argument_type);
                    args.append(self.converted(argument, promoted));
                } elif isinstance(argument_type, CPointer) {
                    args.append(argument.expr);
                } else { self.fail(child, "Variadic aggregate arguments require target ABI classification"); }
            }
            return CValue(self.ast.invoke(call_target, args), signature.returns);
        }
        if kind == "builtin" and nd.value == "__builtin_offsetof" {
            record = self.variable(children[0].operands[0], children[0].operands[1]);
            (offset, _) = self.offset_designator(record, children[1]);
            return CValue(offset, self.config.size_type(), True);
        }
        if kind in ["sizeof_type", "sizeof_expr"] {
            if kind == "sizeof_expr" and self.expression(children[0], decay=False).bit_width {
                self.fail(nd, "sizeof cannot designate a bitfield");
            }
            known = self.types.integer_constant(nd);
            if known is not None {
                return CValue(self.ast.call(known.typ.jac, [self.ast.integer(known.value)]),
                    known.typ, True, known.value);
            }
            # Only the type is used; the operand's expression tree is never emitted.
            sized_type = self.variable(children[0].operands[0], children[0].operands[1]) if kind == "sizeof_type" else self.expression(children[0], decay=False).typ;
            if self.is_void(sized_type) { self.fail(nd, "sizeof(void) is not standard C"); }
            size = self.types.storage_size(sized_type);
            size_type = self.config.size_type();
            if size is None {
                base = unqualified(sized_type);
                if (isinstance(base, CRecord) and base.complete)
                    or (isinstance(base, CArray) and base.length is not None and not base.variable) {
                    measured = self.ast.call("size_of", [self.ast.type_node(sized_type)]);
                    return CValue(self.ast.call(size_type.jac, [measured]), size_type, True);
                }
                self.fail(nd, "sizeof requires resolved object layout or variable-length array lowering");
            }
            assert size is not None;
            return CValue(self.ast.call(size_type.jac, [self.ast.integer(size)]), size_type, True, size);
        }
        self.fail(nd, "Expression '" + kind + "' requires further source lowering");
        return CValue(self.ast.integer(0), CScalar());
    }

    def check_expression_block(nd: CNode) {
        pending = [nd];
        while pending {
            part = pending.pop();
            if part.kind in ["return", "goto", "break", "continue", "label"] {
                self.fail(part, "Expression block requires nonlocal control-flow lowering");
            }
            pending.extend(part.operands);
        }
    }

    def atomic_order(nd: CNode) -> int {
        value = self.types.integer_constant(nd);
        if value is None or value.value not in range(6) {
            self.fail(nd, "Atomic ordering must be a supported constant memory_order value");
        }
        assert value is not None;
        return value.value;
    }

    def atomic_call(nd: CNode) -> CValue {
        name = nd.operands[0].value;
        operands = nd.operands[1:];
        fetch = {"__atomic_fetch_add": "atomic_fetch_add", "__atomic_fetch_sub": "atomic_fetch_sub",
            "__atomic_fetch_and": "atomic_fetch_and", "__atomic_fetch_or": "atomic_fetch_or",
            "__atomic_fetch_xor": "atomic_fetch_xor", "__atomic_fetch_nand": "atomic_fetch_nand"};
        counts = {"__atomic_load": 3, "__atomic_load_n": 2, "__atomic_store": 3, "__atomic_store_n": 3,
            "__atomic_exchange": 4, "__atomic_exchange_n": 3, "__atomic_compare_exchange": 6,
            "__atomic_compare_exchange_n": 6};
        required = 3 if name in fetch else counts.get(name);
        if required is None or len(operands) != required {
            self.fail(nd, "Unsupported atomic builtin or argument count: " + name);
        }
        pointer = self.expression(operands[0]);
        pointer_type = unqualified(pointer.typ);
        if not isinstance(pointer_type, CPointer) { self.fail(nd, "Atomic operation requires a pointer"); }
        assert isinstance(pointer_type, CPointer);
        base = unqualified(pointer_type.pointee);
        if not self.config.scalar_atomic_storage(base) { self.fail(nd, "Atomic operation requires supported scalar storage"); }
        self.ast.type_node(pointer_type.pointee);
        qualifiers = qualifiers_of(pointer_type.pointee);
        if "const" in qualifiers and name not in ["__atomic_load", "__atomic_load_n"] {
            self.fail(nd, "Atomic update cannot modify const storage");
        }
        order_names = ["relaxed", "consume", "acquire", "release", "acq_rel", "seq_cst"];
        order = self.atomic_order(operands[-2] if name.startswith("__atomic_compare_exchange") else operands[-1]);
        order_expr = self.ast.string(order_names[order]);
        volatile = self.ast.boolean("volatile" in qualifiers);
        void = CScalar(category="void");
        if name in ["__atomic_load", "__atomic_load_n"] {
            if order in [3, 4] { self.fail(nd, "Atomic loads cannot use release or acq_rel ordering"); }
            loaded = self.ast.invoke(self.ast.member(pointer.expr, "atomic_load"), [order_expr, volatile]);
            if name == "__atomic_load_n" { return CValue(loaded, base); }
            output = self.atomic_buffer(operands[1], base, writable=True);
            return CValue(self.ast.invoke(self.ast.member(output.expr, "store"), [loaded]), void);
        }
        if name.startswith("__atomic_compare_exchange") {
            expected = self.atomic_buffer(operands[1], base, writable=True);
            desired = self.expression(operands[2]) if name.endswith("_n") else
                CValue(self.ast.invoke(self.ast.member(self.atomic_buffer(operands[2], base).expr, "load"), []), base);
            weak = self.types.integer_constant(operands[3]);
            if weak is None { self.fail(nd, "Compare-exchange weak flag must be constant"); }
            assert weak is not None;
            failure = self.atomic_order(operands[5]);
            allowed = {0: [0], 1: [0, 1], 2: [0, 1, 2], 3: [0], 4: [0, 1, 2], 5: [0, 1, 2, 5]};
            if failure not in allowed[order] { self.fail(nd, "Invalid compare-exchange failure ordering"); }
            called = self.ast.invoke(self.ast.member(pointer.expr, "atomic_compare_exchange"), [
                expected.expr, self.converted(desired, base), order_expr, self.ast.string(order_names[failure]),
                self.ast.boolean(weak.value != 0), volatile]);
            return CValue(called, CScalar(8, False, 0, "bool"));
        }
        argument = self.expression(operands[1]) if name.endswith("_n") or name in fetch else
            CValue(self.ast.invoke(self.ast.member(self.atomic_buffer(operands[1], base).expr, "load"), []), base);
        if name in ["__atomic_store", "__atomic_store_n"] {
            if order in [1, 2, 4] { self.fail(nd, "Atomic stores cannot use acquire, consume or acq_rel ordering"); }
            method = "atomic_store";
        } else { method = fetch.get(name, "atomic_exchange"); }
        if name in fetch and not isinstance(base, CScalar) { self.fail(nd, "Atomic fetch arithmetic requires integer storage"); }
        called = self.ast.invoke(self.ast.member(pointer.expr, method), [self.converted(argument, base), order_expr, volatile]);
        if name == "__atomic_exchange" {
            output = self.atomic_buffer(operands[2], base, writable=True);
            return CValue(self.ast.invoke(self.ast.member(output.expr, "store"), [called]), void);
        }
        return CValue(called, void if method == "atomic_store" else base);
    }

    def atomic_buffer(nd: CNode, typ: CType, writable: bool = False) -> CValue {
        value = self.expression(nd); pointer = unqualified(value.typ);
        if not isinstance(pointer, CPointer) { self.fail(nd, "Atomic buffer requires a pointer"); }
        assert isinstance(pointer, CPointer);
        if not compatible(pointer.pointee, typ, ignore_qualifiers=True)
            or (writable and "const" in qualifiers_of(pointer.pointee)) {
            self.fail(nd, "Atomic buffer must point to compatible writable storage");
        }
        if any(q not in ["const", "restrict"] for q in qualifiers_of(pointer.pointee)) {
            self.fail(nd, "Atomic auxiliary buffers require ordinary scalar storage");
        }
        return value;
    }

    def offset_designator(typ: CType, nd: CNode) -> tuple[uni.Expr, CType] {
        size_type = self.config.size_type();
        if nd.kind == "member" and nd.value.startswith(".") {
            (prefix, owner) = self.offset_designator(typ, nd.operands[0]);
            (suffix, field_type) = self.offset_field(owner, nd.value[1:], nd);
            return (self.ast.call("wrapping_add", [prefix, suffix]), field_type);
        }
        if nd.kind == "subscript" {
            (prefix, owner) = self.offset_designator(typ, nd.operands[0]);
            base = unqualified(owner); index = self.types.integer_constant(nd.operands[1]);
            if not isinstance(base, CArray) or index is None or index.value < 0 {
                self.fail(nd, "offsetof subscript requires array storage and a nonnegative integer constant");
            }
            assert isinstance(base, CArray) and index is not None;
            extent = self.ast.call(size_type.jac, [self.ast.call("size_of", [self.ast.type_node(base.element)])]);
            displacement = self.ast.call("wrapping_mul", [extent,
                self.ast.call(size_type.jac, [self.ast.integer(index.value)])]);
            return (self.ast.call("wrapping_add", [prefix, displacement]), base.element);
        }
        if nd.kind == "identifier" { return self.offset_field(typ, nd.value, nd); }
        self.fail(nd, "Unsupported offsetof member designator");
        return (self.ast.integer(0), typ);
    }

    def offset_field(typ: CType, name: str, nd: CNode) -> tuple[uni.Expr, CType] {
        base = unqualified(typ);
        if not isinstance(base, CRecord) or not base.complete { self.fail(nd, "offsetof requires a complete record type"); }
        assert isinstance(base, CRecord);
        path = base.member_paths().get(name);
        if path is None { self.fail(nd, "Unknown offsetof member " + name); }
        assert path is not None;
        result = self.ast.call(self.config.size_type().jac, [self.ast.integer(0)]);
        member_type: CType = typ;
        for field in path {
            owner = unqualified(member_type);
            assert isinstance(owner, CRecord);
            if field.bit_width is not None { self.fail(nd, "offsetof cannot designate a bitfield"); }
            if owner.kind != "union" {
                measured = self.ast.field_offset(owner, field);
                result = self.ast.call("wrapping_add", [result,
                    self.ast.call(self.config.size_type().jac, [measured])]);
            } else { self.ast.type_node(owner); }
            member_type = field.typ;
        }
        return (result, member_type);
    }

    def place(nd: CNode) -> CValue {
        if nd.kind == "identifier" and self.types.constant(nd.value) is not None {
            self.fail(nd, "Enumerator does not designate addressable storage");
        }
        if nd.kind == "parenthesized" { return self.place(nd.operands[0]); }
        if nd.kind == "member" and nd.value.startswith(".") { self.place(nd.operands[0]); }
        elif nd.kind not in ["identifier", "subscript", "member"] and not (nd.kind == "unary" and nd.value == "*") {
            self.fail(nd, "Expression does not designate C storage");
        }
        return self.expression(nd, decay=False);
    }

    def bit_value(value: uni.Expr, shift: int, width: int) -> uni.Expr {
        shifted = self.ast.binary(">>", value, self.ast.integer(shift)) if shift else value;
        return self.ast.binary("&", shifted, self.ast.call("u8", [self.ast.integer((1 << width) - 1)]));
    }

    def assignment_value(nd: CNode) -> CValue {
        destination = self.place(nd.operands[0]);
        if "const" in qualifiers_of(destination.typ) { self.fail(nd, "Assignment to const object"); }
        if isinstance(unqualified(destination.typ), CArray) { self.fail(nd, "C arrays are not assignable"); }
        operation = nd.value[:-1] if nd.kind == "assignment" and nd.value != "=" else nd.value;
        if nd.value in ["++", "--"] { operation = "+" if nd.value == "++" else "-"; }
        value = self.expression(nd.operands[1]) if nd.kind == "assignment" else
            CValue(self.ast.call("i32", [self.ast.integer(1)]), CScalar(), True, 1);
        if operation == "=" {
            value = CValue(self.converted(value, destination.typ), destination.typ);
        }
        postfix = nd.kind == "postfix";
        qualifiers = qualifiers_of(destination.typ);
        atomic = "_Atomic" in qualifiers; volatile = "volatile" in qualifiers;
        if destination.unaligned_address is not None and (atomic or volatile) {
            self.fail(nd, "Qualified unaligned assignment requires combined memory operations");
        }
        selected: CAssignmentHelper | None = None;
        for helper in self.assignment_helpers {
            if helper.operation == operation and helper.postfix == postfix
                and helper.unaligned == (destination.unaligned_address is not None)
                and helper.atomic == atomic and helper.volatile == volatile
                and helper.bit_shift == destination.bit_shift and helper.bit_width == destination.bit_width
                and compatible(helper.target_type, destination.typ) and compatible(helper.value_type, value.typ) {
                selected = helper; break;
            }
        }
        if selected is None {
            # Validate before remembering a helper so diagnostics keep the C
            # assignment's location and invalid helper bodies are never emitted.
            assigned = value if operation == "=" else self.binary(operation, destination, value, nd);
            self.converted(assigned, destination.typ);
            selected = CAssignmentHelper(self.fresh("assign", "_c2jac_"), destination.typ, value.typ,
                operation, postfix, destination.unaligned_address is not None, atomic, volatile, destination.bit_shift, destination.bit_width);
            self.assignment_helpers.append(selected);
        }
        address = destination.bitfield_address or destination.unaligned_address or self.ast.call("addr_of", [destination.expr]);
        return CValue(self.ast.call(selected.name, [address, value.expr]), unqualified(destination.typ));
    }

    def effect(nd: CNode) -> list[uni.CodeBlockStmt] {
        children = nd.operands;
        if nd.kind == "omitted" { return []; }
        if nd.kind in ["parenthesized", "extension"] { return self.effect(children[0]); }
        if nd.kind == "comma" { return self.effect(children[0]) + self.effect(children[1]); }
        if nd.kind == "statement_expression" { return self.body(children[0]); }
        if nd.kind == "conditional" {
            condition = self.expression(children[0]);
            if self.is_void(condition.typ) { self.fail(nd, "Void conditional guard"); }
            return [self.ast.branch(self.ast.call("bool", [condition.expr]), self.effect(children[1]), self.effect(children[2]))];
        }
        value = self.expression(nd);
        return [self.ast.expression(value.expr)];
    }

    def conditional_type(yes: CValue, no: CValue, nd: CNode) -> CType {
        left = unqualified(yes.typ); right = unqualified(no.typ);
        if isinstance(left, CScalar) and isinstance(right, CScalar) {
            return common(self.scalar_type(yes.typ, nd), self.scalar_type(no.typ, nd));
        }
        left_null = yes.null_pointer_constant or (isinstance(left, CScalar)
            and left.category in ["integer", "bool"] and yes.constant and yes.integer_value == 0);
        right_null = no.null_pointer_constant or (isinstance(right, CScalar)
            and right.category in ["integer", "bool"] and no.constant and no.integer_value == 0);
        if isinstance(left, CPointer) and right_null { return yes.typ; }
        if isinstance(right, CPointer) and left_null { return no.typ; }
        if isinstance(left, CPointer) and isinstance(right, CPointer) {
            a = unqualified(left.pointee); b = unqualified(right.pointee);
            qualifiers = qualifiers_of(left.pointee) | qualifiers_of(right.pointee);
            pointee: CType;
            if compatible(a, b) { pointee = a; }
            elif (self.is_void(a) and not isinstance(b, CFunctionType))
                or (self.is_void(b) and not isinstance(a, CFunctionType)) {
                pointee = CScalar(category="void");
            } else {
                self.fail(nd, "Conditional pointer operands require compatible pointee types");
                return left;
            }
            if qualifiers { pointee = CQualified(pointee, tuple(sorted(qualifiers))); }
            return CPointer(pointee);
        }
        if isinstance(left, CRecord) and compatible(left, right) { return left; }
        self.fail(nd, "Conditional operands require compatible scalar, pointer, or record types");
        return left;
    }

    def fresh(name: str, prefix: str = "_c2jac_local_") -> str {
        self.serial += 1;
        return prefix + str(self.serial) + "_" + name;
    }

    def local_declaration(nd: CNode) -> list[uni.CodeBlockStmt] {
        children = nd.operands; spec = children[0]; storage = self.storage(spec);
        if "typedef" in storage {
            if any(s != "typedef" for s in storage) { self.fail(nd, "Invalid local typedef storage specifier"); }
            for item in children[1:] {
                if len(item.operands) != 1 { self.fail(item, "Typedef cannot have an initializer"); }
                decl = item.operands[0];
                typ = self.declared_type(spec, decl);
                self.types.declare_alias(self.name_of(decl), typ, decl);
            }
            return [];
        }
        if "static" in storage {
            if any(s not in ["static", "_Thread_local"] for s in storage) { self.fail(nd, "Invalid static local storage specifier"); }
        } elif any(s not in ["auto", "register"] for s in storage) {
            self.fail(nd, "Local extern declarations require linkage-aware lowering");
        }
        lines: list[uni.CodeBlockStmt] = [];
        if len(children) == 1 { self.declared_type(spec); }
        for item in children[1:] {
            parts = item.operands; decl = parts[0]; name = self.name_of(decl);
            inferred: CValue | None = None;
            if any(part.kind == "scalar" and part.value == "__auto_type" for part in spec.operands) {
                if len(nd.operands) != 2 or len(parts) != 2 or derived_operators(decl)
                    or any(part.kind not in ["scalar", "storage", "extension"] for part in spec.operands) {
                    self.fail(item, "__auto_type requires a plain initialized identifier");
                }
                # GNU inference evaluates the initializer before introducing
                # the new binding; array/function decay still applies.
                inferred = self.expression(parts[1]);
                typ = inferred.typ;
            } else { typ = self.variable(spec, decl); }
            if name in self.scopes[-1] { self.fail(decl, "Duplicate local declaration " + name); }
            self.types.declare_ordinary(name, decl);
            typ = self.types.complete_array(typ, parts[1] if len(parts) > 1 else None);
            (typ, alignment) = self.object_storage(typ);
            binding = CBinding(self.fresh(name, "_c2jac_static_" if "static" in storage else "_c2jac_local_"), typ, static_storage="static" in storage, alignment=alignment);
            self.scopes[-1][name] = binding;
            if "static" in storage {
                initializer: uni.Expr | None = None;
                if len(parts) > 1 {
                    initial = inferred or self.initial_value(parts[1], typ);
                    if not initial.constant { self.fail(item, "Static local initializer requires a constant expression"); }
                    initializer = self.converted(initial, typ);
                }
                self.storage_nodes.append(self.ast.global_var(binding.name, self.binding_type(binding), self.binding_initial(binding, initializer or self.zero(typ)),
                    thread_local="_Thread_local" in storage, internal=True));
                continue;
            }
            # Reading an uninitialized C scalar has no defined value. Initializing
            # its Jac storage does not change defined executions of this subset.
            value = self.converted(inferred or self.initial_value(parts[1], typ), typ) if len(parts) > 1 else self.zero(typ);
            volatile_init = "volatile" in qualifiers_of(typ) and len(parts) > 1;
            initialization = self.ast.expression(self.ast.invoke(self.ast.member(
                self.ast.call("addr_of", [self.binding_place(binding)]), "store_volatile"), [value])) if volatile_init else None;
            if self.control_graph is not None {
                self.control_graph.locals.append(self.ast.assignment(binding.name, self.binding_initial(binding, self.zero(typ)), self.binding_type(binding)));
                if initialization is not None { lines.append(initialization); }
                elif len(parts) > 1 { lines.append(self.ast.store(self.binding_place(binding), value)); }
            } elif initialization is not None {
                lines.append(self.ast.assignment(binding.name, self.binding_initial(binding, self.zero(typ)), self.binding_type(binding)));
                lines.append(initialization);
            } else { lines.append(self.ast.assignment(binding.name, self.binding_initial(binding, value), self.binding_type(binding))); }
        }
        return lines;
    }

    def body(nd: CNode) -> list[uni.CodeBlockStmt] {
        if nd.kind == "compound" {
            self.scopes.append({}); self.types.enter_scope(); stmts: list[uni.CodeBlockStmt] = [];
            try {
                for child in nd.operands {
                    self.ast.origin = child;
                    stmts.extend(self.local_declaration(child) if child.kind == "declaration" else self.statement(child));
                }
            } finally { self.scopes.pop(); self.types.leave_scope(); }
            return stmts;
        }
        return self.statement(nd);
    }

    def statement(nd: CNode) -> list[uni.CodeBlockStmt] {
        self.current = nd; self.ast.origin = nd; children = nd.operands; kind = nd.kind;
        if kind == "empty" { return []; }
        if kind == "compound" { return [self.ast.branch(self.ast.boolean(True), self.body(nd))]; }
        if kind == "expression" { return self.effect(children[0]); }
        if kind == "return" {
            if not children {
                if not self.is_void(self.return_type) { self.fail(nd, "Non-void return needs a value"); }
                return [self.ast.returned()];
            }
            returned = self.expression(children[0]);
            if self.is_void(self.return_type) {
                if not self.is_void(returned.typ) { self.fail(nd, "Void function cannot return a scalar value"); }
                return [self.ast.expression(returned.expr), self.ast.returned()];
            }
            return [self.ast.returned(self.converted(returned, self.return_type))];
        }
        if kind == "if" {
            condition = self.expression(children[0]);
            if self.is_void(condition.typ) { self.fail(nd, "Void condition"); }
            body = self.body(children[1]);
            alternative = self.body(children[2]) if len(children) == 3 else None;
            self.ast.origin = nd;
            return [self.ast.branch(self.ast.call("bool", [condition.expr]), body, alternative)];
        }
        if kind in ["while", "for", "do_while"] {
            self.scopes.append({}); self.types.enter_scope();
            try {
                initial: list[uni.CodeBlockStmt] = []; step: list[uni.CodeBlockStmt] = [];
                if kind == "for" {
                    initial = self.local_declaration(children[0]) if children[0].kind == "declaration" else self.effect(children[0]);
                    condition = CValue(self.ast.boolean(True), CScalar(category="bool")) if children[1].kind == "omitted" else self.expression(children[1]);
                    step = self.effect(children[2]); body_node = children[3];
                } elif kind == "while" { condition = self.expression(children[0]); body_node = children[1]; }
                else {
                    body_node = children[0]; condition = self.expression(children[1]);
                    step = [self.ast.branch(self.ast.unary("not", self.ast.call("bool", [condition.expr])), [self.ast.control("break")])];
                }
                if self.is_void(condition.typ) { self.fail(nd, "Void loop condition"); }
                self.continue_actions.append(step);
                try { body_stmts = self.body(body_node); }
                finally { self.continue_actions.pop(); }
                self.ast.origin = nd;
                guard = self.ast.boolean(True) if kind == "do_while" else self.ast.call("bool", [condition.expr]);
                return initial + [self.ast.loop(guard, body_stmts + step)];
            } finally { self.scopes.pop(); self.types.leave_scope(); }
        }
        if kind in ["break", "continue"] {
            if not self.continue_actions { self.fail(nd, kind + " outside a supported loop"); }
            # Each statement occurrence must own its own graph, including the
            # for-step/do-condition copied into a continue path.
            prefix = self.ast.clone_block(self.continue_actions[-1]) if kind == "continue" else [];
            return prefix + [self.ast.control(kind)];
        }
        self.fail(nd, "Statement '" + kind + "' has no source lowering yet");
        return [];
    }

    def needs_flow(nd: CNode) -> bool {
        return nd.kind in ["goto", "label", "switch"]
            or any(self.needs_flow(child) for child in nd.operands);
    }

    def flow_statement(nd: CNode, start_block: int, exit_target: int = -1,
        continue_target: int = -1, selection: CSwitchTargets | None = None) -> int {
        cfg = self.control_graph;
        assert cfg is not None;
        self.current = nd; self.ast.origin = nd;
        kind = nd.kind; children = nd.operands;
        if kind == "compound" {
            self.scopes.append({}); self.types.enter_scope();
            try {
                for child in children {
                    start_block = self.flow_statement(child, start_block, exit_target, continue_target, selection);
                }
            } finally { self.scopes.pop(); self.types.leave_scope(); }
            return start_block;
        }
        if kind == "declaration" {
            cfg.blocks[start_block].body.extend(self.local_declaration(nd));
            return start_block;
        }
        if kind == "label" {
            if nd.value in cfg.defined { self.fail(nd, "Duplicate label " + nd.value); }
            cfg.defined.add(nd.value); target = cfg.label(nd.value);
            cfg.jump(start_block, target);
            return self.flow_statement(children[0], target, exit_target, continue_target, selection);
        }
        if kind in ["goto", "break", "continue"] {
            target = cfg.label(nd.value) if kind == "goto" else
                (exit_target if kind == "break" else continue_target);
            if target < 0 { self.fail(nd, kind + " outside its enclosing control statement"); }
            cfg.jump(start_block, target);
            return cfg.block();
        }
        if kind == "return" {
            cfg.blocks[start_block].body.extend(self.statement(nd));
            return cfg.block();
        }
        if kind == "if" {
            condition = self.expression(children[0]);
            if self.is_void(condition.typ) { self.fail(nd, "Void condition"); }
            yes = cfg.block(); no = cfg.block(); end = cfg.block();
            cfg.branch(start_block, self.ast.call("bool", [condition.expr]), yes, no);
            cfg.jump(self.flow_statement(children[1], yes, exit_target, continue_target, selection), end);
            other = self.flow_statement(children[2], no, exit_target, continue_target, selection)
                if len(children) > 2 else no;
            cfg.jump(other, end);
            return end;
        }
        if kind in ["while", "for", "do_while"] {
            self.scopes.append({}); self.types.enter_scope();
            try {
                condition_block = cfg.block(); body_block = cfg.block();
                step_block = cfg.block(); end = cfg.block();
                body_node: CNode; condition_node: CNode;
                if kind == "for" {
                    cfg.blocks[start_block].body.extend(self.local_declaration(children[0])
                        if children[0].kind == "declaration" else self.effect(children[0]));
                    condition_node = children[1]; body_node = children[3];
                    cfg.blocks[step_block].body.extend(self.effect(children[2]));
                } elif kind == "while" { condition_node = children[0]; body_node = children[1]; }
                else { condition_node = children[1]; body_node = children[0]; }
                loop_guard: uni.Expr = self.ast.boolean(True);
                if condition_node.kind != "omitted" {
                    loop_value = self.expression(condition_node);
                    if self.is_void(loop_value.typ) { self.fail(condition_node, "Void loop condition"); }
                    loop_guard = self.ast.call("bool", [loop_value.expr]);
                }
                cfg.branch(condition_block, loop_guard, body_block, end);
                cfg.jump(start_block, body_block if kind == "do_while" else condition_block);
                cfg.jump(step_block, condition_block);
                tail = self.flow_statement(body_node, body_block, end, step_block, selection);
                cfg.jump(tail, step_block);
                return end;
            } finally { self.scopes.pop(); self.types.leave_scope(); }
        }
        if kind == "switch" {
            value = self.expression(children[0]);
            promoted = promote(self.scalar_type(value.typ, children[0], integer_only=True));
            name = self.fresh("switch");
            cfg.locals.append(self.ast.assignment(name, self.zero(promoted), self.ast.type_node(promoted)));
            cfg.blocks[start_block].body.append(self.ast.assignment(name, self.converted(value, promoted)));
            targets = CSwitchTargets(); body_block = cfg.block(); end = cfg.block();
            tail = self.flow_statement(children[1], body_block, end, continue_target, targets);
            cfg.jump(tail, end);
            dispatch = start_block;
            ranges: list[tuple[int, int]] = [];
            for (lower, upper, target) in targets.cases {
                # Case values are converted to the promoted controlling type.
                low = CInteger(lower, promoted).converted(promoted).value; high = CInteger(upper, promoted).converted(promoted).value;
                if low > high { self.fail(nd, "Switch case range wraps its controlling type"); }
                if any(low <= b and high >= a for (a, b) in ranges) { self.fail(nd, "Overlapping switch cases"); }
                ranges.append((low, high));
                left = self.ast.call(promoted.jac, [self.ast.integer(low)]);
                right = self.ast.call(promoted.jac, [self.ast.integer(high)]);
                case_guard = self.ast.binary("==", self.ast.name(name), left) if low == high else
                    self.ast.binary("and", self.ast.binary(">=", self.ast.name(name), left),
                        self.ast.binary("<=", self.ast.name(name), right));
                next_dispatch = cfg.block();
                cfg.branch(dispatch, case_guard, target, next_dispatch); dispatch = next_dispatch;
            }
            cfg.jump(dispatch, targets.default_target if targets.default_target >= 0 else end);
            return end;
        }
        if kind in ["case", "case_range", "default"] {
            if selection is None { self.fail(nd, "Case label outside switch"); }
            assert selection is not None;
            target = cfg.block(); cfg.jump(start_block, target);
            if kind == "default" {
                if selection.default_target >= 0 { self.fail(nd, "Duplicate default label"); }
                selection.default_target = target;
            } else {
                lower = self.types.integer_constant(children[0]);
                upper = self.types.integer_constant(children[1]) if kind == "case_range" else lower;
                if lower is None or upper is None { self.fail(nd, "Case label requires an integer constant expression"); }
                assert lower is not None and upper is not None;
                if lower.value > upper.value { self.fail(nd, "Empty switch case range"); }
                selection.cases.append((lower.value, upper.value, target));
            }
            return self.flow_statement(children[-1], target, exit_target, continue_target, selection);
        }
        cfg.blocks[start_block].body.extend(self.statement(nd));
        return start_block;
    }

    def function_node(nd: CNode) -> uni.Ability {
        parts = nd.operands; decl = parts[1]; fn = self.functions[self.name_of(decl)];
        self.current_function = fn.name;
        if fn.signature.variadic { self.fail(decl, "Variadic definitions require C calling-convention lowering"); }
        if any(lowering_attributes(attributes_of(declaration), handled={"gnu_inline"}) for declaration in fn.declarations) {
            self.fail(decl, "Function attributes require ABI-aware source lowering");
        }
        parameters = self.operators(decl)[0].operands[1:];
        self.scopes = [{}];
        self.types.enter_scope(id(self.operators(decl)[0]));
        self.return_type = fn.signature.returns;
        params: list[uni.ParamVar] = [];
        for i in range(len(fn.signature.parameters)) {
            parameter = parameters[i]; name = self.name_of(parameter.operands[1]);
            if not name { self.fail(parameter, "Function definition requires named parameters"); }
            if name in self.scopes[0] { self.fail(parameter, "Duplicate parameter " + name); }
            binding = CBinding(self.fresh(name), fn.signature.parameters[i]);
            self.scopes[0][name] = binding; params.append(self.ast.parameter(binding.name, self.ast.type_node(binding.typ)));
        }
        # The function's outermost block shares the parameter scope in C.
        lines: list[uni.CodeBlockStmt] = [];
        uses_dispatch = self.needs_flow(parts[2]);
        if uses_dispatch {
            cfg = CFlowGraph(self.ast, self.fresh("block")); self.control_graph = cfg;
            try {
                start_block = cfg.block(); tail = start_block;
                for child in parts[2].operands { tail = self.flow_statement(child, tail); }
                lines = cfg.emit(start_block);
            } finally { self.control_graph = None; }
        } else {
            for child in parts[2].operands {
                lines.extend(self.local_declaration(child) if child.kind == "declaration" else self.statement(child));
            }
        }
        if not self.is_void(fn.signature.returns) and (uses_dispatch or not parts[2].operands or parts[2].operands[-1].kind != "return") {
            lines.append(self.ast.returned(self.zero(fn.signature.returns)));
        }
        self.ast.origin = nd;
        return self.ast.function("c_" + fn.name, params, self.ast.type_node(fn.signature.returns), lines, internal=fn.internal or fn.inline_only);
    }

    def global_nodes(nd: CNode) -> list[uni.ElementStmt] {
        parts = nd.operands; spec = parts[0]; lines: list[uni.ElementStmt] = [];
        if "typedef" in self.storage(spec) {
            # Header aliases have already been resolved to their semantic types.
            # Only source-owned aliases are part of the emitted source interface.
            if not self.source_owned(nd) { return lines; }
            for item in parts[1:] {
                name = self.name_of(item.operands[0]);
                if name not in self.emitted_aliases {
                    self.emitted_aliases.add(name);
                    lines.append(self.ast.alias("c_" + name, self.ast.type_node(self.types.aliases[name])));
                }
            }
            return lines;
        }
        self.scopes = [];
        for item in parts[1:] {
            children = item.operands; decl = children[0]; name = self.name_of(decl);
            if self.operators(decl) and self.operators(decl)[0].kind == "function" { continue; }
            binding = self.globals[name]; typ = binding.typ;
            if not binding.defined or name in self.emitted_globals { continue; }
            if self.selected_paths and not self.source_owned(nd) and not binding.referenced { continue; }
            self.emitted_globals.add(name);
            source_initializer = binding.initializer;
            if source_initializer is not None {
                value = self.initial_value(source_initializer, typ);
                if not value.constant { self.fail(item, "Global initializer must be a supported constant expression"); }
                initializer = self.converted(value, typ);
            } else { initializer = self.zero(typ); }
            lines.append(self.ast.global_var(binding.name, self.binding_type(binding), self.binding_initial(binding, initializer), thread_local=binding.thread_local, internal=binding.internal));
        }
        return lines;
    }

    def helper_nodes -> list[uni.ElementStmt] {
        nodes: list[uni.ElementStmt] = [];
        for helper in self.union_initializer_helpers {
            params = [self.ast.parameter("value", self.ast.type_node(helper.field.typ))];
            storage = self.ast.invoke(self.ast.union_storage_type(helper.record), []);
            initialized = self.ast.invoke(self.ast.type_node(helper.record), [storage]);
            body: list[uni.CodeBlockStmt] = [
                self.ast.assignment("result", initialized, self.ast.type_node(helper.record)),
                self.ast.store(self.ast.field_access(self.ast.name("result"), helper.record, helper.field), self.ast.name("value")),
                self.ast.returned(self.ast.name("result"))
            ];
            nodes.append(self.ast.function(helper.name, params, self.ast.type_node(helper.record), body, internal=True));
        }
        # Helpers preserve expression sequencing without injecting statements
        # outside short-circuit operands, loop conditions, or call arguments.
        for helper in self.assignment_helpers {
            params = [self.ast.parameter("place", self.ast.type_node(CPointer(helper.target_type))),
                self.ast.parameter("value", self.ast.type_node(helper.value_type))];
            body: list[uni.CodeBlockStmt] = [];
            value = CValue(self.ast.name("value"), helper.value_type);
            if helper.atomic and helper.operation != "=" {
                loaded: uni.Expr = self.ast.invoke(self.ast.member(self.ast.name("place"), "atomic_load"),
                    [self.ast.string("seq_cst"), self.ast.boolean(helper.volatile)]);
                body.append(self.ast.assignment("previous", loaded, self.ast.type_node(helper.target_type)));
                body.append(self.ast.assignment("assigned", self.zero(helper.target_type), self.ast.type_node(helper.target_type)));
                assert self.current is not None;
                changed = self.binary(helper.operation, CValue(self.ast.name("previous"), unqualified(helper.target_type)), value, self.current);
                attempt: list[uni.CodeBlockStmt] = [
                    self.ast.assignment("assigned", self.converted(changed, helper.target_type)),
                    self.ast.assignment("expected", self.ast.name("previous"), self.ast.type_node(helper.target_type))];
                success = self.ast.invoke(self.ast.member(self.ast.name("place"), "atomic_compare_exchange"), [
                    self.ast.call("addr_of", [self.ast.name("expected")]), self.ast.name("assigned"),
                    self.ast.string("seq_cst"), self.ast.string("seq_cst"), self.ast.boolean(False), self.ast.boolean(helper.volatile)]);
                attempt.append(self.ast.branch(success, [self.ast.control("break")]));
                attempt.append(self.ast.assignment("previous", self.ast.name("expected")));
                body.append(self.ast.loop(self.ast.boolean(True), attempt));
                body.append(self.ast.returned(self.ast.name("previous" if helper.postfix else "assigned")));
                nodes.append(self.ast.function(helper.name, params, self.ast.type_node(helper.target_type), body, internal=True));
                continue;
            }
            if helper.operation != "=" or helper.bit_width {
                loaded = self.ast.invoke(self.ast.member(self.ast.name("place"), "load_unaligned"), []) if helper.unaligned
                    else self.ast.index(self.ast.name("place"), self.ast.integer(0));
                if helper.volatile { loaded = self.ast.invoke(self.ast.member(self.ast.name("place"), "load_volatile"), []); }
                if helper.bit_width {
                    body.append(self.ast.assignment("unit", loaded, self.ast.typ("u8")));
                    loaded = self.bit_value(self.ast.name("unit"), helper.bit_shift, helper.bit_width);
                }
                if helper.operation != "=" {
                    body.append(self.ast.assignment("previous", loaded, self.ast.type_node(helper.target_type)));
                    assert self.current is not None;
                    value = self.binary(helper.operation, CValue(self.ast.name("previous"), helper.target_type), value, self.current);
                }
            }
            body.append(self.ast.assignment("assigned", self.converted(value, helper.target_type), self.ast.type_node(helper.target_type)));
            if helper.bit_width {
                body.append(self.ast.assignment("assigned", self.bit_value(self.ast.name("assigned"), 0, helper.bit_width)));
                retained = self.ast.binary("&", self.ast.name("unit"),
                    self.ast.call("u8", [self.ast.integer(255 ^ (((1 << helper.bit_width) - 1) << helper.bit_shift))]));
                merged = self.ast.binary("|", retained,
                    self.ast.binary("<<", self.ast.name("assigned"), self.ast.integer(helper.bit_shift)));
                if helper.volatile {
                    body.append(self.ast.expression(self.ast.invoke(self.ast.member(self.ast.name("place"), "store_volatile"), [merged])));
                } else { body.append(self.ast.store(self.ast.index(self.ast.name("place"), self.ast.integer(0)), merged)); }
                body.append(self.ast.returned(self.ast.name("previous" if helper.postfix else "assigned")));
                nodes.append(self.ast.function(helper.name, params, self.ast.type_node(helper.target_type), body, internal=True));
                continue;
            }
            if helper.atomic {
                body.append(self.ast.expression(self.ast.invoke(self.ast.member(self.ast.name("place"), "atomic_store"),
                    [self.ast.name("assigned"), self.ast.string("seq_cst"), self.ast.boolean(helper.volatile)])));
            } elif helper.volatile {
                body.append(self.ast.expression(self.ast.invoke(self.ast.member(self.ast.name("place"), "store_volatile"),
                    [self.ast.name("assigned")])));
            } elif helper.unaligned {
                body.append(self.ast.expression(self.ast.invoke(self.ast.member(self.ast.name("place"), "store_unaligned"),
                    [self.ast.name("assigned")])));
            } else {
                body.append(self.ast.store(self.ast.index(self.ast.name("place"), self.ast.integer(0)), self.ast.name("assigned")));
            }
            body.append(self.ast.returned(self.ast.name("previous" if helper.postfix else "assigned")));
            nodes.append(self.ast.function(helper.name, params, self.ast.type_node(helper.target_type), body, internal=True));
        }
        for name in sorted(self.helpers) {
            typ = self.helpers[name].jac;
            params = [self.ast.parameter("a", typ), self.ast.parameter("b", typ)];
            body: list[uni.CodeBlockStmt] = [];
            if "_rem_" in name {
                quotient = self.ast.call("_c2jac_div_" + typ, [self.ast.name("a"), self.ast.name("b")]);
                product = self.ast.binary("*", quotient, self.ast.name("b"));
                body.append(self.ast.returned(self.ast.binary("-", self.ast.name("a"), product)));
            } else {
                body.append(self.ast.assignment("q", self.ast.binary("//", self.ast.name("a"), self.ast.name("b")), typ));
                negative_a = self.ast.binary("<", self.ast.name("a"), self.ast.integer(0));
                negative_b = self.ast.binary("<", self.ast.name("b"), self.ast.integer(0));
                opposite = self.ast.binary("!=", negative_a, negative_b);
                remainder = self.ast.binary("%", self.ast.name("a"), self.ast.name("b"));
                nonzero = self.ast.binary("!=", remainder, self.ast.integer(0));
                correction = self.ast.binary("+", self.ast.name("q"), self.ast.call(typ, [self.ast.integer(1)]));
                body.append(self.ast.branch(self.ast.binary("and", opposite, nonzero), [self.ast.assignment("q", correction)]));
                body.append(self.ast.returned(self.ast.name("q")));
            }
            nodes.append(self.ast.function(name, params, typ, body, internal=True));
        }
        return nodes;
    }

    def lower(parsed: CParseResult) -> CLowerResult {
        self.result = CLowerResult();
        eof = parsed.preprocessing.eof;
        self.input_path = eof.source.file_path if eof is not None else parsed.tree.loc.mod_path;
        self.selected_paths = {os.path.realpath(path) for path in self.config.source_paths};
        self.ctx.errors_had = self.result.errors_had;
        self.ctx.warnings_had = self.result.warnings_had;
        self.types = CTypeResolver(config=self.config, expression_type=self.expression_type);
        self.emitted_aliases = set(); self.emitted_globals = set(); self.globals = {}; self.functions = {}; self.scopes = [];
        self.helpers = {}; self.assignment_helpers = []; self.union_initializer_helpers = []; self.storage_nodes = []; self.serial = 0; self.continue_actions = [];
        self.ast.required_records = {}; self.ast.required_layouts = set();
        self.current_function = ""; self.function_strings = {};
        for diagnostic in parsed.diagnostics {
            alert = frontend_alert(diagnostic, CLowerPass);
            if diagnostic.severity == "error" { self.result.errors_had.append(alert); }
            else { self.result.warnings_had.append(alert); }
        }
        if self.config.abi not in ["lp64", "llp64", "ilp32"] {
            self.report_error(parsed.tree, "Unknown ABI: " + self.config.abi); return self.result;
        }
        if self.config.enum_model not in ["gnu", "int32"] {
            self.report_error(parsed.tree, "Unknown enum model: " + self.config.enum_model); return self.result;
        }
        if not self.result.ok { return self.result; }
        declarations = [n for n in parsed.tree.operands if n.kind != "preprocessing_unit"];
        if self.selected_paths {
            available = {os.path.realpath(nd.loc.mod_path) for nd in declarations};
            for path in sorted(self.selected_paths - available) {
                self.report_error(parsed.tree, "Selected source has no active declarations in this translation unit: " + path);
            }
            if not self.result.ok { return self.result; }
        }
        for nd in declarations {
            self.current = nd; self.ast.origin = nd;
            try { self.collect(nd); }
            except ValueError as error { self.report_error(self.current or nd, str(error)); }
        }
        if not self.result.ok { return self.result; }
        if self.selected_paths {
            # An included source's externally linked dependencies are imports.
            # Keep internal definitions in the closure because they cannot be
            # resolved by the linker. Context-only constructors remain owned by
            # the translation unit that supplies those external definitions.
            for function in self.functions.values() {
                function.context_external = function.definition is not None and not function.internal
                    and not function.inline_only and not self.source_owned(function.definition);
            }
            for (name, binding) in self.globals.items() {
                binding.context_external = binding.defined and not binding.internal
                    and not any(self.source_owned(definition) for definition in binding.definitions);
                if binding.context_external { binding.name = name; }
            }
        }
        body: list[uni.ElementStmt] = [];
        # Definitions with external linkage and source-owned functions are roots.
        # Header static functions are emitted when a retained definition or
        # initializer refers to them. Function addresses count as references too.
        emitted_functions: set[str] = set();
        pending_functions: list[CNode] = [];
        pending_globals: list[CNode] = [];
        for nd in declarations {
            if nd.kind == "function_definition" {
                function = self.functions[self.name_of(nd.operands[1])];
                if function.context_external { continue; }
                if (not self.selected_paths and (not function.internal and not function.inline_only or function.requires_retention))
                    or self.source_owned(nd) {
                    function.referenced = True;
                }
                pending_functions.append(nd);
                continue;
            }
            pending_globals.append(nd);
            self.current = nd; self.ast.origin = nd;
            try { body.extend(self.global_nodes(nd)); }
            except ValueError as error { self.report_error(self.current or nd, str(error)); }
            finally { self.types.scopes = self.types.scopes[:1]; }
        }
        while True {
            progressed = False;
            # Function bodies can discover globals whose initializers in turn
            # reference functions. Retain their complete shared dependency closure.
            for nd in pending_globals {
                before = len(self.emitted_globals);
                self.current = nd; self.ast.origin = nd;
                try { body.extend(self.global_nodes(nd)); }
                except ValueError as error { self.report_error(self.current or nd, str(error)); }
                finally { self.types.scopes = self.types.scopes[:1]; }
                progressed = progressed or len(self.emitted_globals) > before;
            }
            for nd in pending_functions {
                name = self.name_of(nd.operands[1]);
                if name in emitted_functions or not self.functions[name].referenced { continue; }
                emitted_functions.add(name); progressed = True;
                self.current = nd; self.ast.origin = nd;
                try { body.append(self.function_node(nd)); }
                except ValueError as error { self.report_error(self.current or nd, str(error)); }
                finally { self.types.scopes = self.types.scopes[:1]; self.current_function = ""; }
            }
            if not progressed { break; }
        }
        foreign_nodes: list[uni.UniNode] = [];
        for binding in self.globals.values() {
            if binding.defined or not binding.referenced { continue; }
            self.current = binding.declarations[0]; self.ast.origin = self.current;
            try { foreign_nodes.append(self.ast.global_var(binding.name, self.binding_type(binding), None, thread_local=binding.thread_local)); }
            except ValueError as error { self.report_error(self.current, str(error)); }
        }
        foreign_signatures: dict[str, CFunctionType] = {};
        for function in self.functions.values() {
            if not function.referenced { continue; }
            if function.definition is not None and not function.context_external and not (function.inline_only and function.address_referenced) { continue; }
            self.current = parsed.tree;
            try {
                if not function.signature.prototype {
                    self.fail(parsed.tree, "External function needs a prototype: " + function.name);
                }
                if any(lowering_attributes([attribute for attribute in attributes_of(declaration)
                    if attribute.kind != "asm_label" or not function.external_name], handled={"gnu_inline"})
                    for declaration in function.declarations) {
                    self.fail(parsed.tree, "External function attributes require ABI-aware lowering: " + function.name);
                }
                symbol_name = function.external_name or function.name;
                if symbol_name in foreign_signatures {
                    if not compatible(foreign_signatures[symbol_name], function.signature) {
                        self.fail(parsed.tree, "Conflicting foreign signatures for symbol " + symbol_name);
                    }
                    continue;
                }
                foreign_signatures[symbol_name] = function.signature;
                params = [self.ast.parameter("arg" + str(i), self.ast.type_node(typ))
                    for (i, typ) in enumerate(function.signature.parameters)];
                foreign_nodes.append(self.ast.function(symbol_name, params,
                    self.ast.type_node(function.signature.returns), None,
                    variadic=function.signature.variadic));
            } except ValueError as error { self.report_error(self.current, str(error)); }
        }
        helpers = self.helper_nodes() if self.result.ok else [];
        # Building type nodes records nominal dependencies. Expand the closure
        # after foreign declarations, which can introduce additional pointees.
        # Resolve all C declarations above, but do not demand storage for unused
        # header records merely because an included header declared them.
        for record in self.types.records {
            if record.definition is not None and self.source_owned(record.definition) {
                self.ast.required_records[record.identity] = record;
                self.ast.required_layouts.add(record.identity);
            }
        }
        record_nodes: dict[int, uni.ElementStmt] = {};
        emitted_records: dict[int, bool] = {};
        while True {
            # Pointer-only dependencies need nominal declarations. A later
            # by-value field can upgrade that declaration to a complete body.
            records = [record for (identity, record) in self.ast.required_records.items()
                if identity not in emitted_records or (identity in self.ast.required_layouts and not emitted_records[identity])];
            if not records { break; }
            for record in records {
                emitted_records[record.identity] = record.identity in self.ast.required_layouts;
                self.current = record.definition or parsed.tree;
                try { record_nodes[record.identity] = self.ast.record(record); }
                except ValueError as error { self.report_error(self.current, str(error)); }
            }
        }
        imports: list[uni.ElementStmt] = [self.ast.foreign(foreign_nodes)] if foreign_nodes else [];
        if self.result.ok {
            self.ast.origin = parsed.tree;
            self.result.module = self.ast.module(list(record_nodes.values()) + imports + self.storage_nodes + helpers + body);
            self.result.origins = dict(self.ast.origins);
        }
        return self.result;
    }
}

"""Lower C syntax to a standard Jac Module without printing or executing it."""
def lower_c(parsed: CParseResult, config: CEmitConfig | None = None) -> CLowerResult {
    eof = parsed.preprocessing.eof;
    input_path = eof.source.file_path if eof is not None else parsed.tree.loc.mod_path;
    source = uni.Source("", input_path + ".jac");
    context = CompileContext(current_node=parsed.tree, from_pass=CLowerPass, pass_name="CLowerPass");
    return CLowerPass(config=config or CEmitConfig(), ast=CJacAst(source, parsed.tree), ctx=context).lower(parsed);
}
