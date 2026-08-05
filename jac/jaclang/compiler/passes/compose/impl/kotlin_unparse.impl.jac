import from jaclang.compiler.passes.compose { kotlin_ast as kt }

glob _KT_HARD_KEYWORDS: set[str] = {
         'is',
         'in',
         'object',
         'fun',
         'val',
         'var',
         'when',
         'class',
         'this',
         'typeof',
         'as'
     };

impl escape_kotlin_string(value: str) -> str {
    return value.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace(
        '$', '\\$'
    );
}

impl kt_to_source(nd: (kt.KtNode | None), indent: str = '    ') -> str {
    generator = KotlinCodeGenerator(indent=indent);
    return generator.generate(nd);
}

impl KotlinCodeGenerator.init(indent: str = '    ') -> None {
    self.indent_str = indent;
    self.indent_level = 0;
}

impl KotlinCodeGenerator.indent -> str {
    return (self.indent_str * self.indent_level);
}

impl KotlinCodeGenerator._escape_string(value: str) -> str {
    return escape_kotlin_string(value);
}

impl KotlinCodeGenerator._escape_ident(name: str) -> str {
    if name in _KT_HARD_KEYWORDS {
        return f"`{name}`";
    }
    return name;
}

impl KotlinCodeGenerator._gen_body(stmts: list[kt.KtNode]) -> str {
    if not stmts {
        return '';
    }
    parts: list[str] = [];
    for stmt in stmts {
        parts.append(f"{self.indent()}{self.generate(stmt)}");
    }
    return '\n'.join(parts);
}

impl KotlinCodeGenerator.generate(nd: (kt.KtNode | None)) -> str {
    import from jaclang.jac0core.helpers { pascal_to_snake }
    if (nd is None) {
        return '';
    }
    node_type = nd.type;
    method_name = f"gen_{pascal_to_snake(node_type)}";
    method = getattr(self, method_name, None);
    if method {
        return method(nd);
    }
    return f"/* Unsupported node type: {node_type} */";
}

impl KotlinCodeGenerator.gen_kt_identifier(nd: kt.KtIdentifier) -> str {
    return self._escape_ident(nd.name);
}

impl KotlinCodeGenerator.gen_kt_literal(nd: kt.KtLiteral) -> str {
    if isinstance(nd.value, str) {
        return f'"{self._escape_string(nd.value)}"';
    } elif (nd.value is None) {
        return 'null';
    } elif isinstance(nd.value, bool) {
        return 'true' if nd.value else 'false';
    } else {
        return str(nd.value);
    }
}

impl KotlinCodeGenerator.gen_kt_string_template(nd: kt.KtStringTemplate) -> str {
    parts: list[str] = [];
    for part in nd.parts {
        if isinstance(part, str) {
            parts.append(self._escape_string(part));
        } else {
            parts.append(f"${{{self.generate(part)}}}");
        }
    }
    inner = ''.join(parts);
    return f'"{inner}"';
}

impl KotlinCodeGenerator.gen_kt_this(nd: kt.KtThis) -> str {
    return 'this';
}

impl KotlinCodeGenerator.gen_kt_member_access(nd: kt.KtMemberAccess) -> str {
    receiver = self.generate(nd.object) if nd.object else '';
    prop = self.generate(nd.property);
    safe = '?.' if nd.safe else '';
    if nd.computed {
        return f"{receiver}{safe}[{prop}]";
    }
    if nd.safe {
        return f"{receiver}{safe}{prop}";
    }
    if receiver {
        return f"{receiver}.{prop}";
    }
    return prop;
}

impl KotlinCodeGenerator.gen_kt_call(nd: kt.KtCall) -> str {
    callee = self.generate(nd.callee);
    arg_parts: list[str] = [];
    for arg in nd.args {
        arg_parts.append(self.generate(arg));
    }
    for na in nd.named_args {
        arg_parts.append(f"{na.name} = {self.generate(na.value)}");
    }
    args_str = ', '.join(arg_parts);
    if nd.safe {
        result = f"{callee}?.invoke({args_str})";
    } else {
        result = f"{callee}({args_str})";
    }
    if nd.trailing_lambda {
        result = f"{result} {self.generate(nd.trailing_lambda)}";
    }
    return result;
}

