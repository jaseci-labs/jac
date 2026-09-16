"""C semantic lowering to standard Jac UniTree; no Jac source concatenation."""
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.c.parser { CParser, CParseResult }
import from jaclang.compiler.frontend.c.semantics { CEmitConfig, CScalar, compatible, promote, common }
import from jaclang.compiler.frontend.c.jac_ast { CJacAst }
import from jaclang.compiler.frontend.c.tokens { CDiagnostic }
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
        typ: CScalar,
        constant: bool = False;
}

obj CBinding {
    has name: str,
        typ: CScalar,
        readonly: bool = False,
        global_var: bool = False;
}

obj CFunction {
    has name: str,
        returns: CScalar,
        parameters: list[CScalar],
        definition: CNode | None = None;
}

obj CLowerPass {
    has config: CEmitConfig,
        ast: CJacAst,
        ctx: CompileContext,
        result: CLowerResult = CLowerResult(),
        aliases: dict[str, CScalar] = {},
        emitted_aliases: set[str] = set(),
        globals: dict[str, CBinding] = {},
        functions: dict[str, CFunction] = {},
        scopes: list[dict[str, CBinding]] = [],
        serial: int = 0,
        current: CNode | None = None,
        return_type: CScalar = CScalar(category="void"),
        # Each loop supplies the statements a continue must execute first.
        continue_actions: list[list[uni.CodeBlockStmt]] = [],
        helpers: dict[str, CScalar] = {};

    def fail(nd: CNode, message: str) {
        self.current = nd;
        raise ValueError(message);
    }

    def report_error(nd: CNode, message: str) {
        self.ctx.emit(E2290, node_override=nd, details=message);
    }

    def scalar(spec: CNode) -> CScalar {
        self.current = spec;
        words: list[str] = []; alias: CScalar | None = None;
        for part in spec.operands {
            if part.kind == "storage" { continue; }
            if part.kind == "qualifier" {
                if part.value != "const" { self.fail(part, "Qualifier '" + part.value + "' requires C memory semantics"); }
            } elif part.kind == "scalar" { words.append(part.value); }
            elif part.kind == "typedef_name" {
                alias = self.aliases.get(part.value);
                if alias is None { self.fail(part, "Unsupported or unknown typedef " + part.value); }
            } else { self.fail(part, "Type form '" + part.kind + "' has no source lowering yet"); }
        }
        if alias is not None {
            if words { self.fail(spec, "Typedef cannot be combined with scalar specifiers"); }
            return alias;
        }
        if words == ["void"] { return CScalar(category="void"); }
        if words == ["_Bool"] { return CScalar(width=8, signed=False, rank=0, category="bool"); }
        allowed = ["char", "short", "int", "long", "signed", "unsigned"];
        if not words or any(w not in allowed for w in words) {
            self.fail(spec, "Only integer, _Bool, and void scalar types are currently emitted");
        }
        for word in allowed {
            if words.count(word) > (2 if word == "long" else 1) { self.fail(spec, "Repeated C type specifier " + word); }
        }
        if "signed" in words and "unsigned" in words { self.fail(spec, "Conflicting C signedness specifiers"); }
        if "char" in words {
            if any(w in words for w in ["short", "long", "int"]) { self.fail(spec, "Invalid char type specifiers"); }
            signed = "unsigned" not in words and ("signed" in words or self.config.char_signed);
            return CScalar(8, signed, 1);
        }
        if "short" in words {
            if "long" in words { self.fail(spec, "Conflicting short and long specifiers"); }
            return CScalar(16, "unsigned" not in words, 2);
        }
        longs = words.count("long");
        width = 64 if longs == 2 or (longs == 1 and self.config.abi == "lp64") else 32;
        return CScalar(width, "unsigned" not in words, 3 + longs);
    }

    def storage(spec: CNode) -> list[str] {
        return [p.value for p in spec.operands if p.kind == "storage"];
    }

    def readonly(spec: CNode) -> bool {
        return any(p.kind == "qualifier" and p.value == "const" for p in spec.operands);
    }

    def name_of(decl: CNode) -> str {
        return CParser(tokens=[]).declarator_name(decl);
    }

    def operators(decl: CNode) -> list[CNode] {
        return CParser(tokens=[]).derived_operators(decl);
    }

    def variable(spec: CNode, decl: CNode) -> CScalar {
        typ = self.scalar(spec);
        if typ.category == "void" { self.fail(decl, "Object cannot have void type"); }
        if self.operators(decl) { self.fail(decl, "Pointers, arrays, and function-pointer objects require further lowering"); }
        return typ;
    }

    def signature(spec: CNode, decl: CNode) -> CFunction {
        operators = self.operators(decl);
        if len(operators) != 1 or operators[0].kind != "function" { self.fail(decl, "Only scalar function signatures are currently emitted"); }
        returns = self.scalar(spec); params: list[CScalar] = [];
        parameters = operators[0].operands[1:];
        # Empty C parameter lists do not provide a prototype.
        if not parameters { self.fail(decl, "Use an explicit (void) prototype for a function without parameters"); }
        for parameter in parameters {
            if parameter.kind != "parameter" { self.fail(parameter, "Variadic functions require C calling-convention lowering"); }
            children = parameter.operands;
            typ = self.scalar(children[0]);
            if typ.category == "void" and len(parameters) == 1 and not self.name_of(children[1]) and not self.operators(children[1]) { break; }
            params.append(self.variable(children[0], children[1]));
        }
        return CFunction(self.name_of(decl), returns, params);
    }

    def remember_function(spec: CNode, decl: CNode, definition: CNode | None = None) {
        fn = self.signature(spec, decl);
        if fn.name in self.globals or fn.name in self.aliases { self.fail(decl, "Conflicting ordinary identifier " + fn.name); }
        previous = self.functions.get(fn.name);
        if previous is not None {
            if not compatible(previous.returns, fn.returns) or len(previous.parameters) != len(fn.parameters) {
                self.fail(decl, "Conflicting function declarations for " + fn.name);
            }
            for i in range(len(fn.parameters)) {
                if not compatible(previous.parameters[i], fn.parameters[i]) { self.fail(decl, "Conflicting parameter type for " + fn.name); }
            }
            if previous.definition is not None and definition is not None { self.fail(decl, "Duplicate function definition " + fn.name); }
            if definition is not None { previous.definition = definition; }
        } else { fn.definition = definition; self.functions[fn.name] = fn; }
    }

    def collect(nd: CNode) {
        if nd.kind == "preprocessing_unit" { return; }
        if nd.kind not in ["declaration", "function_definition"] { self.fail(nd, "Top-level " + nd.kind + " is not supported yet"); }
        children = nd.operands; spec = children[0]; storage = self.storage(spec);
        if any(s not in ["typedef", "static", "extern", "inline"] for s in storage) { self.fail(spec, "Unsupported storage or function specifier"); }
        if nd.kind == "function_definition" { self.remember_function(spec, children[1], nd); return; }
        if len(children) == 1 { self.scalar(spec); }
        for item in children[1:] {
            decl = item.operands[0]; name = self.name_of(decl); ops = self.operators(decl);
            if "typedef" in storage {
                if len(item.operands) > 1 { self.fail(item, "Typedef cannot have an initializer"); }
                typ = self.scalar(spec);
                if ops { self.fail(decl, "Only scalar typedefs can currently be emitted"); }
                if name in self.functions or name in self.globals { self.fail(decl, "Conflicting typedef " + name); }
                previous = self.aliases.get(name);
                if previous is not None and not compatible(previous, typ) { self.fail(decl, "Conflicting typedef " + name); }
                self.aliases[name] = typ;
            } elif ops and ops[0].kind == "function" {
                if len(item.operands) > 1 { self.fail(item, "Function declaration cannot have an initializer"); }
                self.remember_function(spec, decl);
            }
            else {
                if "extern" in storage { self.fail(item, "External object declarations require linkage lowering"); }
                if name in self.globals or name in self.functions or name in self.aliases { self.fail(item, "Repeated object declaration requires C linkage merging: " + name); }
                self.globals[name] = CBinding("c_" + name, self.variable(spec, decl), self.readonly(spec), True);
            }
        }
    }

    def converted(value: CValue, typ: CScalar) -> uni.Expr {
        if typ.category == "bool" { return self.ast.call("bool", [value.expr]); }
        if typ.category == "void" or value.typ.category == "void" { raise ValueError("A void expression cannot be converted to a value"); }
        if compatible(value.typ, typ) { return value.expr; }
        return self.ast.call(typ.jac + ".wrap", [value.expr]);
    }

    def zero(typ: CScalar) -> uni.Expr {
        return self.ast.boolean(False) if typ.category == "bool" else self.ast.call(typ.jac, [self.ast.integer(0)]);
    }

    def binding(nd: CNode) -> CBinding {
        if nd.kind == "parenthesized" { return self.binding(nd.operands[0]); }
        if nd.kind != "identifier" { self.fail(nd, "Only scalar identifier lvalues are supported"); }
        for scope in reversed(self.scopes) {
            found = scope.get(nd.value);
            if found is not None { return found; }
        }
        found = self.globals.get(nd.value);
        if found is not None { return found; }
        self.fail(nd, "Unknown scalar identifier " + nd.value);
        return CBinding("", CScalar());
    }

    def integer(nd: CNode) -> CValue {
        spelling = nd.value; end = len(spelling);
        while end and spelling[end - 1] in "uUlL" { end -= 1; }
        digits = spelling[:end]; suffix = spelling[end:].lower(); base = 10;
        if digits.lower().startswith("0x") { base = 16; }
        elif len(digits) > 1 and digits.startswith("0") { base = 8; }
        try { number = int(digits, base); }
        except ValueError { self.fail(nd, "Floating-point literals are not emitted yet"); number = 0; }
        minimum = 5 if "ll" in suffix else (4 if "l" in suffix else 3);
        for rank in range(minimum, 6) {
            width = 64 if rank == 5 or (rank == 4 and self.config.abi == "lp64") else 32;
            candidates = [False] if "u" in suffix else ([True, False] if base != 10 else [True]);
            for signed in candidates {
                if number < (1 << (width - (1 if signed else 0))) {
                    typ = CScalar(width, signed, rank);
                    return CValue(self.ast.call(typ.jac, [self.ast.integer(number)]), typ, True);
                }
            }
        }
        self.fail(nd, "Integer literal exceeds the selected C data model");
        return CValue(self.ast.integer(0), CScalar());
    }

    def binary(op: str, left: CValue, right: CValue, nd: CNode) -> CValue {
        self.ast.origin = nd;
        if left.typ.category == "void" or right.typ.category == "void" { self.fail(nd, "Void operand in integer expression"); }
        constant = left.constant and right.constant;
        if op in ["&&", "||"] {
            value = self.ast.binary("and" if op == "&&" else "or",
                self.ast.call("bool", [left.expr]), self.ast.call("bool", [right.expr]));
            return CValue(self.ast.call("i32", [value]), CScalar(), constant);
        }
        typ = promote(left.typ) if op in ["<<", ">>"] else common(left.typ, right.typ);
        a = self.converted(left, typ);
        b = self.converted(right, promote(right.typ) if op in ["<<", ">>"] else typ);
        if op in ["==", "!=", "<", ">", "<=", ">="] {
            return CValue(self.ast.call("i32", [self.ast.binary(op, a, b)]), CScalar(), constant);
        }
        wrapping = {"+": "wrapping_add", "-": "wrapping_sub", "*": "wrapping_mul", "<<": "wrapping_shl"};
        expr: uni.Expr;
        if not typ.signed and op in wrapping { expr = self.ast.call(wrapping[op], [a, b]); }
        elif op in ["/", "%"] and typ.signed {
            helper = "_c2jac_" + ("div_" if op == "/" else "rem_") + typ.jac;
            self.helpers[helper] = typ;
            if op == "%" { self.helpers["_c2jac_div_" + typ.jac] = typ; }
            expr = self.ast.call(helper, [a, b]);
        } else { expr = self.ast.binary("//" if op == "/" else op, a, b); }
        return CValue(expr, typ, constant);
    }

    def expression(nd: CNode) -> CValue {
        value = self.lower_expression(nd);
        self.ast.origin = nd;
        self.ast.mark(value.expr);
        return value;
    }

    def lower_expression(nd: CNode) -> CValue {
        self.current = nd; self.ast.origin = nd; children = nd.operands; kind = nd.kind;
        if kind == "number" { return self.integer(nd); }
        if kind == "identifier" {
            bound = self.binding(nd); return CValue(self.ast.name(bound.name), bound.typ);
        }
        if kind == "parenthesized" { return self.expression(children[0]); }
        if kind == "cast" {
            type_parts = children[0].operands;
            if self.operators(type_parts[1]) { self.fail(nd, "Pointer and array casts require further lowering"); }
            typ = self.scalar(type_parts[0]); value = self.expression(children[1]);
            return CValue(self.converted(value, typ), typ, value.constant);
        }
        if kind == "unary" {
            op = nd.value;
            if op not in ["+", "-", "~", "!"] { self.fail(nd, "Expression-valued " + op + " is not emitted yet"); }
            value = self.expression(children[0]);
            if value.typ.category == "void" { self.fail(nd, "Void operand in unary expression"); }
            if op == "!" { return CValue(self.ast.call("i32", [self.ast.unary("not", self.ast.call("bool", [value.expr]))]), CScalar(), value.constant); }
            typ = promote(value.typ); code = self.converted(value, typ);
            if op == "-" and not typ.signed { code = self.ast.call("wrapping_neg", [code]); }
            else { code = self.ast.unary(op, code); }
            return CValue(code, typ, value.constant);
        }
        if kind == "binary" { return self.binary(nd.value, self.expression(children[0]), self.expression(children[1]), nd); }
        if kind == "conditional" {
            condition = self.expression(children[0]); yes = self.expression(children[1]); no = self.expression(children[2]);
            if condition.typ.category == "void" or yes.typ.category == "void" or no.typ.category == "void" { self.fail(nd, "Void conditional expressions are not emitted yet"); }
            typ = common(yes.typ, no.typ);
            return CValue(self.ast.conditional(self.ast.call("bool", [condition.expr]), self.converted(yes, typ), self.converted(no, typ)), typ, condition.constant and yes.constant and no.constant);
        }
        if kind == "call" {
            callee = children[0];
            if callee.kind != "identifier" { self.fail(callee, "Indirect calls require function-pointer lowering"); }
            for scope in self.scopes {
                if callee.value in scope { self.fail(callee, "Call target is shadowed by a local object"); }
            }
            fn = self.functions.get(callee.value);
            if fn is None or fn.definition is None { self.fail(callee, "External call requires a C library binding: " + callee.value); }
            assert fn is not None;
            if len(children) - 1 != len(fn.parameters) { self.fail(nd, "Incorrect argument count for " + callee.value); }
            args: list[uni.Expr] = [];
            for i in range(len(fn.parameters)) { args.append(self.converted(self.expression(children[i + 1]), fn.parameters[i])); }
            return CValue(self.ast.call("c_" + fn.name, args), fn.returns);
        }
        if kind == "sizeof_type" {
            typ = self.variable(children[0].operands[0], children[0].operands[1]);
            size_type = CScalar(32 if self.config.abi == "ilp32" else 64, False, 3 if self.config.abi == "ilp32" else (4 if self.config.abi == "lp64" else 5));
            return CValue(self.ast.call(size_type.jac, [self.ast.integer(typ.width // 8)]), size_type, True);
        }
        self.fail(nd, "Expression '" + kind + "' requires further source lowering");
        return CValue(self.ast.integer(0), CScalar());
    }

    def effect(nd: CNode) -> list[uni.CodeBlockStmt] {
        children = nd.operands;
        if nd.kind == "omitted" { return []; }
        if nd.kind == "parenthesized" { return self.effect(children[0]); }
        if nd.kind == "comma" { return self.effect(children[0]) + self.effect(children[1]); }
        if nd.kind == "assignment" or (nd.kind in ["unary", "postfix"] and nd.value in ["++", "--"]) {
            bound = self.binding(children[0]);
            if bound.readonly { self.fail(nd, "Assignment to const object"); }
            if nd.kind == "assignment" {
                value = self.expression(children[1]);
                if nd.value != "=" { value = self.binary(nd.value[:-1], CValue(self.ast.name(bound.name), bound.typ), value, nd); }
            } else { value = self.binary("+" if nd.value == "++" else "-", CValue(self.ast.name(bound.name), bound.typ), CValue(self.ast.call("i32", [self.ast.integer(1)]), CScalar(), True), nd); }
            return [self.ast.assignment(bound.name, self.converted(value, bound.typ))];
        }
        value = self.expression(nd);
        return [self.ast.expression(value.expr)];
    }

    def fresh(name: str) -> str {
        self.serial += 1;
        return "_c2jac_local_" + str(self.serial) + "_" + name;
    }

    def local_declaration(nd: CNode) -> list[uni.CodeBlockStmt] {
        children = nd.operands; spec = children[0]; storage = self.storage(spec);
        if any(s != "auto" and s != "register" for s in storage) { self.fail(nd, "Local typedef/static/extern declarations require further lowering"); }
        lines: list[uni.CodeBlockStmt] = [];
        for item in children[1:] {
            parts = item.operands; decl = parts[0]; name = self.name_of(decl); typ = self.variable(spec, decl);
            if name in self.scopes[-1] { self.fail(decl, "Duplicate local declaration " + name); }
            binding = CBinding(self.fresh(name), typ, self.readonly(spec)); self.scopes[-1][name] = binding;
            # Reading an uninitialized C scalar has no defined value. Initializing
            # its Jac storage does not change defined executions of this subset.
            value = self.converted(self.expression(parts[1]), typ) if len(parts) > 1 else self.zero(typ);
            lines.append(self.ast.assignment(binding.name, value, typ.jac));
        }
        return lines;
    }

    def body(nd: CNode) -> list[uni.CodeBlockStmt] {
        if nd.kind == "compound" {
            self.scopes.append({}); stmts: list[uni.CodeBlockStmt] = [];
            try {
                for child in nd.operands {
                    self.ast.origin = child;
                    stmts.extend(self.local_declaration(child) if child.kind == "declaration" else self.statement(child));
                }
            } finally { self.scopes.pop(); }
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
                if self.return_type.category != "void" { self.fail(nd, "Non-void return needs a value"); }
                return [self.ast.returned()];
            }
            if self.return_type.category == "void" { self.fail(nd, "Void function cannot return a scalar value"); }
            return [self.ast.returned(self.converted(self.expression(children[0]), self.return_type))];
        }
        if kind == "if" {
            condition = self.expression(children[0]);
            if condition.typ.category == "void" { self.fail(nd, "Void condition"); }
            body = self.body(children[1]);
            alternative = self.body(children[2]) if len(children) == 3 else None;
            self.ast.origin = nd;
            return [self.ast.branch(self.ast.call("bool", [condition.expr]), body, alternative)];
        }
        if kind in ["while", "for", "do_while"] {
            self.scopes.append({});
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
                if condition.typ.category == "void" { self.fail(nd, "Void loop condition"); }
                self.continue_actions.append(step);
                try { body_stmts = self.body(body_node); }
                finally { self.continue_actions.pop(); }
                self.ast.origin = nd;
                guard = self.ast.boolean(True) if kind == "do_while" else self.ast.call("bool", [condition.expr]);
                return initial + [self.ast.loop(guard, body_stmts + step)];
            } finally { self.scopes.pop(); }
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

    def function_node(nd: CNode) -> uni.Ability {
        parts = nd.operands; decl = parts[1]; fn = self.functions[self.name_of(decl)];
        parameters = self.operators(decl)[0].operands[1:];
        self.scopes = [{}]; self.return_type = fn.returns;
        params: list[uni.ParamVar] = [];
        for i in range(len(fn.parameters)) {
            parameter = parameters[i]; name = self.name_of(parameter.operands[1]);
            if not name { self.fail(parameter, "Function definition requires named parameters"); }
            if name in self.scopes[0] { self.fail(parameter, "Duplicate parameter " + name); }
            binding = CBinding(self.fresh(name), fn.parameters[i], self.readonly(parameter.operands[0]));
            self.scopes[0][name] = binding; params.append(self.ast.parameter(binding.name, binding.typ.jac));
        }
        # The function's outermost block shares the parameter scope in C.
        lines: list[uni.CodeBlockStmt] = [];
        for child in parts[2].operands {
            lines.extend(self.local_declaration(child) if child.kind == "declaration" else self.statement(child));
        }
        if fn.returns.category != "void" and (not parts[2].operands or parts[2].operands[-1].kind != "return") {
            lines.append(self.ast.returned(self.zero(fn.returns)));
        }
        self.ast.origin = nd;
        return self.ast.function("c_" + fn.name, params, fn.returns.jac, lines);
    }

    def global_nodes(nd: CNode) -> list[uni.ElementStmt] {
        parts = nd.operands; spec = parts[0]; lines: list[uni.ElementStmt] = [];
        if "typedef" in self.storage(spec) {
            for item in parts[1:] {
                name = self.name_of(item.operands[0]);
                if name not in self.emitted_aliases {
                    self.emitted_aliases.add(name);
                    lines.append(self.ast.alias("c_" + name, self.aliases[name].jac));
                }
            }
            return lines;
        }
        self.scopes = [];
        for item in parts[1:] {
            children = item.operands; decl = children[0]; name = self.name_of(decl);
            if self.operators(decl) { continue; }
            binding = self.globals[name]; typ = binding.typ;
            if len(children) > 1 {
                value = self.expression(children[1]);
                if not value.constant { self.fail(item, "Global initializer must be a supported integer constant expression"); }
                initializer = self.converted(value, typ);
            } else { initializer = self.zero(typ); }
            lines.append(self.ast.global_var(binding.name, typ.jac, initializer));
        }
        return lines;
    }

    def helper_nodes -> list[uni.ElementStmt] {
        nodes: list[uni.ElementStmt] = [];
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
            nodes.append(self.ast.function(name, params, typ, body));
        }
        return nodes;
    }

    def lower(parsed: CParseResult) -> CLowerResult {
        self.result = CLowerResult();
        self.ctx.errors_had = self.result.errors_had;
        self.ctx.warnings_had = self.result.warnings_had;
        self.aliases = {}; self.emitted_aliases = set(); self.globals = {}; self.functions = {}; self.scopes = [];
        self.helpers = {}; self.serial = 0; self.continue_actions = [];
        for diagnostic in parsed.diagnostics {
            alert = frontend_alert(diagnostic, CLowerPass);
            if diagnostic.severity == "error" { self.result.errors_had.append(alert); }
            else { self.result.warnings_had.append(alert); }
        }
        if self.config.abi not in ["lp64", "llp64", "ilp32"] {
            self.report_error(parsed.tree, "Unknown ABI: " + self.config.abi); return self.result;
        }
        if not self.result.ok { return self.result; }
        declarations = [n for n in parsed.tree.operands if n.kind != "preprocessing_unit"];
        for nd in declarations {
            self.current = nd; self.ast.origin = nd;
            try { self.collect(nd); }
            except ValueError as error { self.report_error(self.current or nd, str(error)); }
        }
        if not self.result.ok { return self.result; }
        body: list[uni.ElementStmt] = [];
        for nd in declarations {
            self.current = nd; self.ast.origin = nd;
            try {
                if nd.kind == "function_definition" { body.append(self.function_node(nd)); }
                else { body.extend(self.global_nodes(nd)); }
            } except ValueError as error { self.report_error(self.current or nd, str(error)); }
        }
        if self.result.ok {
            self.ast.origin = parsed.tree;
            self.result.module = self.ast.module(self.helper_nodes() + body);
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
