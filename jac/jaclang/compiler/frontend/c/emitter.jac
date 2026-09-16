"""Emit ordinary Jac source for the supported scalar C subset.

No partial module is returned on errors. Unsupported C semantics are diagnosed
at their source node rather than approximated with managed Jac operations.
"""
import from .parser { CParser, CParseResult, parse_c }
import from .preprocessor { CConfig }
import from .tokens { CToken, CDiagnostic }
import from jaclang.compiler.frontend.unitree_c { CNode }

obj CEmitConfig {
    has abi: str = "lp64",
        char_signed: bool = True;
}

obj CEmitResult {
    has source: str = "",
        diagnostics: list[CDiagnostic] = [];
    has ok: bool {
        getter { return not any(d.severity == "error" for d in self.diagnostics); }
    }
}

obj CScalar {
    has width: int = 32,
        signed: bool = True,
        rank: int = 3,
        category: str = "integer";
    has jac: str {
        getter {
            if self.category == "void" { return "None"; }
            if self.category == "bool" { return "bool"; }
            return ("i" if self.signed else "u") + str(self.width);
        }
    }
}

obj CValue {
    has code: str,
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

obj CJacEmitter {
    has config: CEmitConfig,
        result: CEmitResult = CEmitResult(),
        aliases: dict[str, CScalar] = {},
        emitted_aliases: set[str] = set(),
        globals: dict[str, CBinding] = {},
        functions: dict[str, CFunction] = {},
        scopes: list[dict[str, CBinding]] = [],
        serial: int = 0,
        current: CNode | None = None,
        return_type: CScalar = CScalar(category="void"),
        # Each loop supplies the statements a continue must execute first.
        continue_actions: list[list[str]] = [],
        helpers: dict[str, CScalar] = {};

    def fail(nd: CNode, message: str) {
        self.current = nd;
        raise ValueError(message);
    }

    def diagnostic(nd: CNode, message: str) -> CDiagnostic {
        (first, _) = nd.resolve_tok_range();
        token = CToken(kind="emission", text=first.value, source=first.orig_src,
            start=first.pos_start, end=first.pos_end, line=first.line_no,
            column=first.c_start, end_line=first.end_line, end_column=first.c_end);
        return CDiagnostic("c2jac: " + message, token);
    }

    def compatible(a: CScalar, b: CScalar) -> bool {
        return a.width == b.width and a.signed == b.signed and a.rank == b.rank and a.category == b.category;
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
            if not self.compatible(previous.returns, fn.returns) or len(previous.parameters) != len(fn.parameters) {
                self.fail(decl, "Conflicting function declarations for " + fn.name);
            }
            for i in range(len(fn.parameters)) {
                if not self.compatible(previous.parameters[i], fn.parameters[i]) { self.fail(decl, "Conflicting parameter type for " + fn.name); }
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
                if previous is not None and not self.compatible(previous, typ) { self.fail(decl, "Conflicting typedef " + name); }
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

    def promote(typ: CScalar) -> CScalar {
        return CScalar() if typ.rank < 3 else typ;
    }

    def common(a: CScalar, b: CScalar) -> CScalar {
        left = self.promote(a); right = self.promote(b);
        if left.signed == right.signed { return left if left.rank >= right.rank else right; }
        unsigned = right if left.signed else left; signed = left if left.signed else right;
        if unsigned.rank >= signed.rank { return unsigned; }
        if signed.width > unsigned.width { return signed; }
        return CScalar(signed.width, False, signed.rank);
    }

    def converted(value: CValue, typ: CScalar) -> str {
        if typ.category == "bool" { return "bool(" + value.code + ")"; }
        if typ.category == "void" or value.typ.category == "void" { raise ValueError("A void expression cannot be converted to a value"); }
        if self.compatible(value.typ, typ) { return value.code; }
        return typ.jac + ".wrap(" + value.code + ")";
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
                    return CValue(typ.jac + "(" + str(number) + ")", typ, True);
                }
            }
        }
        self.fail(nd, "Integer literal exceeds the selected C data model");
        return CValue("", CScalar());
    }

    def binary(op: str, left: CValue, right: CValue, nd: CNode) -> CValue {
        if left.typ.category == "void" or right.typ.category == "void" { self.fail(nd, "Void operand in integer expression"); }
        constant = left.constant and right.constant;
        if op in ["&&", "||"] {
            join = " and " if op == "&&" else " or ";
            return CValue("i32(bool(" + left.code + ")" + join + "bool(" + right.code + "))", CScalar(), constant);
        }
        typ = self.promote(left.typ) if op in ["<<", ">>"] else self.common(left.typ, right.typ);
        a = self.converted(left, typ);
        b = self.converted(right, self.promote(right.typ) if op in ["<<", ">>"] else typ);
        if op in ["==", "!=", "<", ">", "<=", ">="] {
            return CValue("i32(" + a + " " + op + " " + b + ")", CScalar(), constant);
        }
        wrapping = {"+": "wrapping_add", "-": "wrapping_sub", "*": "wrapping_mul", "<<": "wrapping_shl"};
        if not typ.signed and op in wrapping { code = wrapping[op] + "(" + a + ", " + b + ")"; }
        elif op in ["/", "%"] and typ.signed {
            helper = "_c2jac_" + ("div_" if op == "/" else "rem_") + typ.jac;
            self.helpers[helper] = typ;
            if op == "%" { self.helpers["_c2jac_div_" + typ.jac] = typ; }
            code = helper + "(" + a + ", " + b + ")";
        } else { code = "(" + a + " " + ("//" if op == "/" else op) + " " + b + ")"; }
        return CValue(code, typ, constant);
    }

    def expression(nd: CNode) -> CValue {
        self.current = nd; children = nd.operands; kind = nd.kind;
        if kind == "number" { return self.integer(nd); }
        if kind == "identifier" {
            bound = self.binding(nd); return CValue(bound.name, bound.typ);
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
            if op == "!" { return CValue("i32(not bool(" + value.code + "))", CScalar(), value.constant); }
            typ = self.promote(value.typ); code = self.converted(value, typ);
            if op == "-" and not typ.signed { code = "wrapping_neg(" + code + ")"; }
            else { code = "(" + op + code + ")"; }
            return CValue(code, typ, value.constant);
        }
        if kind == "binary" { return self.binary(nd.value, self.expression(children[0]), self.expression(children[1]), nd); }
        if kind == "conditional" {
            condition = self.expression(children[0]); yes = self.expression(children[1]); no = self.expression(children[2]);
            if condition.typ.category == "void" or yes.typ.category == "void" or no.typ.category == "void" { self.fail(nd, "Void conditional expressions are not emitted yet"); }
            typ = self.common(yes.typ, no.typ);
            return CValue("(" + self.converted(yes, typ) + " if bool(" + condition.code + ") else " + self.converted(no, typ) + ")", typ, condition.constant and yes.constant and no.constant);
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
            args: list[str] = [];
            for i in range(len(fn.parameters)) { args.append(self.converted(self.expression(children[i + 1]), fn.parameters[i])); }
            return CValue("c_" + fn.name + "(" + ", ".join(args) + ")", fn.returns);
        }
        if kind == "sizeof_type" {
            typ = self.variable(children[0].operands[0], children[0].operands[1]);
            size_type = CScalar(32 if self.config.abi == "ilp32" else 64, False, 3 if self.config.abi == "ilp32" else (4 if self.config.abi == "lp64" else 5));
            return CValue(size_type.jac + "(" + str(typ.width // 8) + ")", size_type, True);
        }
        self.fail(nd, "Expression '" + kind + "' requires further source lowering");
        return CValue("", CScalar());
    }

    def effect(nd: CNode) -> list[str] {
        children = nd.operands;
        if nd.kind == "omitted" { return []; }
        if nd.kind == "parenthesized" { return self.effect(children[0]); }
        if nd.kind == "comma" { return self.effect(children[0]) + self.effect(children[1]); }
        if nd.kind == "assignment" or (nd.kind in ["unary", "postfix"] and nd.value in ["++", "--"]) {
            bound = self.binding(children[0]);
            if bound.readonly { self.fail(nd, "Assignment to const object"); }
            if nd.kind == "assignment" {
                value = self.expression(children[1]);
                if nd.value != "=" { value = self.binary(nd.value[:-1], CValue(bound.name, bound.typ), value, nd); }
            } else { value = self.binary("+" if nd.value == "++" else "-", CValue(bound.name, bound.typ), CValue("i32(1)", CScalar(), True), nd); }
            return [bound.name + " = " + self.converted(value, bound.typ) + ";"];
        }
        value = self.expression(nd);
        return [value.code + ";"];
    }

    def fresh(name: str) -> str {
        self.serial += 1;
        return "_c2jac_local_" + str(self.serial) + "_" + name;
    }

    def local_declaration(nd: CNode) -> list[str] {
        children = nd.operands; spec = children[0]; storage = self.storage(spec);
        if any(s != "auto" and s != "register" for s in storage) { self.fail(nd, "Local typedef/static/extern declarations require further lowering"); }
        lines: list[str] = [];
        for item in children[1:] {
            parts = item.operands; decl = parts[0]; name = self.name_of(decl); typ = self.variable(spec, decl);
            if name in self.scopes[-1] { self.fail(decl, "Duplicate local declaration " + name); }
            binding = CBinding(self.fresh(name), typ, self.readonly(spec)); self.scopes[-1][name] = binding;
            # Reading an uninitialized C scalar has no defined value. Initializing
            # its Jac storage does not change defined executions of this subset.
            value = self.converted(self.expression(parts[1]), typ) if len(parts) > 1 else ("False" if typ.category == "bool" else typ.jac + "(0)");
            lines.append(binding.name + ": " + typ.jac + " = " + value + ";");
        }
        return lines;
    }

    def indent(lines: list[str]) -> list[str] { return ["    " + line for line in lines]; }

    def body(nd: CNode) -> list[str] {
        if nd.kind == "compound" {
            self.scopes.append({}); lines: list[str] = [];
            try {
                for child in nd.operands {
                    lines.extend(self.local_declaration(child) if child.kind == "declaration" else self.statement(child));
                }
            } finally { self.scopes.pop(); }
            return lines;
        }
        return self.statement(nd);
    }

    def statement(nd: CNode) -> list[str] {
        self.current = nd; children = nd.operands; kind = nd.kind;
        if kind == "empty" { return []; }
        if kind == "compound" { return ["if True {"] + self.indent(self.body(nd)) + ["}"]; }
        if kind == "expression" { return self.effect(children[0]); }
        if kind == "return" {
            if not children {
                if self.return_type.category != "void" { self.fail(nd, "Non-void return needs a value"); }
                return ["return;"];
            }
            if self.return_type.category == "void" { self.fail(nd, "Void function cannot return a scalar value"); }
            return ["return " + self.converted(self.expression(children[0]), self.return_type) + ";"];
        }
        if kind == "if" {
            condition = self.expression(children[0]);
            if condition.typ.category == "void" { self.fail(nd, "Void condition"); }
            lines = ["if bool(" + condition.code + ") {"] + self.indent(self.body(children[1])) + ["}"];
            if len(children) == 3 { lines.extend(["else {"] + self.indent(self.body(children[2])) + ["}"]); }
            return lines;
        }
        if kind in ["while", "for", "do_while"] {
            self.scopes.append({});
            try {
                initial: list[str] = []; step: list[str] = [];
                if kind == "for" {
                    initial = self.local_declaration(children[0]) if children[0].kind == "declaration" else self.effect(children[0]);
                    condition = CValue("True", CScalar(category="bool")) if children[1].kind == "omitted" else self.expression(children[1]);
                    step = self.effect(children[2]); body_node = children[3];
                } elif kind == "while" { condition = self.expression(children[0]); body_node = children[1]; }
                else {
                    body_node = children[0]; condition = self.expression(children[1]);
                    step = ["if not bool(" + condition.code + ") { break; }"];
                }
                if condition.typ.category == "void" { self.fail(nd, "Void loop condition"); }
                self.continue_actions.append(step);
                try { body_lines = self.body(body_node); }
                finally { self.continue_actions.pop(); }
                head = "while True {" if kind == "do_while" else "while bool(" + condition.code + ") {";
                return initial + [head] + self.indent(body_lines + step) + ["}"];
            } finally { self.scopes.pop(); }
        }
        if kind in ["break", "continue"] {
            if not self.continue_actions { self.fail(nd, kind + " outside a supported loop"); }
            return (self.continue_actions[-1] if kind == "continue" else []) + [kind + ";"];
        }
        self.fail(nd, "Statement '" + kind + "' has no source lowering yet");
        return [];
    }

    def function_source(nd: CNode) -> list[str] {
        parts = nd.operands; decl = parts[1]; fn = self.functions[self.name_of(decl)];
        parameters = self.operators(decl)[0].operands[1:];
        self.scopes = [{}]; self.return_type = fn.returns;
        params: list[str] = [];
        for i in range(len(fn.parameters)) {
            parameter = parameters[i]; name = self.name_of(parameter.operands[1]);
            if not name { self.fail(parameter, "Function definition requires named parameters"); }
            if name in self.scopes[0] { self.fail(parameter, "Duplicate parameter " + name); }
            binding = CBinding(self.fresh(name), fn.parameters[i], self.readonly(parameter.operands[0]));
            self.scopes[0][name] = binding; params.append(binding.name + ": " + binding.typ.jac);
        }
        # The function's outermost block shares the parameter scope in C.
        lines: list[str] = [];
        for child in parts[2].operands {
            lines.extend(self.local_declaration(child) if child.kind == "declaration" else self.statement(child));
        }
        if fn.returns.category != "void" and (not parts[2].operands or parts[2].operands[-1].kind != "return") {
            lines.append("return " + ("False" if fn.returns.category == "bool" else fn.returns.jac + "(0)") + ";");
        }
        return ["def c_" + fn.name + "(" + ", ".join(params) + ") -> " + fn.returns.jac + " {"] + self.indent(lines) + ["}", ""];
    }

    def global_source(nd: CNode) -> list[str] {
        parts = nd.operands; spec = parts[0]; lines: list[str] = [];
        if "typedef" in self.storage(spec) {
            for item in parts[1:] {
                name = self.name_of(item.operands[0]);
                if name not in self.emitted_aliases {
                    self.emitted_aliases.add(name);
                    lines.append("type c_" + name + " = " + self.aliases[name].jac + ";");
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
            } else { initializer = "False" if typ.category == "bool" else typ.jac + "(0)"; }
            lines.append("glob " + binding.name + ": " + typ.jac + " = " + initializer + ";");
        }
        return lines;
    }

    def helper_source -> list[str] {
        lines: list[str] = [];
        for name in sorted(self.helpers) {
            typ = self.helpers[name].jac;
            lines.append("def " + name + "(a: " + typ + ", b: " + typ + ") -> " + typ + " {");
            if "_rem_" in name { lines.append("    return a - _c2jac_div_" + typ + "(a, b) * b;"); }
            else {
                lines.append("    q: " + typ + " = a // b;");
                lines.append("    if ((a < 0) != (b < 0)) and ((a % b) != 0) { q = q + " + typ + "(1); }");
                lines.append("    return q;");
            }
            lines.extend(["}", ""]);
        }
        return lines;
    }

    def emit(parsed: CParseResult) -> CEmitResult {
        self.result = CEmitResult(diagnostics=list(parsed.diagnostics));
        self.aliases = {}; self.emitted_aliases = set(); self.globals = {}; self.functions = {}; self.scopes = [];
        self.helpers = {}; self.serial = 0; self.continue_actions = [];
        if self.config.abi not in ["lp64", "llp64", "ilp32"] {
            self.result.diagnostics.append(self.diagnostic(parsed.tree, "Unknown ABI: " + self.config.abi)); return self.result;
        }
        if not parsed.ok { return self.result; }
        declarations = [n for n in parsed.tree.operands if n.kind != "preprocessing_unit"];
        for nd in declarations {
            self.current = nd;
            try { self.collect(nd); }
            except ValueError as error { self.result.diagnostics.append(self.diagnostic(self.current or nd, str(error))); }
        }
        if not self.result.ok { return self.result; }
        lines: list[str] = [];
        for nd in declarations {
            self.current = nd;
            try { lines.extend(self.function_source(nd) if nd.kind == "function_definition" else self.global_source(nd)); }
            except ValueError as error { self.result.diagnostics.append(self.diagnostic(self.current or nd, str(error))); }
        }
        if self.result.ok {
            header = ["# Generated by jac tool c2jac; C data model: " + self.config.abi + ".",
                "# Global C names use the c_ prefix; preprocessing is already resolved.", ""];
            self.result.source = "\n".join(header + self.helper_source() + lines).rstrip() + "\n";
        }
        return self.result;
    }
}

"""Parse and emit without compiling, executing, or writing the generated Jac."""
def emit_c(source: str, file_path: str = "<c-input>",
           preprocess: CConfig | None = None, config: CEmitConfig | None = None) -> CEmitResult {
    parsed = parse_c(source, file_path, preprocess);
    return CJacEmitter(config or CEmitConfig()).emit(parsed);
}
