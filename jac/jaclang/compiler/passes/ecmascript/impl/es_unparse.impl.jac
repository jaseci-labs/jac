"""Convert an ESTree node to JavaScript code."""

impl es_to_js(<>node: (es.Node | None), indent: str = '  ') -> str {
    generator = JSCodeGenerator(indent=indent);
    return generator.generate(<>node);
}

"""Generate export all declaration."""
impl JSCodeGenerator.gen_export_all_declaration(<>node: es.ExportAllDeclaration) -> str {
    source = self.generate(<>node.source);
    if <>node.exported {
        exported = self.generate(<>node.exported);
        return f"{self.indent()}export * as {exported} from {source};";
    }
    return f"{self.indent()}export * from {source};";
}

"""Generate export default declaration."""
impl JSCodeGenerator.gen_export_default_declaration(
    <>node: es.ExportDefaultDeclaration
) -> str {
    return f"{self.indent()}export default {self.generate(<>node.declaration)}";
}

"""Generate export specifier."""
impl JSCodeGenerator.gen_export_specifier(<>node: es.ExportSpecifier) -> str {
    local = self.generate(<>node.local);
    exported = self.generate(<>node.exported);
    if (local != exported) {
        return f"{local} as {exported}";
    }
    return local;
}

"""Generate export named declaration."""
impl JSCodeGenerator.gen_export_named_declaration(
    <>node: es.ExportNamedDeclaration
) -> str {
    if <>node.declaration {
        return f"{self.indent()}export {self.generate(<>node.declaration).lstrip()}";
    }
    specs = ', '.join(self.generate(s) for s in <>node.specifiers);
    if <>node.source {
        source = self.generate(<>node.source);
        return f"{self.indent()}export {{{specs}}} from {source};";
    }
    return f"{self.indent()}export {{{specs}}};";
}

"""Generate import namespace specifier."""
impl JSCodeGenerator.gen_import_namespace_specifier(
    <>node: es.ImportNamespaceSpecifier
) -> str {
    return f"* as {self.generate(<>node.local)}";
}

"""Generate import default specifier."""
impl JSCodeGenerator.gen_import_default_specifier(
    <>node: es.ImportDefaultSpecifier
) -> str {
    return self.generate(<>node.local);
}

"""Generate import specifier."""
impl JSCodeGenerator.gen_import_specifier(<>node: es.ImportSpecifier) -> str {
    imported = self.generate(<>node.imported);
    local = self.generate(<>node.local);
    if (imported != local) {
        return f"{imported} as {local}";
    }
    return imported;
}