impl KotlinCodeGenerator.gen_kt_binary(nd: kt.KtBinary) -> str {
    left = self.generate(nd.left);
    right = self.generate(nd.right);
    return f"{left} {nd.operator} {right}";
}

impl KotlinCodeGenerator.gen_kt_unary(nd: kt.KtUnary) -> str {
    arg = self.generate(nd.argument);
    if nd.prefix {
        return f"{nd.operator}{arg}";
    }
    return f"{arg}{nd.operator}";
}

impl KotlinCodeGenerator.gen_kt_conditional(nd: kt.KtConditional) -> str {
    `test = self.generate(nd.test);
    consequent = self.generate(nd.consequent);
    alternate = self.generate(nd.alternate);
    return f"if ({test}) {consequent} else {alternate}";
}

impl KotlinCodeGenerator.gen_kt_assignment(nd: kt.KtAssignment) -> str {
    left = self.generate(nd.left);
    right = self.generate(nd.right);
    return f"{left} {nd.operator} {right}";
}

impl KotlinCodeGenerator.gen_kt_lambda(nd: kt.KtLambda) -> str {
    arrow = f"{', '.join(nd.params)} -> " if nd.params else "";
    if nd.expression_body {
        body = self.generate(nd.expression_body);
        return f"{{ {arrow}{body} }}";
    }
    self.indent_level += 1;
    body = self._gen_body(nd.body);
    self.indent_level -= 1;
    if nd.params {
        return f"{{ {arrow}\n{body}\n{self.indent()}}}";
    }
    return f"{{\n{body}\n{self.indent()}}}";
}

impl KotlinCodeGenerator.gen_kt_list_literal(nd: kt.KtListLiteral) -> str {
    elements = ', '.join(self.generate(e) for e in nd.elements);
    return f"listOf({elements})";
}

impl KotlinCodeGenerator.gen_kt_map_literal(nd: kt.KtMapLiteral) -> str {
    entries: list[str] = [];
    for e in nd.entries {
        pair: any = e;
        key = self.generate(pair[0]);
        value = self.generate(pair[1]);
        entries.append(f"{key} to {value}");
    }
    return f"mapOf({', '.join(entries)})";
}

impl KotlinCodeGenerator.gen_kt_spread(nd: kt.KtSpread) -> str {
    return f"*{self.generate(nd.argument)}";
}

impl KotlinCodeGenerator.gen_kt_raw(nd: kt.KtRaw) -> str {
    return nd.code;
}

impl KotlinCodeGenerator.gen_kt_expr_stmt(nd: kt.KtExprStmt) -> str {
    return self.generate(nd.expression);
}

impl KotlinCodeGenerator.gen_kt_block(nd: kt.KtBlock) -> str {
    if not nd.body {
        return '{}';
    }
    self.indent_level += 1;
    body = self._gen_body(nd.body);
    self.indent_level -= 1;
    return f"{{\n{body}\n{self.indent()}}}";
}

impl KotlinCodeGenerator.gen_kt_property(nd: kt.KtProperty) -> str {
    lines: list[str] = [];
    for ann in nd.annotations {
        lines.append(f"{self.indent()}@{ann}");
    }
    kw = 'var' if nd.mutable else 'val';
    name_part = nd.name;
    if nd.type_ann {
        name_part = f"{name_part}: {nd.type_ann}";
    }
    if nd.delegate {
        decl = f"{kw} {name_part} by {self.generate(nd.delegate)}";
    } elif nd.`init {
        init_val = self.generate(nd.`init);
        decl = f"{kw} {name_part} = {init_val}";
    } else {
        decl = f"{kw} {name_part}";
    }
    lines.append(f"{self.indent()}{decl}");
    return '\n'.join(lines);
}

impl KotlinCodeGenerator.gen_kt_if(nd: kt.KtIf) -> str {
    `test = self.generate(nd.test);
    result = f"{self.indent()}if ({test}) ";
    if len(nd.consequent) == 1 and isinstance(nd.consequent[0], kt.KtBlock) {
        result += self.generate(nd.consequent[0]);
    } elif nd.consequent {
        self.indent_level += 1;
        body = self._gen_body(nd.consequent);
        self.indent_level -= 1;
        result += f"{{\n{body}\n{self.indent()}}}";
    } else {
        result += '{}';
    }
    if nd.alternate {
        if len(nd.alternate) == 1 and isinstance(nd.alternate[0], kt.KtBlock) {
            result += f" else {self.generate(nd.alternate[0])}";
        } elif nd.alternate {
            self.indent_level += 1;
            body = self._gen_body(nd.alternate);
            self.indent_level -= 1;
            result += f" else {{\n{body}\n{self.indent()}}}";
        }
    }
    return result;
}

impl KotlinCodeGenerator.gen_kt_for(nd: kt.KtFor) -> str {
    iterable = self.generate(nd.iterable);
    self.indent_level += 1;
    body = self._gen_body(nd.body);
    self.indent_level -= 1;
    return f"{self.indent()}for ({nd.variable} in {iterable}) {{\n{body}\n{self.indent()}}}";
}

impl KotlinCodeGenerator.gen_kt_while(nd: kt.KtWhile) -> str {
    `test = self.generate(nd.test);
    self.indent_level += 1;
    body = self._gen_body(nd.body);
    self.indent_level -= 1;
    return f"{self.indent()}while ({test}) {{\n{body}\n{self.indent()}}}";
}

impl KotlinCodeGenerator.gen_kt_return(nd: kt.KtReturn) -> str {
    label_str = f"@{nd.label}" if nd.label else '';
    if nd.argument {
        return f"{self.indent()}return{label_str} {self.generate(nd.argument)}";
    }
    return f"{self.indent()}return{label_str}";
}

impl KotlinCodeGenerator.gen_kt_try(nd: kt.KtTry) -> str {
    self.indent_level += 1;
    try_body = self._gen_body(nd.try_body);
    self.indent_level -= 1;
    result = f"{self.indent()}try {{\n{try_body}\n{self.indent()}}}";
    if nd.catch_body {
        self.indent_level += 1;
        catch_body = self._gen_body(nd.catch_body);
        self.indent_level -= 1;
        result += (
            f" catch ({nd.catch_param}: {nd.catch_type}) {{\n"
            f"{catch_body}\n{self.indent()}}}"
        );
    }
    if nd.finally_body {
        self.indent_level += 1;
        finally_body = self._gen_body(nd.finally_body);
        self.indent_level -= 1;
        result += f" finally {{\n{finally_body}\n{self.indent()}}}";
    }
    return result;
}

impl KotlinCodeGenerator.gen_kt_throw(nd: kt.KtThrow) -> str {
    return f"{self.indent()}throw {self.generate(nd.argument)}";
}

impl KotlinCodeGenerator.gen_kt_break(nd: kt.KtBreak) -> str {
    return f"{self.indent()}break";
}

impl KotlinCodeGenerator.gen_kt_continue(nd: kt.KtContinue) -> str {
    return f"{self.indent()}continue";
}

impl KotlinCodeGenerator.gen_kt_when(nd: kt.KtWhen) -> str {
    subj_str = f"({self.generate(nd.subject)})" if nd.subject else '';
    entry_parts: list[str] = [];
    for entry in nd.entries {
        if entry.test is None {
            test_str = 'else';
        } else {
            test_str = self.generate(entry.test);
        }
        self.indent_level += 1;
        body = self._gen_body(entry.body);
        self.indent_level -= 1;
        entry_parts.append(
            f"{self.indent()}{test_str} -> {{\n{body}\n{self.indent()}}}"
        );
    }
    entries = '\n'.join(entry_parts);
    return f"{self.indent()}when {subj_str} {{\n{entries}\n{self.indent()}}}";
}

impl KotlinCodeGenerator.gen_kt_function(nd: kt.KtFunction) -> str {
    lines: list[str] = [];
    for ann in nd.annotations {
        lines.append(f"{self.indent()}@{ann}");
    }
    mods: list[str] = list(nd.modifiers);
    if nd.is_suspend and 'suspend' not in mods {
        mods.insert(0, 'suspend');
    }
    mod_str = ' '.join(mods);
    if mod_str {
        mod_str = f"{mod_str} ";
    }
    param_strs: list[str] = [];
    for p in nd.params {
        ps = f"{p.name}: {p.type_ann}" if p.type_ann else p.name;
        if p.default {
            ps = f"{ps} = {self.generate(p.default)}";
        }
        param_strs.append(ps);
    }
    params = ', '.join(param_strs);
    ret = f": {nd.return_type}" if nd.return_type else '';
    sig = f"{mod_str}fun {nd.name}({params}){ret}";
    if nd.is_expression_body and nd.expression_body {
        lines.append(f"{self.indent()}{sig} = {self.generate(nd.expression_body)}");
    } else {
        self.indent_level += 1;
        body = self._gen_body(nd.body);
        self.indent_level -= 1;
        lines.append(f"{self.indent()}{sig} {{\n{body}\n{self.indent()}}}");
    }
    return '\n'.join(lines);
}

impl KotlinCodeGenerator.gen_kt_class(nd: kt.KtClass) -> str {
    lines: list[str] = [];
    for ann in nd.annotations {
        lines.append(f"{self.indent()}@{ann}");
    }
    mod_str = ' '.join(nd.modifiers);
    if mod_str {
        mod_str = f"{mod_str} ";
    }
    param_strs: list[str] = [];
    for p in nd.primary_params {
        ps = f"{p.name}: {p.type_ann}" if p.type_ann else p.name;
        if p.default {
            ps = f"{ps} = {self.generate(p.default)}";
        }
        param_strs.append(ps);
    }
    params = f"({', '.join(param_strs)})" if param_strs else '';
    super_str = f" : {', '.join(nd.super_types)}" if nd.super_types else '';
    header = f"{self.indent()}{mod_str}{nd.kind} {nd.name}{params}{super_str}";
    if nd.body {
        self.indent_level += 1;
        body = self._gen_body(nd.body);
        self.indent_level -= 1;
        lines.append(f"{header} {{\n{body}\n{self.indent()}}}");
    } else {
        lines.append(header);
    }
    return '\n'.join(lines);
}

impl KotlinCodeGenerator.gen_kt_object(nd: kt.KtObject) -> str {
    lines: list[str] = [];
    for ann in nd.annotations {
        lines.append(f"{self.indent()}@{ann}");
    }
    header = f"{self.indent()}object {nd.name}";
    if nd.body {
        self.indent_level += 1;
        body = self._gen_body(nd.body);
        self.indent_level -= 1;
        lines.append(f"{header} {{\n{body}\n{self.indent()}}}");
    } else {
        lines.append(header);
    }
    return '\n'.join(lines);
}

impl KotlinCodeGenerator.gen_kt_import(nd: kt.KtImport) -> str {
    if nd.alias {
        return f"import {nd.path} as {nd.alias}";
    }
    return f"import {nd.path}";
}

impl KotlinCodeGenerator.gen_kt_file(nd: kt.KtFile) -> str {
    parts: list[str] = [];
    if nd.package {
        pkg = nd.package;
        parts.append(f"package {pkg}");
    }
    for imp in nd.imports {
        parts.append(self.generate(imp));
    }
    if nd.package or nd.imports {
        parts.append('');
    }
    decls: list[str] = [];
    for decl in nd.declarations {
        decls.append(self.generate(decl));
    }
    if decls {
        parts.append('\n\n'.join(decls));
    }
    return '\n'.join(parts);
}

impl KotlinCodeGenerator.gen_kt_modifier_chain(nd: kt.KtModifierChain) -> str {
    if not nd.calls {
        return 'Modifier';
    }
    parts: list[str] = ['Modifier'];
    for call in nd.calls {
        arg_parts: list[str] = [];
        for arg in call.args {
            arg_parts.append(self.generate(arg));
        }
        for na in call.named_args {
            arg_parts.append(f"{na.name} = {self.generate(na.value)}");
        }
        args_str = ', '.join(arg_parts);
        parts.append(f"{call.name}({args_str})");
    }
    return '.'.join(parts);
}

impl KotlinCodeGenerator.gen_kt_composable_call(nd: kt.KtComposableCall) -> str {
    arg_parts: list[str] = [];
    for na in nd.args {
        if isinstance(na, kt.KtNamedArg) {
            arg_parts.append(f"{na.name} = {self.generate(na.value)}");
        } else {
            item: any = na;
            arg_parts.append(self.generate(item));
        }
    }
    args_str = ', '.join(arg_parts);
    base = f"{nd.name}({args_str})";
    if nd.content {
        self.indent_level += 1;
        body = self._gen_body(nd.content);
        self.indent_level -= 1;
        return f"{base} {{\n{body}\n{self.indent()}}}";
    }
    return base;
}
