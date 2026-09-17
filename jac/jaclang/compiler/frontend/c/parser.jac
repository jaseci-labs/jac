"""C syntax to UniTree. C operations remain explicit pending semantic lowering."""
import re;
import from .declarators { declarator_name, derived_operators }
import from .tokens { CToken, CDiagnostic }
import from .preprocessor { CConfig, CPreprocessor, CPreprocessResult }
import from jaclang.compiler.frontend.unitree_c {
    CNode, CTranslationUnit, CPreprocessingUnit, CDeclaration, CTypeSpec, CDeclarator, CExpression, CStatement
}

obj CParseResult {
    has tree: CTranslationUnit, preprocessing: CPreprocessResult, diagnostics: list[CDiagnostic];
    has ok: bool {
        getter { return not any(d.severity == "error" for d in self.diagnostics); }
    }
}

obj CParser {
    has tokens: list[CToken], pos: int = 0, diagnostics: list[CDiagnostic] = [],
        scopes: list[dict[str, bool]] = [{}],
        preprocessing_node: CPreprocessingUnit | None = None;

    def current -> CToken { return self.tokens[min(self.pos, len(self.tokens) - 1)]; }
    def peek -> str { return self.current().text; }
    def take -> CToken {
        t = self.current();
        if t.kind == "eof" { raise ValueError("Unexpected end of C source"); }
        self.pos += 1; return t;
    }
    def accept(text: str) -> bool {
        if self.peek() == text { self.pos += 1; return True; }
        return False;
    }
    def expect(text: str) -> CToken {
        if self.peek() != text { raise ValueError("Expected '" + text + "', found '" + self.peek() + "'"); }
        return self.take();
    }
    def identifier -> CToken {
        t = self.current();
        reserved = ["auto", "break", "case", "char", "const", "continue", "default", "do", "double",
            "else", "enum", "extern", "float", "for", "goto", "if", "inline", "int", "long", "register",
            "restrict", "return", "short", "signed", "sizeof", "static", "struct", "switch", "typedef",
            "union", "unsigned", "void", "volatile", "while", "_Alignas", "_Alignof", "_Atomic", "_Bool",
            "_Complex", "_Generic", "_Imaginary", "_Noreturn", "_Static_assert", "_Thread_local"];
        if t.kind != "identifier" or t.text in reserved { raise ValueError("Expected C identifier"); }
        return self.take();
    }
    def is_typedef(name: str) -> bool {
        for scope in reversed(self.scopes) { if name in scope { return scope[name]; } }
        return False;
    }
    # GNU spellings are normalized at the specifier boundary; attributes retain
    # their balanced token payload so lowering cannot silently discard ABI data.
    def attribute -> CTypeSpec {
        start = self.take(); spelling: list[str] = [start.text];
        self.expect("("); spelling.append("("); depth = 1;
        if start.text in ["asm", "__asm", "__asm__"] {
            if self.current().kind != "string" { raise ValueError("Assembler symbol label requires a string literal"); }
            symbol = self.primary(); self.expect(")");
            return CTypeSpec("asm_label", start.as_unitree(), [symbol], end=self.ending().as_unitree());
        }
        names: list[CToken] = [];
        arguments: list[list[CNode]] = [];
        name_depth = 1 if start.text == "__declspec" else 2;
        previous = "(";
        while depth {
            token = self.take(); spelling.append(token.text);
            if token.kind == "identifier" and depth == name_depth
                and (previous in ["(", ","] or start.text == "__declspec") {
                names.append(token); arguments.append([]);
                if token.text.strip("_") == "aligned" and self.peek() == "(" {
                    first = self.pos; self.take();
                    if self.peek() != ")" { arguments[-1].append(self.expression(3)); }
                    self.expect(")");
                    spelling.extend(part.text for part in self.tokens[first:self.pos]);
                    previous = ")";
                    continue;
                }
            } elif names and depth > name_depth
                and not (depth == name_depth + 1 and token.text == ")") {
                arguments[-1].append(CTypeSpec("attribute_token", token.as_unitree(), value=token.text));
            }
            if token.text == "(" { depth += 1; }
            elif token.text == ")" { depth -= 1; }
            previous = token.text;
        }
        attributes: list[CNode] = [CTypeSpec("attribute_name", token.as_unitree(), arguments[index],
            value=token.text.strip("_")) for (index, token) in enumerate(names)];
        return CTypeSpec("attribute", start.as_unitree(), attributes, value=" ".join(spelling), end=self.ending().as_unitree());
    }

    def starts_type -> bool {
        return self.peek() in ["void", "char", "short", "int", "long", "float", "double", "signed", "unsigned",
            "_Bool", "_Complex", "_Imaginary", "const", "volatile", "restrict", "_Atomic", "struct", "union", "enum",
            "__const", "__const__", "__volatile", "__volatile__", "__restrict", "__restrict__",
            "__attribute__", "__attribute", "__declspec", "__signed", "__signed__", "__int128", "_Float16", "_Float32", "_Float64", "_Float128", "_Float32x", "_Float64x", "_Float128x", "__auto_type", "__typeof", "__typeof__", "typeof"] or self.is_typedef(self.peek());
    }
    def starts_declaration -> bool {
        if self.peek() == "__extension__" {
            saved = self.pos;
            while self.accept("__extension__") { }
            declaration = self.starts_declaration(); self.pos = saved;
            return declaration;
        }
        return self.starts_type() or self.peek() in ["typedef", "extern", "static", "_Thread_local", "auto",
            "register", "inline", "__thread", "_Noreturn", "_Alignas", "_Static_assert", "__inline", "__inline__", "__extension__", "__attribute__", "__attribute", "__declspec"];
    }
    def ending -> CToken { return self.tokens[max(0, self.pos - 1)]; }

    def parse -> CTranslationUnit {
        first = self.current(); body: list[CNode] = [];
        if self.preprocessing_node is not None { body.append(self.preprocessing_node); }
        while self.current().kind != "eof" {
            start = self.pos;
            try { body.append(self.declaration(True)); }
            except ValueError as error {
                self.diagnostics.append(CDiagnostic(str(error), self.current()));
                depth = 0;
                for token in self.tokens[start:self.pos] {
                    if token.text == "{" { depth += 1; }
                    elif token.text == "}" { depth = max(0, depth - 1); }
                }
                while self.current().kind != "eof" {
                    t = self.take().text;
                    if t == "{" { depth += 1; }
                    elif t == "}" {
                        depth = max(0, depth - 1);
                        if depth == 0 { break; }
                    } elif t == ";" and depth == 0 { break; }
                }
                self.scopes = [self.scopes[0]];
            }
        }
        return CTranslationUnit("translation_unit", first.as_unitree(), body, end=self.ending().as_unitree());
    }

    def specs(allow_storage: bool = True) -> CTypeSpec {
        start = self.current(); parts: list[CNode] = []; seen_type = False;
        storage = ["typedef", "extern", "static", "_Thread_local", "auto", "register", "inline", "_Noreturn"];
        scalar = ["void", "char", "short", "int", "long", "float", "double", "signed", "unsigned", "_Bool", "_Complex", "_Imaginary"];
        while True {
            t = self.current(); text = t.text;
            aliases = {"__const": "const", "__const__": "const", "__volatile": "volatile", "__volatile__": "volatile",
                "__restrict": "restrict", "__restrict__": "restrict", "__signed": "signed", "__signed__": "signed",
                "__inline": "inline", "__inline__": "inline", "__thread": "_Thread_local"};
            text = aliases.get(text, text);
            if text in ["__attribute__", "__attribute", "__declspec"] {
                parts.append(self.attribute());
            } elif text == "__extension__" {
                self.take(); parts.append(CTypeSpec("extension", t.as_unitree(), value=text));
            } elif text in ["typeof", "__typeof", "__typeof__"] {
                self.take(); self.expect("(");
                operand = self.type_name() if self.starts_type() else self.expression();
                self.expect(")"); parts.append(CTypeSpec("typeof", t.as_unitree(), [operand])); seen_type = True;
            } elif text in ["__int128", "_Float16", "_Float32", "_Float64", "_Float128", "_Float32x", "_Float64x", "_Float128x", "__auto_type"] {
                self.take(); parts.append(CTypeSpec("scalar", t.as_unitree(), value=text)); seen_type = True;
            } elif text in storage {
                if not allow_storage { break; }
                self.take(); parts.append(CTypeSpec("storage", t.as_unitree(), value=text));
            } elif text in scalar {
                self.take(); parts.append(CTypeSpec("scalar", t.as_unitree(), value=text)); seen_type = True;
            } elif text in ["const", "volatile", "restrict", "_Atomic"] {
                self.take();
                if text == "_Atomic" and self.accept("(") {
                    inner = self.type_name(); self.expect(")");
                    parts.append(CTypeSpec("atomic", t.as_unitree(), [inner])); seen_type = True;
                } else { parts.append(CTypeSpec("qualifier", t.as_unitree(), value=text)); }
            } elif text == "_Alignas" and allow_storage {
                self.take(); self.expect("(");
                alignment = self.type_name() if self.starts_type() else self.expression(3);
                self.expect(")"); parts.append(CTypeSpec("alignment", t.as_unitree(), [alignment]));
            } elif text in ["struct", "union", "enum"] {
                parts.append(self.record_spec()); seen_type = True;
            } elif self.is_typedef(text) and not seen_type {
                self.take(); parts.append(CTypeSpec("typedef_name", t.as_unitree(), value=text)); seen_type = True;
            } else { break; }
        }
        if not seen_type { raise ValueError("Expected explicit C type specifier, found '" + self.peek() + "'"); }
        return CTypeSpec("specifiers", start.as_unitree(), parts, end=self.ending().as_unitree());
    }

    def record_spec -> CTypeSpec {
        start = self.take(); name = ""; attributes: list[CNode] = [];
        while self.peek() in ["__attribute__", "__attribute", "__declspec"] { attributes.append(self.attribute()); }
        if self.current().kind == "identifier" { name = self.identifier().text; }
        members: list[CNode] = []; defined = self.accept("{");
        if defined {
            while self.peek() != "}" {
                if start.text == "enum" {
                    t = self.identifier(); values: list[CNode] = [];
                    if self.accept("=") { values.append(self.expression(3)); }
                    members.append(CDeclaration("enumerator", t.as_unitree(), values, value=t.text));
                    self.scopes[-1][t.text] = False;
                    if not self.accept(",") { break; }
                } else { members.append(self.declaration(False, True)); }
            }
            self.expect("}");
        } elif not name { raise ValueError("Anonymous record requires a definition"); }
        while self.peek() in ["__attribute__", "__attribute", "__declspec"] { attributes.append(self.attribute()); }
        members.extend(attributes);
        return CTypeSpec(start.text + ("_definition" if defined else "_reference"), start.as_unitree(), members, value=name, end=self.ending().as_unitree());
    }

    def declarator(abstract: bool = False, names: bool = True) -> CDeclarator {
        start = self.current(); pointers: list[CNode] = [];
        while self.accept("*") {
            p = self.ending(); quals: list[CNode] = [];
            while self.peek() in ["const", "volatile", "restrict", "_Atomic", "__restrict", "__restrict__", "__const", "__const__", "__volatile", "__volatile__"] {
                q = self.take(); quals.append(CTypeSpec("qualifier", q.as_unitree(), value=q.text));
            }
            pointers.append(CDeclarator("pointer", p.as_unitree(), quals));
        }
        group = self.peek() == "(";
        if group and abstract {
            saved = self.pos; self.take();
            group = self.peek() != ")" and not self.starts_type(); self.pos = saved;
        }
        if group {
            self.take(); direct = self.declarator(abstract, names); self.expect(")");
            direct = CDeclarator("group", start.as_unitree(), [direct]);
        } elif names and self.current().kind == "identifier" and (not self.starts_type() or self.is_typedef(self.peek())) {
            name = self.identifier(); direct = CDeclarator("name", name.as_unitree(), value=name.text);
        } elif abstract { direct = CDeclarator("abstract", self.current().as_unitree()); }
        elif self.current().kind == "identifier" {
            name = self.identifier(); direct = CDeclarator("name", name.as_unitree(), value=name.text);
        } else { raise ValueError("Expected C declarator"); }
        while True {
            t = self.current();
            if self.peek() in ["__attribute__", "__attribute", "__declspec", "__asm", "__asm__", "asm"] {
                attribute = self.attribute();
                direct = CDeclarator("attributed", t.as_unitree(), [direct, attribute]);
            } elif self.accept("[") {
                bounds: list[CNode] = [direct];
                while self.peek() in ["static", "const", "volatile", "restrict"] {
                    q = self.take(); bounds.append(CTypeSpec("array_qualifier", q.as_unitree(), value=q.text));
                }
                if self.accept("*") { bounds.append(CExpression("vla_star", self.ending().as_unitree())); }
                elif self.peek() != "]" { bounds.append(self.expression(2)); }
                self.expect("]"); direct = CDeclarator("array", t.as_unitree(), bounds, end=self.ending().as_unitree());
            } elif self.accept("(") {
                params: list[CNode] = [direct]; self.scopes.append({});
                try {
                    if self.peek() != ")" {
                        while True {
                            if self.accept("...") {
                                if len(params) == 1 { raise ValueError("Variadic prototype needs a named parameter"); }
                                params.append(CDeclaration("variadic", self.ending().as_unitree())); break;
                            }
                            p = self.current(); spec = self.specs(); decl = self.declarator(True);
                            params.append(CDeclaration("parameter", p.as_unitree(), [spec, decl]));
                            parameter_name = declarator_name(decl);
                            if parameter_name { self.scopes[-1][parameter_name] = False; }
                            if not self.accept(",") { break; }
                        }
                    }
                    self.expect(")");
                } finally { self.scopes.pop(); }
                direct = CDeclarator("function", t.as_unitree(), params, end=self.ending().as_unitree());
            } else { break; }
        }
        return CDeclarator("declarator", start.as_unitree(), pointers + [direct], end=self.ending().as_unitree());
    }

    def type_name -> CTypeSpec {
        start = self.current(); spec = self.specs(False); decl = self.declarator(True, False);
        if declarator_name(decl) { raise ValueError("Identifier is not allowed in a type name"); }
        return CTypeSpec("type_name", start.as_unitree(), [spec, decl], end=self.ending().as_unitree());
    }

    def declaration(top: bool = False, member: bool = False) -> CDeclaration {
        start = self.current();
        if self.accept("_Static_assert") {
            self.expect("("); condition = self.expression(3); self.expect(",");
            if self.current().kind != "string" { raise ValueError("Static assertion requires a string message"); }
            message = self.primary(); self.expect(")"); self.expect(";");
            return CDeclaration("static_assert", start.as_unitree(), [condition, message], end=self.ending().as_unitree());
        }
        spec = self.specs(); children: list[CNode] = [spec];
        is_typedef = any(p.kind == "storage" and p.value == "typedef" for p in spec.operands);
        if self.accept(";") { return CDeclaration("declaration", start.as_unitree(), children, end=self.ending().as_unitree()); }
        while True {
            anchor = self.current();
            if member and self.peek() == ":" { decl = CDeclarator("abstract", anchor.as_unitree()); }
            else { decl = self.declarator(); }
            name = declarator_name(decl);
            if name and not member { self.scopes[-1][name] = is_typedef; }
            items: list[CNode] = [decl];
            if member and self.accept(":") { items.append(CExpression("bitfield_width", self.ending().as_unitree(), [self.expression(3)])); }
            if self.peek() == "{" and top and len(children) == 1 {
                if is_typedef { raise ValueError("Typedef cannot have a function body"); }
                operators = derived_operators(decl);
                if not operators or operators[0].kind != "function" {
                    raise ValueError("Function body requires a function declarator");
                }
                bindings: dict[str, bool] = {}; self.parameter_bindings(decl, bindings);
                body = self.compound(bindings);
                return CDeclaration("function_definition", start.as_unitree(), [spec, decl, body], end=self.ending().as_unitree());
            }
            if self.accept("=") { items.append(self.initializer()); }
            children.append(CDeclaration("init_declarator", anchor.as_unitree(), items, value=name));
            if not self.accept(",") { break; }
        }
        self.expect(";");
        return CDeclaration("member_declaration" if member else "declaration", start.as_unitree(), children, end=self.ending().as_unitree());
    }
    def parameter_bindings(nd: CNode, bindings: dict[str, bool]) {
        operators = derived_operators(nd);
        if operators and operators[0].kind == "function" {
            for p in operators[0].operands[1:] {
                if p.kind == "parameter" {
                    name = declarator_name(p.operands[1]);
                    if name { bindings[name] = False; }
                }
            }
        }
    }

    def initializer -> CExpression {
        start = self.current();
        if not self.accept("{") { return self.expression(2); }
        values: list[CNode] = [];
        while self.peek() != "}" {
            anchor = self.current(); designators: list[CNode] = [];
            while self.peek() in [".", "["] {
                t = self.take();
                if t.text == "." { designators.append(CExpression("field_designator", t.as_unitree(), value=self.identifier().text)); }
                else {
                    designators.append(CExpression("index_designator", t.as_unitree(), [self.expression(3)])); self.expect("]");
                }
            }
            if designators { self.expect("="); }
            value = self.initializer();
            values.append(CExpression("designated_initializer", anchor.as_unitree(), designators + [value]) if designators else value);
            if not self.accept(",") { break; }
        }
        self.expect("}"); return CExpression("initializer_list", start.as_unitree(), values, end=self.ending().as_unitree());
    }

    def primary -> CExpression {
        t = self.take();
        if t.text == "(" {
            if self.peek() == "{" {
                block = self.compound(); self.expect(")");
                return CExpression("statement_expression", t.as_unitree(), [block], end=self.ending().as_unitree());
            }
            value = self.expression(); self.expect(")");
            return CExpression("parenthesized", t.as_unitree(), [value], end=self.ending().as_unitree());
        }
        if t.kind in ["number", "char", "string"] {
            if t.kind == "number" {
                integer = r"(?:0[xX][0-9a-fA-F]+|0[0-7]*|[1-9][0-9]*)(?:[uU](?:[lL]|ll|LL)?|(?:[lL]|ll|LL)[uU]?)?";
                floating = r"(?:(?:(?:[0-9]+\.[0-9]*|\.[0-9]+)(?:[eE][+-]?[0-9]+)?|[0-9]+[eE][+-]?[0-9]+)|0[xX](?:[0-9a-fA-F]+\.?[0-9a-fA-F]*|\.[0-9a-fA-F]+)[pP][+-]?[0-9]+)[fFlL]?";
                if re.fullmatch(integer, t.text) is None and re.fullmatch(floating, t.text) is None {
                    raise ValueError("Invalid C numeric constant: " + t.text);
                }
            }
            parts: list[CNode] = [];
            if t.kind == "string" {
                while self.current().kind == "string" {
                    part = self.take(); parts.append(CExpression("string", part.as_unitree(), value=part.text));
                }
            }
            return CExpression(t.kind, t.as_unitree(), parts, value=t.text, end=self.ending().as_unitree());
        }
        if t.kind == "identifier" {
            self.pos -= 1; self.identifier();
            if self.is_typedef(t.text) { raise ValueError("Typedef name used as expression: " + t.text); }
            return CExpression("identifier", t.as_unitree(), value=t.text);
        }
        raise ValueError("Expected C expression, found '" + t.text + "'");
    }

    def unary -> CExpression {
        t = self.current();
        if t.text == "__extension__" {
            self.take(); return CExpression("extension", t.as_unitree(), [self.unary()]);
        }
        if t.text in ["__builtin_va_arg", "__builtin_offsetof", "__builtin_types_compatible_p"] {
            self.take(); self.expect("("); arguments: list[CNode] = [];
            if t.text == "__builtin_va_arg" {
                arguments.append(self.expression(2)); self.expect(","); arguments.append(self.type_name());
            } else {
                arguments.append(self.type_name()); self.expect(",");
                arguments.append(self.type_name() if t.text == "__builtin_types_compatible_p" else self.expression(2));
            }
            self.expect(")"); return CExpression("builtin", t.as_unitree(), arguments, value=t.text);
        }
        if t.text in ["++", "--", "&", "*", "+", "-", "~", "!"] {
            self.take(); return CExpression("unary", t.as_unitree(), [self.unary()], value=t.text);
        }
        if t.text in ["sizeof", "_Alignof", "__alignof", "__alignof__"] {
            self.take();
            if self.peek() == "(" {
                saved = self.pos; self.take();
                if self.starts_type() {
                    typ = self.type_name(); self.expect(")");
                    return CExpression(t.text + "_type", t.as_unitree(), [typ]);
                }
                self.pos = saved;
            }
            if t.text == "_Alignof" { raise ValueError("_Alignof requires a type name"); }
            return CExpression("sizeof_expr", t.as_unitree(), [self.unary()]);
        }
        if t.text == "_Generic" {
            self.take(); self.expect("("); control = self.expression(2); self.expect(","); choices: list[CNode] = [control];
            while True {
                anchor = self.current();
                typ = CTypeSpec("default", self.take().as_unitree()) if self.peek() == "default" else self.type_name();
                self.expect(":"); choices.append(CExpression("generic_association", anchor.as_unitree(), [typ, self.expression(2)]));
                if not self.accept(",") { break; }
            }
            self.expect(")"); return CExpression("generic", t.as_unitree(), choices);
        }
        if t.text == "(" {
            saved = self.pos; self.take();
            if self.starts_type() {
                typ = self.type_name(); self.expect(")");
                if self.peek() == "{" {
                    value = CExpression("compound_literal", t.as_unitree(), [typ, self.initializer()]); return self.postfix(value);
                }
                return CExpression("cast", t.as_unitree(), [typ, self.unary()]);
            }
            self.pos = saved;
        }
        return self.postfix(self.primary());
    }
    def postfix(value: CExpression) -> CExpression {
        while True {
            t = self.current();
            if self.accept("(") {
                args: list[CNode] = [value];
                if self.peek() != ")" {
                    while True {
                        args.append(self.expression(2));
                        if not self.accept(",") { break; }
                    }
                }
                self.expect(")"); value = CExpression("call", t.as_unitree(), args);
            } elif self.accept("[") {
                index = self.expression(); self.expect("]"); value = CExpression("subscript", t.as_unitree(), [value, index]);
            } elif t.text in [".", "->"] {
                self.take(); name = self.identifier(); value = CExpression("member", t.as_unitree(), [value], value=t.text + name.text);
            } elif t.text in ["++", "--"] {
                self.take(); value = CExpression("postfix", t.as_unitree(), [value], value=t.text);
            } else { break; }
        }
        return value;
    }
    def expression(minimum: int = 1) -> CExpression {
        precedence = {",": 1, "=": 2, "+=": 2, "-=": 2, "*=": 2, "/=": 2, "%=": 2,
            "<<=": 2, ">>=": 2, "&=": 2, "^=": 2, "|=": 2,
            "||": 4, "&&": 5, "|": 6, "^": 7, "&": 8, "==": 9, "!=": 9,
            "<": 10, ">": 10, "<=": 10, ">=": 10, "<<": 11, ">>": 11,
            "+": 12, "-": 12, "*": 13, "/": 13, "%": 13};
        left = self.unary();
        while True {
            t = self.current();
            if t.text == "?" and minimum <= 3 {
                self.take();
                if self.accept(":") {
                    left = CExpression("conditional_omitted", t.as_unitree(), [left, self.expression(3)]); continue;
                }
                yes = self.expression(); self.expect(":"); no = self.expression(3);
                left = CExpression("conditional", t.as_unitree(), [left, yes, no]); continue;
            }
            power = precedence.get(t.text, 0);
            if power < minimum { break; }
            self.take(); right = self.expression(power if power == 2 else power + 1);
            kind = "assignment" if power == 2 else ("comma" if power == 1 else "binary");
            left = CExpression(kind, t.as_unitree(), [left, right], value=t.text);
        }
        return left;
    }

    def compound(bindings: dict[str, bool] | None = None) -> CStatement {
        t = self.expect("{"); children: list[CNode] = []; self.scopes.append(dict(bindings or {}));
        try {
            while self.peek() != "}" { children.append(self.declaration() if self.starts_declaration() else self.statement()); }
            self.expect("}");
        } finally { self.scopes.pop(); }
        return CStatement("compound", t.as_unitree(), children, end=self.ending().as_unitree());
    }
    def statement -> CStatement {
        t = self.current(); text = t.text;
        if text in ["asm", "__asm", "__asm__"] {
            self.take(); spelling: list[str] = [text];
            while self.peek() in ["volatile", "__volatile", "__volatile__", "inline", "goto"] { spelling.append(self.take().text); }
            self.expect("("); spelling.append("("); depth = 1;
            while depth {
                token = self.take(); spelling.append(token.text);
                if token.text == "(" { depth += 1; }
                elif token.text == ")" { depth -= 1; }
            }
            self.expect(";"); return CStatement("asm", t.as_unitree(), value=" ".join(spelling), end=self.ending().as_unitree());
        }
        if text == "{" { return self.compound(); }
        if text == ";" { self.take(); return CStatement("empty", t.as_unitree()); }
        if text in ["if", "switch", "while"] {
            self.take(); self.expect("("); condition = self.expression(); self.expect(")");
            children: list[CNode] = [condition, self.statement()];
            if text == "if" and self.accept("else") { children.append(self.statement()); }
            return CStatement(text, t.as_unitree(), children, end=self.ending().as_unitree());
        }
        if text == "do" {
            self.take(); body = self.statement(); self.expect("while"); self.expect("(");
            condition = self.expression(); self.expect(")"); self.expect(";");
            return CStatement("do_while", t.as_unitree(), [body, condition], end=self.ending().as_unitree());
        }
        if text == "for" {
            self.take(); self.expect("("); self.scopes.append({}); parts: list[CNode] = [];
            try {
                if self.starts_declaration() { parts.append(self.declaration()); }
                else {
                    parts.append(self.expression() if self.peek() != ";" else CExpression("omitted", self.current().as_unitree())); self.expect(";");
                }
                parts.append(self.expression() if self.peek() != ";" else CExpression("omitted", self.current().as_unitree())); self.expect(";");
                parts.append(self.expression() if self.peek() != ")" else CExpression("omitted", self.current().as_unitree())); self.expect(")"); parts.append(self.statement());
            } finally { self.scopes.pop(); }
            return CStatement("for", t.as_unitree(), parts, end=self.ending().as_unitree());
        }
        if text in ["return", "break", "continue", "goto"] {
            self.take(); values: list[CNode] = []; name = "";
            if text == "goto" {
                if self.accept("*") {
                    values.append(self.expression()); self.expect(";");
                    return CStatement("computed_goto", t.as_unitree(), values, end=self.ending().as_unitree());
                }
                name = self.identifier().text;
            }
            elif text == "return" and self.peek() != ";" { values.append(self.expression()); }
            self.expect(";"); return CStatement(text, t.as_unitree(), values, value=name, end=self.ending().as_unitree());
        }
        if text in ["case", "default"] {
            self.take(); values: list[CNode] = [];
            if text == "case" {
                values.append(self.expression(3));
                if self.accept("...") {
                    values.append(self.expression(3)); text = "case_range";
                }
            }
            self.expect(":"); values.append(self.statement()); return CStatement(text, t.as_unitree(), values);
        }
        if t.kind == "identifier" and self.pos + 1 < len(self.tokens) and self.tokens[self.pos + 1].text == ":" {
            self.identifier(); self.expect(":"); return CStatement("label", t.as_unitree(), [self.statement()], value=text);
        }
        value = self.expression(); self.expect(";"); return CStatement("expression", t.as_unitree(), [value], end=self.ending().as_unitree());
    }
}

"""Parse one configured translation unit. `ok` denotes syntax acceptance only.

Includes use explicit configuration. No external compiler or shell is run.
"""
def parse_c(source: str, file_path: str = "<c-input>", config: CConfig | None = None) -> CParseResult {
    preprocessing = CPreprocessor(config or CConfig()).run(source, file_path);
    program = CPreprocessingUnit("preprocessing_unit", preprocessing.tokens[0].as_unitree(), preprocessing.operations);
    initial = {name: True for name in config.typedef_names} if config is not None else {};
    parser = CParser(preprocessing.tokens, scopes=[initial], preprocessing_node=program); tree = parser.parse();
    return CParseResult(tree, preprocessing, preprocessing.diagnostics + parser.diagnostics);
}
