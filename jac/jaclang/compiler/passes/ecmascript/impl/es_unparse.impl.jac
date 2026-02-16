"""Convert an ESTree node to JavaScript code."""

impl es_to_js(nd: (es.Node | None), indent: str = '  ') -> str {
    generator = JSCodeGenerator(indent=indent);
    return generator.generate(nd);
}

"""Generate export all declaration."""
impl JSCodeGenerator.gen_export_all_declaration(nd: es.ExportAllDeclaration) -> str {
    source = self.generate(nd.source);
    if nd.exported {
        exported = self.generate(nd.exported);
        return f"{self.indent()}export * as {exported} from {source};";
    }
    return f"{self.indent()}export * from {source};";
}

"""Generate export default declaration."""
impl JSCodeGenerator.gen_export_default_declaration(
    nd: es.ExportDefaultDeclaration
) -> str {
    return f"{self.indent()}export default {self.generate(nd.declaration)}";
}

"""Generate export specifier."""
impl JSCodeGenerator.gen_export_specifier(nd: es.ExportSpecifier) -> str {
    local = self.generate(nd.local);
    exported = self.generate(nd.exported);
    if (local != exported) {
        return f"{local} as {exported}";
    }
    return local;
}

"""Generate export named declaration."""
impl JSCodeGenerator.gen_export_named_declaration(nd: es.ExportNamedDeclaration) -> str {
    if nd.declaration {
        return f"{self.indent()}export {self.generate(nd.declaration).lstrip()}";
    }
    specs = ', '.join(self.generate(s) for s in nd.specifiers);
    if nd.source {
        source = self.generate(nd.source);
        return f"{self.indent()}export {{{specs}}} from {source};";
    }
    return f"{self.indent()}export {{{specs}}};";
}

"""Generate import namespace specifier."""
impl JSCodeGenerator.gen_import_namespace_specifier(
    nd: es.ImportNamespaceSpecifier
) -> str {
    return f"* as {self.generate(nd.local)}";
}

"""Generate import default specifier."""
impl JSCodeGenerator.gen_import_default_specifier(nd: es.ImportDefaultSpecifier) -> str {
    return self.generate(nd.local);
}

"""Generate import specifier."""
impl JSCodeGenerator.gen_import_specifier(nd: es.ImportSpecifier) -> str {
    imported = self.generate(nd.imported);
    local = self.generate(nd.local);
    if (imported != local) {
        return f"{imported} as {local}";
    }
    return imported;
}

"""Generate import declaration."""
impl JSCodeGenerator.gen_import_declaration(nd: es.ImportDeclaration) -> str {
    default_spec: (str | None) = None;
    namespace_spec: (str | None) = None;
    named_specs: list[str] = [];
    for spec in nd.specifiers {
        if isinstance(spec, es.ImportDefaultSpecifier) {
            default_spec = self.generate(spec);
        } elif isinstance(spec, es.ImportNamespaceSpecifier) {
            namespace_spec = self.generate(spec);
        } elif isinstance(spec, es.ImportSpecifier) {
            named_specs.append(self.generate(spec));
        }
    }
    clause_parts: list[str] = [];
    if default_spec {
        clause_parts.append(default_spec);
    }
    if namespace_spec {
        clause_parts.append(namespace_spec);
    }
    if named_specs {
        clause_parts.append('{ ' + ', '.join(named_specs) + ' }');
    }
    source = self.generate(nd.source);
    if clause_parts {
        clause = ', '.join(clause_parts);
        return f"{self.indent()}import {clause} from {source};";
    }
    return f"{self.indent()}import {source};";
}

"""Generate rest element."""
impl JSCodeGenerator.gen_rest_element(nd: es.RestElement) -> str {
    return f"...{self.generate(nd.argument)}";
}

"""Generate assignment pattern."""
impl JSCodeGenerator.gen_assignment_pattern(nd: es.AssignmentPattern) -> str {
    left = self.generate(nd.left);
    right = self.generate(nd.right);
    return f"{left} = {right}";
}