"""Generate import declaration."""
impl JSCodeGenerator.gen_import_declaration(<>node: es.ImportDeclaration) -> str {
    default_spec: (str | None) = None;
    namespace_spec: (str | None) = None;
    named_specs: list[str] = [];
    for spec in <>node.specifiers {
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
    source = self.generate(<>node.source);
    if clause_parts {
        clause = ', '.join(clause_parts);
        return f"{self.indent()}import {clause} from {source};";
    }
    return f"{self.indent()}import {source};";
}

"""Generate rest element."""
impl JSCodeGenerator.gen_rest_element(<>node: es.RestElement) -> str {
    return f"...{self.generate(<>node.argument)}";
}

"""Generate assignment pattern."""
impl JSCodeGenerator.gen_assignment_pattern(<>node: es.AssignmentPattern) -> str {
    left = self.generate(<>node.left);
    right = self.generate(<>node.right);
    return f"{left} = {right}";
}

"""Generate object pattern."""
impl JSCodeGenerator.gen_object_pattern(<>node: es.ObjectPattern) -> str {
    props = ', '.join(self.generate(p) for p in <>node.properties);
    return f"{{{props}}}";
}

"""Generate array pattern."""
impl JSCodeGenerator.gen_array_pattern(<>node: es.ArrayPattern) -> str {
    elements = ', '.join(self.generate(e) if e else '' for e in <>node.elements);
    return f"[{elements}]";
}

"""Generate meta property (e.g., new.target)."""
impl JSCodeGenerator.gen_meta_property(<>node: es.MetaProperty) -> str {
    meta = self.generate(<>node.meta) if <>node.meta else '';
    prop = self.generate(<>node.property) if <>node.property else '';
    return f"{meta}.{prop}";
}

"""Generate super."""
impl JSCodeGenerator.gen_super(<>node: es.Super) -> str {
    return 'super';
}

"""Generate spread element."""
impl JSCodeGenerator.gen_spread_element(<>node: es.SpreadElement) -> str {
    return f"...{self.generate(<>node.argument)}";
}

"""Generate tagged template expression."""
impl JSCodeGenerator.gen_tagged_template_expression(
    <>node: es.TaggedTemplateExpression
) -> str {
    tag = self.generate(<>node.tag);
    quasi = self.generate(<>node.quasi);
    return f"{tag}{quasi}";
}

"""Generate template element."""
impl JSCodeGenerator.gen_template_element(<>node: es.TemplateElement) -> str {
    value = <>node.value.get('raw') if <>node.value else '';
    return (value or '');
}

"""Generate template literal."""
impl JSCodeGenerator.gen_template_literal(<>node: es.TemplateLiteral) -> str {
    parts: list[str] = [];
    for (idx, quasi) in enumerate(<>node.quasis) {
        parts.append(self.generate(quasi));
        if (idx < len(<>node.expressions)) {
            parts.append(f"${{{self.generate(<>node.expressions[idx])}}}");
        }
    }
    return f"`{''.join(parts)}`";
}

"""Generate await expression."""
impl JSCodeGenerator.gen_await_expression(<>node: es.AwaitExpression) -> str {
    return f"await {self.generate(<>node.argument)}";
}

"""Generate yield expression."""
impl JSCodeGenerator.gen_yield_expression(<>node: es.YieldExpression) -> str {
    delegate = '*' if <>node.delegate else '';
    if <>node.argument {
        return f"yield{delegate} {self.generate(<>node.argument)}";
    }
    return f"yield{delegate}";
}

"""Generate sequence expression."""
impl JSCodeGenerator.gen_sequence_expression(<>node: es.SequenceExpression) -> str {
    exprs = ', '.join(self.generate(e) for e in <>node.expressions);
    return f"({exprs})";
}

"""Generate dynamic import expression."""
impl JSCodeGenerator.gen_import_expression(<>node: es.ImportExpression) -> str {
    source = self.generate(<>node.source) if <>node.source else '';
    return f"import({source})";
}

"""Generate new expression."""
impl JSCodeGenerator.gen_new_expression(<>node: es.NewExpression) -> str {
    callee = self.generate(<>node.callee);
    if isinstance(<>node.arguments, es.ObjectExpression) {
        args = self.generate(<>node.arguments);
    } else {
        args = ', '.join(self.generate(arg) for arg in <>node.arguments);
    }
    return f"new {callee}({args})";
}

"""Generate optional chaining expression."""
impl JSCodeGenerator.gen_chain_expression(<>node: es.ChainExpression) -> str {
    return self.generate(<>node.expression);
}

"""Generate call expression."""
impl JSCodeGenerator.gen_call_expression(<>node: es.CallExpression) -> str {
    callee = self.generate(<>node.callee);
    # Wrap arrow/function expressions in parentheses for IIFE pattern
    if isinstance(<>node.callee, (es.ArrowFunctionExpression, es.FunctionExpression)) {
        callee = f"({callee})";
    }
    optional = '?.' if <>node.optional else '';
    if isinstance(<>node.arguments, es.ObjectExpression) {
        args = self.generate(<>node.arguments);
    } else {
        args = ', '.join(self.generate(arg) for arg in <>node.arguments);
    }
    return f"{callee}{optional}({args})";
}

"""Generate conditional expression."""
impl JSCodeGenerator.gen_conditional_expression(
    <>node: es.ConditionalExpression
) -> str {
    <>test = self.generate(<>node.test);
    consequent = self.generate(<>node.consequent);
    alternate = self.generate(<>node.alternate);
    return f"({test} ? {consequent} : {alternate})";
}

"""Generate member expression."""
impl JSCodeGenerator.gen_member_expression(<>node: es.MemberExpression) -> str {
    <>obj = self.generate(<>node.object);
    optional = '?.' if <>node.optional else '';
    if <>node.computed {
        prop = self.generate(<>node.property);
        return f"{<>obj}{optional}[{prop}]";
    } else {
        prop = self.generate(<>node.property);
        if optional {
            return f"{<>obj}{optional}{prop}";
        }
        return f"{<>obj}.{prop}";
    }
}

"""Generate assignment expression."""
impl JSCodeGenerator.gen_assignment_expression(<>node: es.AssignmentExpression) -> str {
    left = self.generate(<>node.left);
    right = self.generate(<>node.right);
    return f"{left} {<>node.operator} {right}";
}

"""Generate logical expression."""
impl JSCodeGenerator.gen_logical_expression(<>node: es.LogicalExpression) -> str {
    left = self.generate(<>node.left);
    right = self.generate(<>node.right);
    return f"({left} {<>node.operator} {right})";
}

"""Generate binary expression."""
impl JSCodeGenerator.gen_binary_expression(<>node: es.BinaryExpression) -> str {
    left = self.generate(<>node.left);
    right = self.generate(<>node.right);
    if isinstance(<>node.left, es.AssignmentExpression) {
        left = f"({left})";
    }
    if isinstance(<>node.right, es.AssignmentExpression) {
        right = f"({right})";
    }
    return f"({left} {<>node.operator} {right})";
}

"""Generate update expression."""
impl JSCodeGenerator.gen_update_expression(<>node: es.UpdateExpression) -> str {
    arg = self.generate(<>node.argument);
    if <>node.prefix {
        return f"{<>node.operator}{arg}";
    } else {
        return f"{arg}{<>node.operator}";
    }
}

"""Generate unary expression."""
impl JSCodeGenerator.gen_unary_expression(<>node: es.UnaryExpression) -> str {
    arg = self.generate(<>node.argument);
    if <>node.prefix {
        if (<>node.operator in ('typeof', 'void', 'delete')) {
            return f"{<>node.operator} {arg}";
        }
        return f"{<>node.operator}{arg}";
    } else {
        return f"{arg}{<>node.operator}";
    }
}

"""Generate arrow function expression."""
impl JSCodeGenerator.gen_arrow_function_expression(
    <>node: es.ArrowFunctionExpression
) -> str {
    async_str = 'async ' if <>node.async_ else '';
    params = ', '.join(self.generate(p) for p in <>node.params);
    params = self.generate(<>node.params[0])
    if (len(<>node.params) == 1)
    else f"({params})";
    if <>node.expression {
        body = self.generate(<>node.body);
        return f"{async_str}{params} => {body}";
    } else {
        body = self.generate(<>node.body);
        return f"{async_str}{params} => {body}";
    }
}

"""Generate function expression."""
impl JSCodeGenerator.gen_function_expression(<>node: es.FunctionExpression) -> str {
    async_str = 'async ' if <>node.async_ else '';
    generator_str = '*' if <>node.generator else '';
    name = self.generate(<>node.id) if <>node.id else '';
    params = ', '.join(self.generate(p) for p in <>node.params);
    body = self.generate(<>node.body);
    return f"{async_str}function{generator_str} {name}({params}) {body}".strip();
}

"""Generate property."""
impl JSCodeGenerator.gen_property(<>node: es.Property) -> str {
    key = self.generate(<>node.key);
    value = self.generate(<>node.value);
    if <>node.shorthand {
        return key;
    } elif <>node.computed {
        return f"[{key}]: {value}";
    } elif (<>node.kind == 'get') {
        return f"get {key}() {value}";
    } elif (<>node.kind == 'set') {
        return f"set {key}({value})";
    } else {
        return f"{key}: {value}";
    }
}

"""Generate object expression."""
impl JSCodeGenerator.gen_object_expression(<>node: es.ObjectExpression) -> str {
    if not <>node.properties {
        return '{}';
    }
    props = ', '.join(self.generate(p) for p in <>node.properties);
    return f"{{{props}}}";
}

"""Generate array expression."""
impl JSCodeGenerator.gen_array_expression(<>node: es.ArrayExpression) -> str {
    elements = ', '.join(self.generate(e) if e else '' for e in <>node.elements);
    return f"[{elements}]";
}

"""Generate this expression."""
impl JSCodeGenerator.gen_this_expression(<>node: es.ThisExpression) -> str {
    return 'this';
}

"""Generate literal."""
impl JSCodeGenerator.gen_literal(<>node: es.Literal) -> str {
    if <>node.raw {
        return <>node.raw;
    }
    if isinstance(<>node.value, str) {
        return f'"{<>node.value}"';
    } elif (<>node.value is None) {
        return 'null';
    } elif isinstance(<>node.value, bool) {
        return 'true' if <>node.value else 'false';
    } else {
        return str(<>node.value);
    }
}

"""Generate private identifier."""
impl JSCodeGenerator.gen_private_identifier(<>node: es.PrivateIdentifier) -> str {
    return f"\#{<>node.name}";
}

"""Generate identifier."""
impl JSCodeGenerator.gen_identifier(<>node: es.Identifier) -> str {
    return <>node.name;
}

"""Generate static initialization block."""
impl JSCodeGenerator.gen_static_block(<>node: es.StaticBlock) -> str {
    block = self.generate(es.BlockStatement(body=<>node.body));
    return f"{self.indent()}static {block}";
}

"""Generate class field definition."""
impl JSCodeGenerator.gen_property_definition(<>node: es.PropertyDefinition) -> str {
    static_str = 'static ' if <>node.static else '';
    key = self.generate(<>node.key) if <>node.key else '';
    if <>node.computed {
        key = f"[{key}]";
    }
    value = f" = {self.generate(<>node.value)}" if <>node.value else '';
    return f"{self.indent()}{static_str}{key}{value};";
}

"""Generate method definition."""
impl JSCodeGenerator.gen_method_definition(<>node: es.MethodDefinition) -> str {
    static_str = 'static ' if <>node.static else '';
    key = self.generate(<>node.key);
    value = self.generate(<>node.value);
    if isinstance(<>node.value, es.FunctionExpression) {
        async_str = 'async ' if <>node.value.async_ else '';
        params = ', '.join(self.generate(p) for p in <>node.value.params);
        body = self.generate(<>node.value.body);
        if (<>node.kind == 'constructor') {
            return f"{self.indent()}constructor({params}) {body}";
        } elif (<>node.kind == 'get') {
            return f"{self.indent()}{static_str}get {key}() {body}";
        } elif (<>node.kind == 'set') {
            return f"{self.indent()}{static_str}set {key}({params}) {body}";
        } else {
            return f"{self.indent()}{static_str}{async_str}{key}({params}) {body}";
        }
    }
    return f"{self.indent()}{static_str}{key}{value}";
}

"""Generate class body."""
impl JSCodeGenerator.gen_class_body(<>node: es.ClassBody) -> str {
    if not <>node.body {
        return '{}';
    }
    self.indent_level += 1;
    methods = '\n'.join(self.generate(m) for m in <>node.body);
    self.indent_level -= 1;
    return f"{{\n{methods}\n{self.indent()}}}";
}

"""Generate class expression."""
impl JSCodeGenerator.gen_class_expression(<>node: es.ClassExpression) -> str {
    name = self.generate(<>node.id) if <>node.id else '';
    extends = f" extends {self.generate(<>node.superClass)}"
    if <>node.superClass
    else '';
    body = self.generate(<>node.body);
    return f"class {name}{extends} {body}";
}

"""Generate class declaration."""
impl JSCodeGenerator.gen_class_declaration(<>node: es.ClassDeclaration) -> str {
    name = self.generate(<>node.id) if <>node.id else '';
    extends = f" extends {self.generate(<>node.superClass)}"
    if <>node.superClass
    else '';
    body = self.generate(<>node.body);
    return f"{self.indent()}class {name}{extends} {body}";
}

"""Generate variable declarator."""
impl JSCodeGenerator.gen_variable_declarator(<>node: es.VariableDeclarator) -> str {
    id_str = self.generate(<>node.id);
    if <>node.<>init {
        return f"{id_str} = {self.generate(<>node.<>init)}";
    }
    return id_str;
}

"""Generate variable declaration."""
impl JSCodeGenerator.gen_variable_declaration(<>node: es.VariableDeclaration) -> str {
    declarators = ', '.join(self.generate(d) for d in <>node.declarations);
    return f"{self.indent()}{<>node.kind} {declarators};";
}

"""Generate function declaration."""
impl JSCodeGenerator.gen_function_declaration(<>node: es.FunctionDeclaration) -> str {
    async_str = 'async ' if <>node.async_ else '';
    generator_str = '*' if <>node.generator else '';
    name = self.generate(<>node.id) if <>node.id else '';
    params = ', '.join(self.generate(p) for p in <>node.params);
    body = self.generate(<>node.body);
    return f"{self.indent()}{async_str}function{generator_str} {name}({params}) {body}";
}

"""Generate switch case."""
impl JSCodeGenerator.gen_switch_case(<>node: es.SwitchCase) -> str {
    result = f"{self.indent()}case {self.generate(<>node.test)}:\\n"
    if <>node.test
    else f"{self.indent()}default:\\n";
    self.indent_level += 1;
    for stmt in <>node.consequent {
        result += f"{self.generate(stmt)}\\n";
    }
    self.indent_level -= 1;
    return result.rstrip();
}

"""Generate switch statement."""
impl JSCodeGenerator.gen_switch_statement(<>node: es.SwitchStatement) -> str {
    discriminant = self.generate(<>node.discriminant);
    self.indent_level += 1;
    cases = '\n'.join(self.generate(<>case) for <>case in <>node.cases);
    self.indent_level -= 1;
    return f"{self.indent()}switch ({discriminant}) {{\n{cases}\n{self.indent()}}}";
}

"""Generate catch clause."""
impl JSCodeGenerator.gen_catch_clause(<>node: es.CatchClause) -> str {
    if <>node.param {
        return f"catch ({self.generate(<>node.param)}) {self.generate(<>node.body)}";
    }
    return f"catch {self.generate(<>node.body)}";
}

"""Generate try statement."""
impl JSCodeGenerator.gen_try_statement(<>node: es.TryStatement) -> str {
    result = f"{self.indent()}try {self.generate(<>node.block)}";
    if <>node.handler {
        result += f" {self.generate(<>node.handler)}";
    }
    if <>node.finalizer {
        result += f" finally {self.generate(<>node.finalizer)}";
    }
    return result;
}

"""Generate throw statement."""
impl JSCodeGenerator.gen_throw_statement(<>node: es.ThrowStatement) -> str {
    return f"{self.indent()}throw {self.generate(<>node.argument)};";
}

"""Generate continue statement."""
impl JSCodeGenerator.gen_continue_statement(<>node: es.ContinueStatement) -> str {
    if <>node.label {
        return f"{self.indent()}continue {self.generate(<>node.label)};";
    }
    return f"{self.indent()}continue;";
}

"""Generate break statement."""
impl JSCodeGenerator.gen_break_statement(<>node: es.BreakStatement) -> str {
    if <>node.label {
        return f"{self.indent()}break {self.generate(<>node.label)};";
    }
    return f"{self.indent()}break;";
}

"""Generate for-of statement."""
impl JSCodeGenerator.gen_for_of_statement(<>node: es.ForOfStatement) -> str {
    await_str = 'await ' if <>node.await_ else '';
    if isinstance(<>node.left, es.VariableDeclaration) {
        declarators = ', '.join(
            self.generate(decl) for decl in <>node.left.declarations
        );
        left = f"{<>node.left.kind} {declarators}";
    } else {
        left = self.generate(<>node.left);
    }
    right = self.generate(<>node.right);
    body = self.generate(<>node.body);
    return f"{self.indent()}for {await_str}({left} of {right}) {body}";
}

"""Generate for-in statement."""
impl JSCodeGenerator.gen_for_in_statement(<>node: es.ForInStatement) -> str {
    left = self.generate(<>node.left);
    right = self.generate(<>node.right);
    body = self.generate(<>node.body);
    return f"{self.indent()}for ({left} in {right}) {body}";
}

"""Generate for statement."""
impl JSCodeGenerator.gen_for_statement(<>node: es.ForStatement) -> str {
    if <>node.<>init {
        init_str = self.generate(<>node.<>init).lstrip();
        if init_str.endswith(';') {
            init_str = init_str.rstrip(';');
        }
    } else {
        init_str = '';
    }
    test_str = self.generate(<>node.test) if <>node.test else '';
    update = self.generate(<>node.update).lstrip() if <>node.update else '';
    body = self.generate(<>node.body);
    return f"{self.indent()}for ({init_str}; {test_str}; {update}) {body}";
}

"""Generate do-while statement."""
impl JSCodeGenerator.gen_do_while_statement(<>node: es.DoWhileStatement) -> str {
    body = self.generate(<>node.body);
    <>test = self.generate(<>node.test);
    return f"{self.indent()}do {body} while ({test});";
}

"""Generate while statement."""
impl JSCodeGenerator.gen_while_statement(<>node: es.WhileStatement) -> str {
    <>test = self.generate(<>node.test);
    body = self.generate(<>node.body);
    return f"{self.indent()}while ({test}) {body}";
}

"""Generate if statement."""
impl JSCodeGenerator.gen_if_statement(<>node: es.IfStatement) -> str {
    <>test = self.generate(<>node.test);
    consequent = self.generate(<>node.consequent);
    result = f"{self.indent()}if ({test}) {consequent}";
    if <>node.alternate {
        if isinstance(<>node.alternate, es.IfStatement) {
            result += f" else {self.generate(<>node.alternate).lstrip()}";
        } else {
            result += f" else {self.generate(<>node.alternate)}";
        }
    }
    return result;
}

"""Generate return statement."""
impl JSCodeGenerator.gen_return_statement(<>node: es.ReturnStatement) -> str {
    if <>node.argument {
        return f"{self.indent()}return {self.generate(<>node.argument)};";
    }
    return f"{self.indent()}return;";
}

"""Generate empty statement."""
impl JSCodeGenerator.gen_empty_statement(<>node: es.EmptyStatement) -> str {
    return f"{self.indent()};";
}

"""Generate block statement."""
impl JSCodeGenerator.gen_block_statement(<>node: es.BlockStatement) -> str {
    if not <>node.body {
        return '{}';
    }
    self.indent_level += 1;
    body = '\n'.join(self.generate(stmt) for stmt in <>node.body);
    self.indent_level -= 1;
    return f"{{\n{body}\n{self.indent()}}}";
}

"""Generate expression statement."""
impl JSCodeGenerator.gen_expression_statement(<>node: es.ExpressionStatement) -> str {
    return f"{self.indent()}{self.generate(<>node.expression)};";
}

"""Generate program."""
impl JSCodeGenerator.gen_program(<>node: es.Program) -> str {
    return '\n'.join(self.generate(stmt) for stmt in <>node.body);
}

"""Generate JavaScript code for a node."""
impl JSCodeGenerator.generate(<>node: (es.Node | None)) -> str {
    import from jaclang.pycore.helpers { pascal_to_snake }
    if (<>node is None) {
        return '';
    }
    method_name = f"gen_{pascal_to_snake(<>node.type)}";
    method = getattr(self, method_name, None);
    if method {
        return method(<>node);
    } else {
        return f"/* Unsupported node type: {<>node.type} */";
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
