"""C syntax to UniTree. C operations remain explicit pending semantic lowering."""
import re;
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
    def starts_type -> bool {
        return self.peek() in ["void", "char", "short", "int", "long", "float", "double", "signed", "unsigned",
            "_Bool", "_Complex", "_Imaginary", "const", "volatile", "restrict", "_Atomic", "struct", "union", "enum"] or self.is_typedef(self.peek());
    }
    def starts_declaration -> bool {
        return self.starts_type() or self.peek() in ["typedef", "extern", "static", "_Thread_local", "auto",
            "register", "inline", "_Noreturn", "_Alignas", "_Static_assert"];
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
            if text in storage {
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
        if not seen_type { raise ValueError("Expected explicit C type specifier"); }
        return CTypeSpec("specifiers", start.as_unitree(), parts, end=self.ending().as_unitree());
    }

    def record_spec -> CTypeSpec {
        start = self.take(); name = "";
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
        return CTypeSpec(start.text + ("_definition" if defined else "_reference"), start.as_unitree(), members, value=name, end=self.ending().as_unitree());
    }

    def declarator(abstract: bool = False, names: bool = True) -> CDeclarator {
        start = self.current(); pointers: list[CNode] = [];
        while self.accept("*") {
            p = self.ending(); quals: list[CNode] = [];
            while self.peek() in ["const", "volatile", "restrict", "_Atomic"] {
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
            if self.accept("[") {
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
                            parameter_name = self.declarator_name(decl);
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

    def declarator_name(nd: CNode) -> str {
        if nd.kind == "name" { return nd.value; }
        children = nd.operands;
        if nd.kind == "declarator" { return self.declarator_name(children[-1]) if children else ""; }
        if nd.kind in ["group", "array", "function"] { return self.declarator_name(children[0]); }
        return "";
    }

    # Operators ordered from the declared identifier outward. This distinguishes
    # a function returning a pointer from an object pointing to a function.
    def derived_operators(nd: CNode) -> list[CNode] {
        children = nd.operands;
        if nd.kind == "declarator" {
            return self.derived_operators(children[-1]) + list(reversed(children[:-1]));
        }
        if nd.kind == "group" { return self.derived_operators(children[0]); }
        if nd.kind in ["array", "function"] { return self.derived_operators(children[0]) + [nd]; }
        return [];
    }
    def type_name -> CTypeSpec {
        start = self.current(); spec = self.specs(False); decl = self.declarator(True, False);
        if self.declarator_name(decl) { raise ValueError("Identifier is not allowed in a type name"); }
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
            name = self.declarator_name(decl);
            if name and not member { self.scopes[-1][name] = is_typedef; }
            items: list[CNode] = [decl];
            if member and self.accept(":") { items.append(CExpression("bitfield_width", self.ending().as_unitree(), [self.expression(3)])); }
            if self.peek() == "{" and top and len(children) == 1 {
                if is_typedef { raise ValueError("Typedef cannot have a function body"); }
                operators = self.derived_operators(decl);
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
        operators = self.derived_operators(nd);
        if operators and operators[0].kind == "function" {
            for p in operators[0].operands[1:] {
                if p.kind == "parameter" {
                    name = self.declarator_name(p.operands[1]);
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
        if t.text in ["++", "--", "&", "*", "+", "-", "~", "!"] {
            self.take(); return CExpression("unary", t.as_unitree(), [self.unary()], value=t.text);
        }
        if t.text in ["sizeof", "_Alignof"] {
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
                self.take(); yes = self.expression(); self.expect(":"); no = self.expression(3);
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
            if text == "goto" { name = self.identifier().text; }
            elif text == "return" and self.peek() != ";" { values.append(self.expression()); }
            self.expect(";"); return CStatement(text, t.as_unitree(), values, value=name, end=self.ending().as_unitree());
        }
        if text in ["case", "default"] {
            self.take(); values: list[CNode] = [];
            if text == "case" { values.append(self.expression(3)); }
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
    parser = CParser(preprocessing.tokens, preprocessing_node=program); tree = parser.parse();
    return CParseResult(tree, preprocessing, preprocessing.diagnostics + parser.diagnostics);
}