"""Generate object pattern."""
impl JSCodeGenerator.gen_object_pattern(nd: es.ObjectPattern) -> str {
    props = ', '.join(self.generate(p) for p in nd.properties);
    return f"{{{props}}}";
}

"""Generate array pattern."""
impl JSCodeGenerator.gen_array_pattern(nd: es.ArrayPattern) -> str {
    elements = ', '.join(self.generate(e) if e else '' for e in nd.elements);
    return f"[{elements}]";
}

"""Generate meta property (e.g., new.target)."""
impl JSCodeGenerator.gen_meta_property(nd: es.MetaProperty) -> str {
    meta = self.generate(nd.meta) if nd.meta else '';
    prop = self.generate(nd.property) if nd.property else '';
    return f"{meta}.{prop}";
}

"""Generate super."""
impl JSCodeGenerator.gen_super(nd: es.Super) -> str {
    return 'super';
}

"""Generate spread element."""
impl JSCodeGenerator.gen_spread_element(nd: es.SpreadElement) -> str {
    return f"...{self.generate(nd.argument)}";
}

"""Generate tagged template expression."""
impl JSCodeGenerator.gen_tagged_template_expression(
    nd: es.TaggedTemplateExpression
) -> str {
    tag = self.generate(nd.tag);
    quasi = self.generate(nd.quasi);
    return f"{tag}{quasi}";
}

"""Generate template element."""
impl JSCodeGenerator.gen_template_element(nd: es.TemplateElement) -> str {
    value = nd.value.get('raw') if nd.value else '';
    return (value or '');
}

"""Generate template literal."""
impl JSCodeGenerator.gen_template_literal(nd: es.TemplateLiteral) -> str {
    parts: list[str] = [];
    for (idx, quasi) in enumerate(nd.quasis) {
        parts.append(self.generate(quasi));
        if (idx < len(nd.expressions)) {
            parts.append(f"${{{self.generate(nd.expressions[idx])}}}");
        }
    }
    return f"`{''.join(parts)}`";
}

"""Generate await expression."""
impl JSCodeGenerator.gen_await_expression(nd: es.AwaitExpression) -> str {
    return f"await {self.generate(nd.argument)}";
}

"""Generate yield expression."""
impl JSCodeGenerator.gen_yield_expression(nd: es.YieldExpression) -> str {
    delegate = '*' if nd.delegate else '';
    if nd.argument {
        return f"yield{delegate} {self.generate(nd.argument)}";
    }
    return f"yield{delegate}";
}

"""Generate sequence expression."""
impl JSCodeGenerator.gen_sequence_expression(nd: es.SequenceExpression) -> str {
    exprs = ', '.join(self.generate(e) for e in nd.expressions);
    return f"({exprs})";
}

"""Generate dynamic import expression."""
impl JSCodeGenerator.gen_import_expression(nd: es.ImportExpression) -> str {
    source = self.generate(nd.source) if nd.source else '';
    return f"import({source})";
}

"""Generate new expression."""
impl JSCodeGenerator.gen_new_expression(nd: es.NewExpression) -> str {
    callee = self.generate(nd.callee);
    if isinstance(nd.arguments, es.ObjectExpression) {
        args = self.generate(nd.arguments);
    } else {
        args = ', '.join(self.generate(arg) for arg in nd.arguments);
    }
    return f"new {callee}({args})";
}

"""Generate optional chaining expression."""
impl JSCodeGenerator.gen_chain_expression(nd: es.ChainExpression) -> str {
    return self.generate(nd.expression);
}

"""Generate call expression."""
impl JSCodeGenerator.gen_call_expression(nd: es.CallExpression) -> str {
    callee = self.generate(nd.callee);
    # Wrap arrow/function expressions in parentheses for IIFE pattern
    if isinstance(nd.callee, (es.ArrowFunctionExpression, es.FunctionExpression)) {
        callee = f"({callee})";
    }
    optional = '?.' if nd.optional else '';
    if isinstance(nd.arguments, es.ObjectExpression) {
        args = self.generate(nd.arguments);
    } else {
        args = ', '.join(self.generate(arg) for arg in nd.arguments);
    }
    return f"{callee}{optional}({args})";
}

