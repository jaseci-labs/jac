"""Resolve C declaration syntax without choosing a Jac runtime representation."""
import from .constants { CIntegerEvaluator, CInteger }
import from .declarators { declarator_name, derived_operators }
import from .semantics {
    CType, CScalar, CPointer, CArray, CFunctionType, CRecord, CEnum,
    CField, CQualified, CAttributed, COpaque, CDeferred, CEmitConfig,
    unqualified, attributes_of, qualifiers_of, compatible, string_bytes
}
import from jaclang.compiler.frontend.unitree_c { CNode }

obj CDeclarationScope {
    has tags: dict[str, CRecord | CEnum] = {},
        aliases: dict[str, CType] = {},
        constants: dict[str, CInteger | None] = {};
}

obj CTypeResolver {
    has config: CEmitConfig = CEmitConfig(),
        scopes: list[CDeclarationScope] = [CDeclarationScope()],
        spec_cache: dict[int, CType] = {},
        parameter_scopes: dict[int, CDeclarationScope] = {},
        serial: int = 0,
        records: list[CRecord] = [],
        expression_type: Callable[[CNode], CType] | None = None,
        current: CNode | None = None;

    has aliases: dict[str, CType] { getter { return self.scopes[-1].aliases; } }

    def postinit {
        self.aliases["__builtin_va_list"] = COpaque("__builtin_va_list");
    }

    def fail(nd: CNode, message: str) {
        self.current = nd;
        raise ValueError(message);
    }

    def enter_scope(parameter: int | None = None) {
        saved = self.parameter_scopes.get(parameter) if parameter is not None else None;
        self.scopes.append(CDeclarationScope(dict(saved.tags), dict(saved.aliases), dict(saved.constants))
            if saved is not None else CDeclarationScope());
    }

    def leave_scope -> CDeclarationScope { return self.scopes.pop(); }

    def constant(name: str) -> CInteger | None {
        for scope in reversed(self.scopes) {
            if name in scope.aliases { return None; }
            if name in scope.constants { return scope.constants[name]; }
        }
        return None;
    }

    def declare_ordinary(name: str, nd: CNode) {
        if not name { return; }
        if name in self.aliases { self.fail(nd, "Ordinary identifier conflicts with typedef " + name); }
        if self.scopes[-1].constants.get(name) is not None {
            self.fail(nd, "Ordinary identifier conflicts with enumerator " + name);
        }
        self.scopes[-1].constants[name] = None;
    }

    def lookup_alias(name: str) -> CType | None {
        for scope in reversed(self.scopes) {
            if name in scope.aliases { return scope.aliases[name]; }
            if name in scope.constants { return None; }
        }
        return None;
    }

    def declare_alias(name: str, typ: CType, nd: CNode) {
        previous = self.aliases.get(name);
        if previous is not None {
            if not compatible(previous, typ) { self.fail(nd, "Conflicting typedef " + name); }
            return;
        }
        if name in self.scopes[-1].constants { self.fail(nd, "Typedef conflicts with ordinary identifier " + name); }
        self.aliases[name] = typ;
    }

    def qualifier(spelling: str) -> str {
        return {"__const": "const", "__const__": "const",
            "__volatile": "volatile", "__volatile__": "volatile",
            "__restrict": "restrict", "__restrict__": "restrict"}.get(spelling, spelling);
    }

    def specifiers(spec: CNode, standalone: bool = False) -> CType {
        self.current = spec;
        cached = self.spec_cache.get(id(spec));
        if cached is not None { return cached; }
        words: list[str] = []; qualifiers: list[str] = [];
        attributes: list[CNode] = []; base: CType | None = None;
        for part in spec.operands {
            if part.kind == "scalar" { words.append(part.value); }
            elif part.kind == "qualifier" { qualifiers.append(self.qualifier(part.value)); }
            elif part.kind in ["storage", "extension"] { continue; }
            elif part.kind in ["attribute", "alignment", "asm_label"] { attributes.append(part); }
            else {
                if base is not None { self.fail(part, "Multiple base types in C declaration"); }
                if part.kind == "typedef_name" {
                    base = self.lookup_alias(part.value);
                    if base is None { self.fail(part, "Unknown typedef " + part.value); }
                } elif part.kind.startswith("struct_") or part.kind.startswith("union_") or part.kind.startswith("enum_") {
                    base = self.record(part, local=standalone);
                } elif part.kind in ["atomic", "typeof"] {
                    operand = part.operands[0];
                    if operand.kind == "type_name" {
                        base = self.resolve(operand.operands[0], operand.operands[1]);
                    } elif self.expression_type is not None {
                        base = self.expression_type(operand);
                    } else { base = CDeferred(operand); }
                    if part.kind == "atomic" { base = CQualified(base, ("_Atomic",)); }
                } else { self.fail(part, "Unsupported C type specifier " + part.kind); }
            }
        }
        if base is not None and words { self.fail(spec, "Base type cannot be combined with scalar specifiers"); }
        if base is None { base = self.scalar_words(spec, words); }
        if qualifiers { base = CQualified(base, tuple(sorted(set(qualifiers)))); }
        if attributes { base = CAttributed(base, attributes); }
        self.spec_cache[id(spec)] = base;
        return base;
    }

    def scalar_words(spec: CNode, words: list[str]) -> CType {
        if words == ["void"] { return CScalar(category="void"); }
        if words == ["_Bool"] { return CScalar(8, False, 0, "bool"); }
        if words == ["__auto_type"] { return CDeferred(spec); }
        real = [word for word in words if word not in ["_Complex", "_Imaginary"]];
        floating = {"float": (32, 1), "double": (64, 2), "long double": (0, 3),
            "_Float16": (16, 1), "_Float32": (32, 1), "_Float64": (64, 2),
            "_Float128": (128, 3), "_Float32x": (64, 2), "_Float64x": (0, 3),
            "_Float128x": (0, 4)};
        spelling = "long double" if sorted(real) == ["double", "long"] else " ".join(real);
        if spelling in floating {
            if len(words) - len(real) > 1 { self.fail(spec, "Conflicting complex type specifiers"); }
            (width, rank) = floating[spelling];
            category = "floating" if len(real) == len(words) else ("complex" if "_Complex" in words else "imaginary");
            return CScalar(width, True, rank, category);
        }
        allowed = ["char", "short", "int", "long", "signed", "unsigned", "__int128"];
        if not words or any(word not in allowed for word in words) {
            self.fail(spec, "Invalid or unsupported C scalar specifiers: " + " ".join(words));
        }
        for word in allowed {
            if words.count(word) > (2 if word == "long" else 1) { self.fail(spec, "Repeated C type specifier " + word); }
        }
        if "signed" in words and "unsigned" in words { self.fail(spec, "Conflicting C signedness specifiers"); }
        if "__int128" in words {
            if any(word in words for word in ["char", "short", "int", "long"]) { self.fail(spec, "Invalid __int128 type specifiers"); }
            return CScalar(128, "unsigned" not in words, 6);
        }
        if "char" in words {
            if any(word in words for word in ["short", "int", "long"]) { self.fail(spec, "Invalid char type specifiers"); }
            return CScalar(8, "unsigned" not in words and ("signed" in words or self.config.char_signed), 1);
        }
        if "short" in words {
            if "long" in words { self.fail(spec, "Conflicting short and long specifiers"); }
            return CScalar(16, "unsigned" not in words, 2);
        }
        longs = words.count("long");
        width = 64 if longs == 2 or (longs == 1 and self.config.abi == "lp64") else 32;
        return CScalar(width, "unsigned" not in words, 3 + longs);
    }

    def constant_type(nd: CNode) -> CType {
        if nd.kind != "type_name" { self.fail(nd, "Expected a C type name in constant expression"); }
        return self.resolve(nd.operands[0], nd.operands[1]);
    }

    def complete_array(typ: CType, initializer: CNode | None) -> CType {
        if initializer is None { return typ; }
        if isinstance(typ, CQualified) { return CQualified(self.complete_array(typ.base, initializer), typ.qualifiers); }
        if isinstance(typ, CAttributed) { return CAttributed(self.complete_array(typ.base, initializer), typ.attributes); }
        if isinstance(typ, CArray) and typ.length is None and typ.bound is None and not typ.variable
            and initializer.kind == "string" {
            element = unqualified(typ.element);
            if isinstance(element, CScalar) and element.category == "integer" and element.width == 8 and element.rank == 1 {
                return CArray(typ.element, len(string_bytes(initializer)) + 1);
            }
        }
        if isinstance(typ, CArray) and typ.length is None and typ.bound is None and not typ.variable
            and initializer.kind == "initializer_list" {
            # Infer only the outer bound here. Nested storage must be explicitly
            # initialized; scalar brace elision needs subobject traversal first.
            cursor = 0; length = 0;
            for item in initializer.operands {
                source = item;
                if item.kind == "designated_initializer" {
                    if len(item.operands) != 2 or item.operands[0].kind != "index_designator" {
                        raise ValueError("Array bound inference requires a direct index designator");
                    }
                    bound = self.constant_bound(item.operands[0].operands[0]);
                    if bound is None or bound < 0 { raise ValueError("Array designator requires a nonnegative integer constant"); }
                    cursor = bound; source = item.operands[1];
                }
                element = unqualified(typ.element);
                if isinstance(element, CArray) and source.kind not in ["initializer_list", "string"] {
                    raise ValueError("Array bound inference requires explicit nested initializers");
                }
                if isinstance(element, CRecord) and source.kind != "initializer_list" {
                    raise ValueError("Struct array bound inference needs expression type or subobject traversal");
                }
                cursor += 1; length = max(length, cursor);
            }
            if not length { raise ValueError("Empty initializer cannot infer an array bound"); }
            return CArray(typ.element, length);
        }
        return typ;
    }

    def storage_size(typ: CType) -> int | None {
        if attributes_of(typ) or ("_Atomic" in qualifiers_of(typ) and not self.config.scalar_atomic_storage(typ)) { return None; }
        base = unqualified(typ);
        if isinstance(base, CEnum) and not base.complete { return None; }
        if isinstance(base, CScalar) {
            if base.category in ["integer", "bool"] or (base.category == "floating" and base.width in [32, 64]) {
                return base.width // 8;
            }
        } elif isinstance(base, CPointer) { return self.config.size_type().width // 8; }
        elif isinstance(base, CArray) {
            element_size = self.storage_size(base.element);
            if base.length is not None and not base.variable and element_size is not None {
                return base.length * element_size;
            }
        }
        return None;
    }

    def integer_constant(nd: CNode) -> CInteger | None {
        return CIntegerEvaluator(self.config, resolve_type=self.constant_type,
            storage_size=self.storage_size, resolve_name=self.constant).evaluate(nd);
    }

    def constant_bound(nd: CNode) -> int | None {
        constant = self.integer_constant(nd);
        return constant.value if constant is not None else None;
    }

    def resolve(spec: CNode, declarator: CNode) -> CType {
        typ = self.specifiers(spec); attributes: list[CNode] = [];
        for operator in reversed(derived_operators(declarator)) {
            self.current = operator;
            if operator.kind == "pointer" {
                typ = CPointer(typ);
                qualifiers = tuple(sorted(set(self.qualifier(q.value) for q in operator.operands)));
                if qualifiers { typ = CQualified(typ, qualifiers); }
            } elif operator.kind == "array" {
                bound: CNode | None = None; quals: list[str] = []; variable = False;
                for item in operator.operands[1:] {
                    if item.kind == "array_qualifier" { quals.append(item.value); }
                    elif item.kind == "vla_star" { variable = True; }
                    else { bound = item; }
                }
                length = self.constant_bound(bound) if bound is not None else None;
                if length is not None and length < 0 { self.fail(operator, "Array length cannot be negative"); }
                element = unqualified(typ);
                if isinstance(element, CFunctionType) or (isinstance(element, CScalar) and element.category == "void") {
                    self.fail(operator, "Array element must be an object type");
                }
                typ = CArray(typ, length, bound, variable, tuple(quals));
            } elif operator.kind == "function" {
                result = unqualified(typ);
                if isinstance(result, (CArray, CFunctionType)) { self.fail(operator, "Function cannot return an array or function type"); }
                parameters: list[CType] = []; variadic = False;
                declarations = operator.operands[1:];
                self.enter_scope();
                try {
                    for parameter in declarations {
                        if parameter.kind == "variadic" { variadic = True; continue; }
                        children = parameter.operands;
                        declared = self.resolve(children[0], children[1]);
                        adjusted = unqualified(declared);
                        if isinstance(adjusted, CScalar) and adjusted.category == "void" {
                            if len(declarations) == 1 and not declarator_name(children[1]) { break; }
                            self.fail(parameter, "void is only valid as an unnamed empty parameter list");
                        }
                        if isinstance(adjusted, CArray) {
                            declared = CPointer(adjusted.element);
                            parameter_quals = tuple(q for q in adjusted.parameter_qualifiers if q != "static");
                            if parameter_quals { declared = CQualified(declared, parameter_quals); }
                        } elif isinstance(adjusted, CFunctionType) { declared = CPointer(adjusted); }
                        self.declare_ordinary(declarator_name(children[1]), parameter);
                        parameters.append(declared);
                    }
                } finally { self.parameter_scopes[id(operator)] = self.leave_scope(); }
                typ = CFunctionType(typ, parameters, variadic, bool(declarations));
            } elif operator.kind in ["attribute", "asm_label"] { attributes.append(operator); }
            else { self.fail(operator, "Unsupported derived C type " + operator.kind); }
        }
        return CAttributed(typ, attributes) if attributes else typ;

    }

    def record(nd: CNode, local: bool = False) -> CType {
        kind = nd.kind.split("_")[0]; definition = nd.kind.endswith("_definition");
        tag: CRecord | CEnum | None = None;
        if nd.value {
            scopes = [self.scopes[-1]] if definition or local else list(reversed(self.scopes));
            for scope in scopes {
                tag = scope.tags.get(nd.value);
                if tag is not None { break; }
            }
        }
        if tag is None {
            self.serial += 1;
            tag = CEnum(name=nd.value, identity=self.serial) if kind == "enum"
                else CRecord(nd.value, self.serial, kind);
            if isinstance(tag, CRecord) { self.records.append(tag); }
            if nd.value { self.scopes[-1].tags[nd.value] = tag; }
        }
        actual_kind = "enum" if isinstance(tag, CEnum) else tag.kind;
        if actual_kind != kind { self.fail(nd, "Conflicting C tag kind for " + nd.value); }
        if not definition { return tag; }
        if tag.definition is not None { self.fail(nd, "Duplicate C tag definition " + nd.value); }
        tag.definition = nd;
        if isinstance(tag, CEnum) {
            next_value = 0;
            values: list[int] = [];
            for member in nd.operands {
                if member.kind != "enumerator" { self.fail(member, "Enum attributes require target enum-layout lowering"); }
                self.current = member;
                if member.value in self.scopes[-1].constants or member.value in self.aliases { self.fail(member, "Duplicate ordinary identifier " + member.value); }
                value = self.integer_constant(member.operands[0]) if member.operands else CInteger(next_value, CScalar());
                if value is None { self.fail(member, "Enumerator requires a resolved integer constant expression"); continue; }
                constant_type = CScalar();
                if not (-(1 << 31) <= value.value < (1 << 31)) {
                    if self.config.enum_model != "gnu" or not (0 <= value.value < (1 << 32)) {
                        self.fail(member, "Extended enumerator range exceeds the configured enum model");
                    }
                    if member.operands and value.typ.width > 32 {
                        self.fail(member, "Wide enumerator expressions require target-specific constant typing");
                    }
                    constant_type = CScalar(32, False, 3);
                }
                self.scopes[-1].constants[member.value] = CInteger(value.value, constant_type);
                values.append(value.value);
                next_value = value.value + 1;
            }
            representation = self.config.enum_type(values);
            tag.width = representation.width; tag.signed = representation.signed; tag.rank = representation.rank;
            tag.complete = True;
            return tag;
        }
        for member in nd.operands {
            if member.kind == "attribute" { tag.attributes.append(member); continue; }
            if member.kind == "static_assert" { tag.assertions.append(member); continue; }
            parts = member.operands;
            if len(parts) == 1 {
                field_type = self.specifiers(parts[0]);
                anonymous = unqualified(field_type);
                if not isinstance(anonymous, CRecord) or anonymous.name or not anonymous.complete {
                    self.fail(member, "Member declaration without a declarator must define an anonymous record");
                }
                tag.fields.append(CField("", field_type, member, ordinal=len(tag.fields)));
            }
            for item in parts[1:] {
                declarator = item.operands[0];
                field_type = self.resolve(parts[0], declarator);
                width = next((child.operands[0] for child in item.operands[1:]
                    if child.kind == "bitfield_width"), None);
                bit_count = self.integer_constant(width) if width is not None else None;
                tag.fields.append(CField(declarator_name(declarator), field_type, item, width,
                    len(tag.fields), bit_count.value if bit_count is not None else None));
            }
        }
        tag.complete = True;
        tag.member_paths();
        return tag;
    }
}