"""Generate conditional expression."""
impl JSCodeGenerator.gen_conditional_expression(nd: es.ConditionalExpression) -> str {
    `test = self.generate(nd.test);
    consequent = self.generate(nd.consequent);
    alternate = self.generate(nd.alternate);
    return f"({test} ? {consequent} : {alternate})";
}

"""Generate member expression."""
impl JSCodeGenerator.gen_member_expression(nd: es.MemberExpression) -> str {
    `obj = self.generate(nd.object);
    optional = '?.' if nd.optional else '';
    if nd.computed {
        prop = self.generate(nd.property);
        return f"{`obj}{optional}[{prop}]";
    } else {
        prop = self.generate(nd.property);
        if optional {
            return f"{`obj}{optional}{prop}";
        }
        return f"{`obj}.{prop}";
    }
}

"""Generate assignment expression."""
impl JSCodeGenerator.gen_assignment_expression(nd: es.AssignmentExpression) -> str {
    left = self.generate(nd.left);
    right = self.generate(nd.right);
    return f"{left} {nd.operator} {right}";
}

"""Generate logical expression."""
impl JSCodeGenerator.gen_logical_expression(nd: es.LogicalExpression) -> str {
    left = self.generate(nd.left);
    right = self.generate(nd.right);
    return f"({left} {nd.operator} {right})";
}

"""Generate binary expression."""
impl JSCodeGenerator.gen_binary_expression(nd: es.BinaryExpression) -> str {
    left = self.generate(nd.left);
    right = self.generate(nd.right);
    if isinstance(nd.left, es.AssignmentExpression) {
        left = f"({left})";
    }
    if isinstance(nd.right, es.AssignmentExpression) {
        right = f"({right})";
    }
    return f"({left} {nd.operator} {right})";
}

"""Generate update expression."""
impl JSCodeGenerator.gen_update_expression(nd: es.UpdateExpression) -> str {
    arg = self.generate(nd.argument);
    if nd.prefix {
        return f"{nd.operator}{arg}";
    } else {
        return f"{arg}{nd.operator}";
    }
}

"""Generate unary expression."""
impl JSCodeGenerator.gen_unary_expression(nd: es.UnaryExpression) -> str {
    arg = self.generate(nd.argument);
    if nd.prefix {
        if (nd.operator in ('typeof', 'void', 'delete')) {
            return f"{nd.operator} {arg}";
        }
        return f"{nd.operator}{arg}";
    } else {
        return f"{arg}{nd.operator}";
    }
}

"""Generate arrow function expression."""
impl JSCodeGenerator.gen_arrow_function_expression(
    nd: es.ArrowFunctionExpression
) -> str {
    async_str = 'async ' if nd.async_ else '';
    params = ', '.join(self.generate(p) for p in nd.params);
    params = self.generate(nd.params[0]) if (len(nd.params) == 1) else f"({params})";
    if nd.expression {
        body = self.generate(nd.body);
        return f"{async_str}{params} => {body}";
    } else {
        body = self.generate(nd.body);
        return f"{async_str}{params} => {body}";
    }
}

"""Generate function expression."""
impl JSCodeGenerator.gen_function_expression(nd: es.FunctionExpression) -> str {
    async_str = 'async ' if nd.async_ else '';
    generator_str = '*' if nd.generator else '';
    name = self.generate(nd.id) if nd.id else '';
    params = ', '.join(self.generate(p) for p in nd.params);
    body = self.generate(nd.body);
    return f"{async_str}function{generator_str} {name}({params}) {body}".strip();
}

"""Generate property."""
impl JSCodeGenerator.gen_property(nd: es.Property) -> str {
    key = self.generate(nd.key);
    value = self.generate(nd.value);
    if nd.shorthand {
        return key;
    } elif nd.computed {
        return f"[{key}]: {value}";
    } elif (nd.kind == 'get') {
        return f"get {key}() {value}";
    } elif (nd.kind == 'set') {
        return f"set {key}({value})";
    } else {
        return f"{key}: {value}";
    }
}

"""Generate object expression."""
impl JSCodeGenerator.gen_object_expression(nd: es.ObjectExpression) -> str {
    if not nd.properties {
        return '{}';
    }
    props = ', '.join(self.generate(p) for p in nd.properties);
    return f"{{{props}}}";
}

"""Generate array expression."""
impl JSCodeGenerator.gen_array_expression(nd: es.ArrayExpression) -> str {
    elements = ', '.join(self.generate(e) if e else '' for e in nd.elements);
    return f"[{elements}]";
}

"""Generate this expression."""
impl JSCodeGenerator.gen_this_expression(nd: es.ThisExpression) -> str {
    return 'this';
}

"""Generate literal."""
impl JSCodeGenerator.gen_literal(nd: es.Literal) -> str {
    if nd.raw {
        return nd.raw;
    }
    if isinstance(nd.value, str) {
        return f'"{nd.value}"';
    } elif (nd.value is None) {
        return 'null';
    } elif isinstance(nd.value, bool) {
        return 'true' if nd.value else 'false';
    } else {
        return str(nd.value);
    }
}

"""Generate private identifier."""
impl JSCodeGenerator.gen_private_identifier(nd: es.PrivateIdentifier) -> str {
    return f"\#{nd.name}";
}

"""Generate identifier."""
impl JSCodeGenerator.gen_identifier(nd: es.Identifier) -> str {
    return nd.name;
}

"""Generate static initialization block."""
impl JSCodeGenerator.gen_static_block(nd: es.StaticBlock) -> str {
    block = self.generate(es.BlockStatement(body=nd.body));
    return f"{self.indent()}static {block}";
}

"""Generate class field definition."""
impl JSCodeGenerator.gen_property_definition(nd: es.PropertyDefinition) -> str {
    static_str = 'static ' if nd.static else '';
    key = self.generate(nd.key) if nd.key else '';
    if nd.computed {
        key = f"[{key}]";
    }
    value = f" = {self.generate(nd.value)}" if nd.value else '';
    return f"{self.indent()}{static_str}{key}{value};";
}

"""Generate method definition."""
impl JSCodeGenerator.gen_method_definition(nd: es.MethodDefinition) -> str {
    static_str = 'static ' if nd.static else '';
    key = self.generate(nd.key);
    value = self.generate(nd.value);
    if isinstance(nd.value, es.FunctionExpression) {
        async_str = 'async ' if nd.value.async_ else '';
        params = ', '.join(self.generate(p) for p in nd.value.params);
        body = self.generate(nd.value.body);
        if (nd.kind == 'constructor') {
            return f"{self.indent()}constructor({params}) {body}";
        } elif (nd.kind == 'get') {
            return f"{self.indent()}{static_str}get {key}() {body}";
        } elif (nd.kind == 'set') {
            return f"{self.indent()}{static_str}set {key}({params}) {body}";
        } else {
            return f"{self.indent()}{static_str}{async_str}{key}({params}) {body}";
        }
    }
    return f"{self.indent()}{static_str}{key}{value}";
}

"""Generate class body."""
impl JSCodeGenerator.gen_class_body(nd: es.ClassBody) -> str {
    if not nd.body {
        return '{}';
    }
    self.indent_level += 1;
    methods = '\n'.join(self.generate(m) for m in nd.body);
    self.indent_level -= 1;
    return f"{{\n{methods}\n{self.indent()}}}";
}

"""Generate class expression."""
impl JSCodeGenerator.gen_class_expression(nd: es.ClassExpression) -> str {
    name = self.generate(nd.id) if nd.id else '';
    extends = f" extends {self.generate(nd.superClass)}" if nd.superClass else '';
    body = self.generate(nd.body);
    return f"class {name}{extends} {body}";
}

"""Generate class declaration."""
impl JSCodeGenerator.gen_class_declaration(nd: es.ClassDeclaration) -> str {
    name = self.generate(nd.id) if nd.id else '';
    extends = f" extends {self.generate(nd.superClass)}" if nd.superClass else '';
    body = self.generate(nd.body);
    return f"{self.indent()}class {name}{extends} {body}";
}

"""Generate variable declarator."""
impl JSCodeGenerator.gen_variable_declarator(nd: es.VariableDeclarator) -> str {
    id_str = self.generate(nd.id);
    if nd.`init {
        return f"{id_str} = {self.generate(nd.`init)}";
    }
    return id_str;
}

"""Generate variable declaration."""
impl JSCodeGenerator.gen_variable_declaration(nd: es.VariableDeclaration) -> str {
    declarators = ', '.join(self.generate(d) for d in nd.declarations);
    return f"{self.indent()}{nd.kind} {declarators};";
}

"""Generate function declaration."""
impl JSCodeGenerator.gen_function_declaration(nd: es.FunctionDeclaration) -> str {
    async_str = 'async ' if nd.async_ else '';
    generator_str = '*' if nd.generator else '';
    name = self.generate(nd.id) if nd.id else '';
    params = ', '.join(self.generate(p) for p in nd.params);
    body = self.generate(nd.body);
    return f"{self.indent()}{async_str}function{generator_str} {name}({params}) {body}";
}

"""Generate switch case."""
impl JSCodeGenerator.gen_switch_case(nd: es.SwitchCase) -> str {
    result = f"{self.indent()}case {self.generate(nd.test)}:\\n"
    if nd.test
    else f"{self.indent()}default:\\n";
    self.indent_level += 1;
    for stmt in nd.consequent {
        result += f"{self.generate(stmt)}\\n";
    }
    self.indent_level -= 1;
    return result.rstrip();
}

"""Generate switch statement."""
impl JSCodeGenerator.gen_switch_statement(nd: es.SwitchStatement) -> str {
    discriminant = self.generate(nd.discriminant);
    self.indent_level += 1;
    cases = '\n'.join(self.generate(`case) for `case in nd.cases);
    self.indent_level -= 1;
    return f"{self.indent()}switch ({discriminant}) {{\n{cases}\n{self.indent()}}}";
}

"""Generate catch clause."""
impl JSCodeGenerator.gen_catch_clause(nd: es.CatchClause) -> str {
    if nd.param {
        return f"catch ({self.generate(nd.param)}) {self.generate(nd.body)}";
    }
    return f"catch {self.generate(nd.body)}";
}

"""Generate try statement."""
impl JSCodeGenerator.gen_try_statement(nd: es.TryStatement) -> str {
    result = f"{self.indent()}try {self.generate(nd.block)}";
    if nd.handler {
        result += f" {self.generate(nd.handler)}";
    }
    if nd.finalizer {
        result += f" finally {self.generate(nd.finalizer)}";
    }
    return result;
}

"""Generate throw statement."""
impl JSCodeGenerator.gen_throw_statement(nd: es.ThrowStatement) -> str {
    return f"{self.indent()}throw {self.generate(nd.argument)};";
}

"""Generate continue statement."""
impl JSCodeGenerator.gen_continue_statement(nd: es.ContinueStatement) -> str {
    if nd.label {
        return f"{self.indent()}continue {self.generate(nd.label)};";
    }
    return f"{self.indent()}continue;";
}

"""Generate break statement."""
impl JSCodeGenerator.gen_break_statement(nd: es.BreakStatement) -> str {
    if nd.label {
        return f"{self.indent()}break {self.generate(nd.label)};";
    }
    return f"{self.indent()}break;";
}

"""Generate for-of statement."""
impl JSCodeGenerator.gen_for_of_statement(nd: es.ForOfStatement) -> str {
    await_str = 'await ' if nd.await_ else '';
    if isinstance(nd.left, es.VariableDeclaration) {
        declarators = ', '.join(self.generate(decl) for decl in nd.left.declarations);
        left = f"{nd.left.kind} {declarators}";
    } else {
        left = self.generate(nd.left);
    }
    right = self.generate(nd.right);
    body = self.generate(nd.body);
    return f"{self.indent()}for {await_str}({left} of {right}) {body}";
}

"""Generate for-in statement."""
impl JSCodeGenerator.gen_for_in_statement(nd: es.ForInStatement) -> str {
    left = self.generate(nd.left);
    right = self.generate(nd.right);
    body = self.generate(nd.body);
    return f"{self.indent()}for ({left} in {right}) {body}";
}

"""Generate for statement."""
impl JSCodeGenerator.gen_for_statement(nd: es.ForStatement) -> str {
    if nd.`init {
        init_str = self.generate(nd.`init).lstrip();
        if init_str.endswith(';') {
            init_str = init_str.rstrip(';');
        }
    } else {
        init_str = '';
    }
    test_str = self.generate(nd.test) if nd.test else '';
    update = self.generate(nd.update).lstrip() if nd.update else '';
    body = self.generate(nd.body);
    return f"{self.indent()}for ({init_str}; {test_str}; {update}) {body}";
}

"""Generate do-while statement."""
impl JSCodeGenerator.gen_do_while_statement(nd: es.DoWhileStatement) -> str {
    body = self.generate(nd.body);
    `test = self.generate(nd.test);
    return f"{self.indent()}do {body} while ({test});";
}

"""Generate while statement."""
impl JSCodeGenerator.gen_while_statement(nd: es.WhileStatement) -> str {
    `test = self.generate(nd.test);
    body = self.generate(nd.body);
    return f"{self.indent()}while ({test}) {body}";
}

"""Generate if statement."""
impl JSCodeGenerator.gen_if_statement(nd: es.IfStatement) -> str {
    `test = self.generate(nd.test);
    consequent = self.generate(nd.consequent);
    result = f"{self.indent()}if ({test}) {consequent}";
    if nd.alternate {
        if isinstance(nd.alternate, es.IfStatement) {
            result += f" else {self.generate(nd.alternate).lstrip()}";
        } else {
            result += f" else {self.generate(nd.alternate)}";
        }
    }
    return result;
}

"""Generate return statement."""
impl JSCodeGenerator.gen_return_statement(nd: es.ReturnStatement) -> str {
    if nd.argument {
        return f"{self.indent()}return {self.generate(nd.argument)};";
    }
    return f"{self.indent()}return;";
}

"""Generate empty statement."""
impl JSCodeGenerator.gen_empty_statement(nd: es.EmptyStatement) -> str {
    return f"{self.indent()};";
}

"""Generate block statement."""
impl JSCodeGenerator.gen_block_statement(nd: es.BlockStatement) -> str {
    if not nd.body {
        return '{}';
    }
    self.indent_level += 1;
    body = '\n'.join(self.generate(stmt) for stmt in nd.body);
    self.indent_level -= 1;
    return f"{{\n{body}\n{self.indent()}}}";
}

"""Generate expression statement."""
impl JSCodeGenerator.gen_expression_statement(nd: es.ExpressionStatement) -> str {
    return f"{self.indent()}{self.generate(nd.expression)};";
}

"""Generate program."""
impl JSCodeGenerator.gen_program(nd: es.Program) -> str {
    return '\n'.join(self.generate(stmt) for stmt in nd.body);
}

"""Generate JavaScript code for a node."""
impl JSCodeGenerator.generate(nd: (es.Node | None)) -> str {
    import from jaclang.jac0core.helpers { pascal_to_snake }
    if (nd is None) {
        return '';
    }
    method_name = f"gen_{pascal_to_snake(nd.type)}";
    method = getattr(self, method_name, None);
    if method {
        return method(nd);
    } else {
        return f"/* Unsupported node type: {nd.type} */";
    }
}

"""Get current indentation."""
impl JSCodeGenerator.indent -> str {
    return (self.indent_str * self.indent_level);
}

"""Initialize the code generator."""
impl JSCodeGenerator.init(indent: str = '  ') -> None {
    self.indent_str = indent;
    self.indent_level = 0;
}
