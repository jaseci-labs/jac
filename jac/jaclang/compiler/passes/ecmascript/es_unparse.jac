"""ECMAScript/JavaScript code generation from ESTree AST.\n\nThis module provides functionality to convert ESTree AST nodes back to\nJavaScript source code (unparsing).\n"""
import from __future__ { annotations }
import from jaclang.compiler.passes.ecmascript { estree as es }
"""Generate JavaScript code from ESTree AST."""
class JSCodeGenerator {
    """Initialize the code generator."""
    def __init__(self: JSCodeGenerator, indent: str = '  ') -> None {
        self.indent_str = indent;
        self.indent_level = 0;
    }

    """Get current indentation."""
    def indent(self: JSCodeGenerator) -> str {
        return (self.indent_str * self.indent_level);
    }

    """Generate JavaScript code for a node."""
    def generate(self: JSCodeGenerator, <>node: (es.Node | None)) -> str {
        import from jaclang.pycore.helpers { pascal_to_snake }
        if (<>node is None) {
            return '';
        }
        method_name = f"gen_{pascal_to_snake(node.type)}";
        method = getattr(self, method_name, None);
        if method {
            return method(<>node);
        } else {
            return f"/* Unsupported node type: {node.type} */";
        }
    }

    """Generate program."""
    def gen_program(self: JSCodeGenerator, <>node: es.Program) -> str {
        return '\n'.join(self.generate(stmt) for stmt in <>node.body);
    }

    """Generate expression statement."""
    def gen_expression_statement(
        self: JSCodeGenerator, <>node: es.ExpressionStatement
    ) -> str {
        return f"{self.indent()}{self.generate(node.expression)};";
    }

    """Generate block statement."""
    def gen_block_statement(self: JSCodeGenerator, <>node: es.BlockStatement) -> str {
        if not <>node.body {
            return '{}';
        }
        self.indent_level += 1;
        body = '\n'.join(self.generate(stmt) for stmt in <>node.body);
        self.indent_level -= 1;
        return f"{{\n{body}\n{self.indent()}}}";
    }

    """Generate empty statement."""
    def gen_empty_statement(self: JSCodeGenerator, <>node: es.EmptyStatement) -> str {
        return f"{self.indent()};";
    }

    """Generate return statement."""
    def gen_return_statement(self: JSCodeGenerator, <>node: es.ReturnStatement) -> str {
        if <>node.argument {
            return f"{self.indent()}return {self.generate(node.argument)};";
        }
        return f"{self.indent()}return;";
    }

    """Generate if statement."""
    def gen_if_statement(self: JSCodeGenerator, <>node: es.IfStatement) -> str {
        <>test = self.generate(<>node.test);
        consequent = self.generate(<>node.consequent);
        result = f"{self.indent()}if ({test}) {consequent}";
        if <>node.alternate {
            if isinstance(<>node.alternate, es.IfStatement) {
                result += f" else {self.generate(node.alternate).lstrip()}";
            } else {
                result += f" else {self.generate(node.alternate)}";
            }
        }
        return result;
    }

    """Generate while statement."""
    def gen_while_statement(self: JSCodeGenerator, <>node: es.WhileStatement) -> str {
        <>test = self.generate(<>node.test);
        body = self.generate(<>node.body);
        return f"{self.indent()}while ({test}) {body}";
    }

    """Generate do-while statement."""
    def gen_do_while_statement(
        self: JSCodeGenerator, <>node: es.DoWhileStatement
    ) -> str {
        body = self.generate(<>node.body);
        <>test = self.generate(<>node.test);
        return f"{self.indent()}do {body} while ({test});";
    }

    """Generate for statement."""
    def gen_for_statement(self: JSCodeGenerator, <>node: es.ForStatement) -> str {
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

    """Generate for-in statement."""
    def gen_for_in_statement(self: JSCodeGenerator, <>node: es.ForInStatement) -> str {
        left = self.generate(<>node.left);
        right = self.generate(<>node.right);
        body = self.generate(<>node.body);
        return f"{self.indent()}for ({left} in {right}) {body}";
    }

    """Generate for-of statement."""
    def gen_for_of_statement(self: JSCodeGenerator, <>node: es.ForOfStatement) -> str {
        await_str = 'await ' if <>node.await_ else '';
        if isinstance(<>node.left, es.VariableDeclaration) {
            declarators = ', '.join(
                self.generate(decl) for decl in <>node.left.declarations
            );
            left = f"{node.left.kind} {declarators}";
        } else {
            left = self.generate(<>node.left);
        }
        right = self.generate(<>node.right);
        body = self.generate(<>node.body);
        return f"{self.indent()}for {await_str}({left} of {right}) {body}";
    }

    """Generate break statement."""
    def gen_break_statement(self: JSCodeGenerator, <>node: es.BreakStatement) -> str {
        if <>node.label {
            return f"{self.indent()}break {self.generate(node.label)};";
        }
        return f"{self.indent()}break;";
    }

    """Generate continue statement."""
    def gen_continue_statement(
        self: JSCodeGenerator, <>node: es.ContinueStatement
    ) -> str {
        if <>node.label {
            return f"{self.indent()}continue {self.generate(node.label)};";
        }
        return f"{self.indent()}continue;";
    }

    """Generate throw statement."""
    def gen_throw_statement(self: JSCodeGenerator, <>node: es.ThrowStatement) -> str {
        return f"{self.indent()}throw {self.generate(node.argument)};";
    }

    """Generate try statement."""
    def gen_try_statement(self: JSCodeGenerator, <>node: es.TryStatement) -> str {
        result = f"{self.indent()}try {self.generate(node.block)}";
        if <>node.handler {
            result += f" {self.generate(node.handler)}";
        }
        if <>node.finalizer {
            result += f" finally {self.generate(node.finalizer)}";
        }
        return result;
    }

    """Generate catch clause."""
    def gen_catch_clause(self: JSCodeGenerator, <>node: es.CatchClause) -> str {
        if <>node.param {
            return f"catch ({self.generate(node.param)}) {self.generate(node.body)}";
        }
        return f"catch {self.generate(node.body)}";
    }

    """Generate switch statement."""
    def gen_switch_statement(self: JSCodeGenerator, <>node: es.SwitchStatement) -> str {
        discriminant = self.generate(<>node.discriminant);
        self.indent_level += 1;
        cases = '\n'.join(self.generate(<>case) for <>case in <>node.cases);
        self.indent_level -= 1;
        return f"{self.indent()}switch ({discriminant}) {{\n{cases}\n{self.indent()}}}";
    }

    """Generate switch case."""
    def gen_switch_case(self: JSCodeGenerator, <>node: es.SwitchCase) -> str {
        result = f"{self.indent()}case {self.generate(node.test)}:\\n"
        if <>node.test
        else f"{self.indent()}default:\\n";
        self.indent_level += 1;
        for stmt in <>node.consequent {
            result += f"{self.generate(stmt)}\\n";
        }
        self.indent_level -= 1;
        return result.rstrip();
    }

    """Generate function declaration."""
    def gen_function_declaration(
        self: JSCodeGenerator, <>node: es.FunctionDeclaration
    ) -> str {
        async_str = 'async ' if <>node.async_ else '';
        generator_str = '*' if <>node.generator else '';
        name = self.generate(<>node.id) if <>node.id else '';
        params = ', '.join(self.generate(p) for p in <>node.params);
        body = self.generate(<>node.body);
        return f"{self.indent()}{async_str}function{generator_str} {name}({params}) {body}";
    }

    """Generate variable declaration."""
    def gen_variable_declaration(
        self: JSCodeGenerator, <>node: es.VariableDeclaration
    ) -> str {
        declarators = ', '.join(self.generate(d) for d in <>node.declarations);
        return f"{self.indent()}{node.kind} {declarators};";
    }

    """Generate variable declarator."""
    def gen_variable_declarator(
        self: JSCodeGenerator, <>node: es.VariableDeclarator
    ) -> str {
        id_str = self.generate(<>node.id);
        if <>node.<>init {
            return f"{id_str} = {self.generate(node.<>init)}";
        }
        return id_str;
    }

    """Generate class declaration."""
    def gen_class_declaration(
        self: JSCodeGenerator, <>node: es.ClassDeclaration
    ) -> str {
        name = self.generate(<>node.id) if <>node.id else '';
        extends = f" extends {self.generate(node.superClass)}"
        if <>node.superClass
        else '';
        body = self.generate(<>node.body);
        return f"{self.indent()}class {name}{extends} {body}";
    }

    """Generate class expression."""
    def gen_class_expression(self: JSCodeGenerator, <>node: es.ClassExpression) -> str {
        name = self.generate(<>node.id) if <>node.id else '';
        extends = f" extends {self.generate(node.superClass)}"
        if <>node.superClass
        else '';
        body = self.generate(<>node.body);
        return f"class {name}{extends} {body}";
    }

    """Generate class body."""
    def gen_class_body(self: JSCodeGenerator, <>node: es.ClassBody) -> str {
        if not <>node.body {
            return '{}';
        }
        self.indent_level += 1;
        methods = '\n'.join(self.generate(m) for m in <>node.body);
        self.indent_level -= 1;
        return f"{{\n{methods}\n{self.indent()}}}";
    }

    """Generate method definition."""
    def gen_method_definition(
        self: JSCodeGenerator, <>node: es.MethodDefinition
    ) -> str {
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

    """Generate class field definition."""
    def gen_property_definition(
        self: JSCodeGenerator, <>node: es.PropertyDefinition
    ) -> str {
        static_str = 'static ' if <>node.static else '';
        key = self.generate(<>node.key) if <>node.key else '';
        if <>node.computed {
            key = f"[{key}]";
        }
        value = f" = {self.generate(node.value)}" if <>node.value else '';
        return f"{self.indent()}{static_str}{key}{value};";
    }

    """Generate static initialization block."""
    def gen_static_block(self: JSCodeGenerator, <>node: es.StaticBlock) -> str {
        block = self.generate(es.BlockStatement(body=<>node.body));
        return f"{self.indent()}static {block}";
    }

    """Generate identifier."""
    def gen_identifier(self: JSCodeGenerator, <>node: es.Identifier) -> str {
        return <>node.name;
    }

    """Generate private identifier."""
    def gen_private_identifier(
        self: JSCodeGenerator, <>node: es.PrivateIdentifier
    ) -> str {
        return f"\#{node.name}";
    }

    """Generate literal."""
    def gen_literal(self: JSCodeGenerator, <>node: es.Literal) -> str {
        if <>node.raw {
            return <>node.raw;
        }
        if isinstance(<>node.value, str) {
            return f'"{node.value}"';
        } elif (<>node.value is None) {
            return 'null';
        } elif isinstance(<>node.value, bool) {
            return 'true' if <>node.value else 'false';
        } else {
            return str(<>node.value);
        }
    }

    """Generate this expression."""
    def gen_this_expression(self: JSCodeGenerator, <>node: es.ThisExpression) -> str {
        return 'this';
    }

    """Generate array expression."""
    def gen_array_expression(self: JSCodeGenerator, <>node: es.ArrayExpression) -> str {
        elements = ', '.join(self.generate(e) if e else '' for e in <>node.elements);
        return f"[{elements}]";
    }

    """Generate object expression."""
    def gen_object_expression(
        self: JSCodeGenerator, <>node: es.ObjectExpression
    ) -> str {
        if not <>node.properties {
            return '{}';
        }
        props = ', '.join(self.generate(p) for p in <>node.properties);
        return f"{{{props}}}";
    }

    """Generate property."""
    def gen_property(self: JSCodeGenerator, <>node: es.Property) -> str {
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

    """Generate function expression."""
    def gen_function_expression(
        self: JSCodeGenerator, <>node: es.FunctionExpression
    ) -> str {
        async_str = 'async ' if <>node.async_ else '';
        generator_str = '*' if <>node.generator else '';
        name = self.generate(<>node.id) if <>node.id else '';
        params = ', '.join(self.generate(p) for p in <>node.params);
        body = self.generate(<>node.body);
        return f"{async_str}function{generator_str} {name}({params}) {body}".strip();
    }

    """Generate arrow function expression."""
    def gen_arrow_function_expression(
        self: JSCodeGenerator, <>node: es.ArrowFunctionExpression
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

    """Generate unary expression."""
    def gen_unary_expression(self: JSCodeGenerator, <>node: es.UnaryExpression) -> str {
        arg = self.generate(<>node.argument);
        if <>node.prefix {
            if (<>node.operator in ('typeof', 'void', 'delete')) {
                return f"{node.operator} {arg}";
            }
            return f"{node.operator}{arg}";
        } else {
            return f"{arg}{node.operator}";
        }
    }

    """Generate update expression."""
    def gen_update_expression(
        self: JSCodeGenerator, <>node: es.UpdateExpression
    ) -> str {
        arg = self.generate(<>node.argument);
        if <>node.prefix {
            return f"{node.operator}{arg}";
        } else {
            return f"{arg}{node.operator}";
        }
    }

    """Generate binary expression."""
    def gen_binary_expression(
        self: JSCodeGenerator, <>node: es.BinaryExpression
    ) -> str {
        left = self.generate(<>node.left);
        right = self.generate(<>node.right);
        if isinstance(<>node.left, es.AssignmentExpression) {
            left = f"({left})";
        }
        if isinstance(<>node.right, es.AssignmentExpression) {
            right = f"({right})";
        }
        return f"{left} {node.operator} {right}";
    }

    """Generate logical expression."""
    def gen_logical_expression(
        self: JSCodeGenerator, <>node: es.LogicalExpression
    ) -> str {
        left = self.generate(<>node.left);
        right = self.generate(<>node.right);
        return f"{left} {node.operator} {right}";
    }

    """Generate assignment expression."""
    def gen_assignment_expression(
        self: JSCodeGenerator, <>node: es.AssignmentExpression
    ) -> str {
        left = self.generate(<>node.left);
        right = self.generate(<>node.right);
        return f"{left} {node.operator} {right}";
    }

    """Generate member expression."""
    def gen_member_expression(
        self: JSCodeGenerator, <>node: es.MemberExpression
    ) -> str {
        <>obj = self.generate(<>node.object);
        optional = '?.' if <>node.optional else '';
        if <>node.computed {
            prop = self.generate(<>node.property);
            return f"{obj}{optional}[{prop}]";
        } else {
            prop = self.generate(<>node.property);
            if optional {
                return f"{obj}{optional}{prop}";
            }
            return f"{obj}.{prop}";
        }
    }

    """Generate conditional expression."""
    def gen_conditional_expression(
        self: JSCodeGenerator, <>node: es.ConditionalExpression
    ) -> str {
        <>test = self.generate(<>node.test);
        consequent = self.generate(<>node.consequent);
        alternate = self.generate(<>node.alternate);
        return f"{test} ? {consequent} : {alternate}";
    }

    """Generate call expression."""
    def gen_call_expression(self: JSCodeGenerator, <>node: es.CallExpression) -> str {
        callee = self.generate(<>node.callee);
        optional = '?.' if <>node.optional else '';
        if isinstance(<>node.arguments, es.ObjectExpression) {
            args = self.generate(<>node.arguments);
        } else {
            args = ', '.join(self.generate(arg) for arg in <>node.arguments);
        }
        return f"{callee}{optional}({args})";
    }

    """Generate optional chaining expression."""
    def gen_chain_expression(self: JSCodeGenerator, <>node: es.ChainExpression) -> str {
        return self.generate(<>node.expression);
    }

    """Generate new expression."""
    def gen_new_expression(self: JSCodeGenerator, <>node: es.NewExpression) -> str {
        callee = self.generate(<>node.callee);
        if isinstance(<>node.arguments, es.ObjectExpression) {
            args = self.generate(<>node.arguments);
        } else {
            args = ', '.join(self.generate(arg) for arg in <>node.arguments);
        }
        return f"new {callee}({args})";
    }

    """Generate dynamic import expression."""
    def gen_import_expression(
        self: JSCodeGenerator, <>node: es.ImportExpression
    ) -> str {
        source = self.generate(<>node.source) if <>node.source else '';
        return f"import({source})";
    }

    """Generate sequence expression."""
    def gen_sequence_expression(
        self: JSCodeGenerator, <>node: es.SequenceExpression
    ) -> str {
        exprs = ', '.join(self.generate(e) for e in <>node.expressions);
        return f"({exprs})";
    }

    """Generate yield expression."""
    def gen_yield_expression(self: JSCodeGenerator, <>node: es.YieldExpression) -> str {
        delegate = '*' if <>node.delegate else '';
        if <>node.argument {
            return f"yield{delegate} {self.generate(node.argument)}";
        }
        return f"yield{delegate}";
    }

    """Generate await expression."""
    def gen_await_expression(self: JSCodeGenerator, <>node: es.AwaitExpression) -> str {
        return f"await {self.generate(node.argument)}";
    }

    """Generate template literal."""
    def gen_template_literal(self: JSCodeGenerator, <>node: es.TemplateLiteral) -> str {
        parts: list[str] = [];
        for (idx, quasi) in enumerate(<>node.quasis) {
            parts.append(self.generate(quasi));
            if (idx < len(<>node.expressions)) {
                parts.append(f"${{{self.generate(node.expressions[idx])}}}");
            }
        }
        return f"`{''.join(parts)}`";
    }

    """Generate template element."""
    def gen_template_element(self: JSCodeGenerator, <>node: es.TemplateElement) -> str {
        value = <>node.value.get('raw') if <>node.value else '';
        return (value or '');
    }

    """Generate tagged template expression."""
    def gen_tagged_template_expression(
        self: JSCodeGenerator, <>node: es.TaggedTemplateExpression
    ) -> str {
        tag = self.generate(<>node.tag);
        quasi = self.generate(<>node.quasi);
        return f"{tag}{quasi}";
    }

    """Generate spread element."""
    def gen_spread_element(self: JSCodeGenerator, <>node: es.SpreadElement) -> str {
        return f"...{self.generate(node.argument)}";
    }

    """Generate super."""
    def gen_super(self: JSCodeGenerator, <>node: es.Super) -> str {
        return 'super';
    }

    """Generate meta property (e.g., new.target)."""
    def gen_meta_property(self: JSCodeGenerator, <>node: es.MetaProperty) -> str {
        meta = self.generate(<>node.meta) if <>node.meta else '';
        prop = self.generate(<>node.property) if <>node.property else '';
        return f"{meta}.{prop}";
    }

    """Generate array pattern."""
    def gen_array_pattern(self: JSCodeGenerator, <>node: es.ArrayPattern) -> str {
        elements = ', '.join(self.generate(e) if e else '' for e in <>node.elements);
        return f"[{elements}]";
    }

    """Generate object pattern."""
    def gen_object_pattern(self: JSCodeGenerator, <>node: es.ObjectPattern) -> str {
        props = ', '.join(self.generate(p) for p in <>node.properties);
        return f"{{{props}}}";
    }

    """Generate assignment pattern."""
    def gen_assignment_pattern(
        self: JSCodeGenerator, <>node: es.AssignmentPattern
    ) -> str {
        left = self.generate(<>node.left);
        right = self.generate(<>node.right);
        return f"{left} = {right}";
    }

    """Generate rest element."""
    def gen_rest_element(self: JSCodeGenerator, <>node: es.RestElement) -> str {
        return f"...{self.generate(node.argument)}";
    }

    """Generate import declaration."""
    def gen_import_declaration(
        self: JSCodeGenerator, <>node: es.ImportDeclaration
    ) -> str {
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

    """Generate import specifier."""
    def gen_import_specifier(self: JSCodeGenerator, <>node: es.ImportSpecifier) -> str {
        imported = self.generate(<>node.imported);
        local = self.generate(<>node.local);
        if (imported != local) {
            return f"{imported} as {local}";
        }
        return imported;
    }

    """Generate import default specifier."""
    def gen_import_default_specifier(
        self: JSCodeGenerator, <>node: es.ImportDefaultSpecifier
    ) -> str {
        return self.generate(<>node.local);
    }

    """Generate import namespace specifier."""
    def gen_import_namespace_specifier(
        self: JSCodeGenerator, <>node: es.ImportNamespaceSpecifier
    ) -> str {
        return f"* as {self.generate(node.local)}";
    }

    """Generate export named declaration."""
    def gen_export_named_declaration(
        self: JSCodeGenerator, <>node: es.ExportNamedDeclaration
    ) -> str {
        if <>node.declaration {
            return f"{self.indent()}export {self.generate(node.declaration).lstrip()}";
        }
        specs = ', '.join(self.generate(s) for s in <>node.specifiers);
        if <>node.source {
            source = self.generate(<>node.source);
            return f"{self.indent()}export {{{specs}}} from {source};";
        }
        return f"{self.indent()}export {{{specs}}};";
    }

    """Generate export specifier."""
    def gen_export_specifier(self: JSCodeGenerator, <>node: es.ExportSpecifier) -> str {
        local = self.generate(<>node.local);
        exported = self.generate(<>node.exported);
        if (local != exported) {
            return f"{local} as {exported}";
        }
        return local;
    }

    """Generate export default declaration."""
    def gen_export_default_declaration(
        self: JSCodeGenerator, <>node: es.ExportDefaultDeclaration
    ) -> str {
        return f"{self.indent()}export default {self.generate(node.declaration)};";
    }

    """Generate export all declaration."""
    def gen_export_all_declaration(
        self: JSCodeGenerator, <>node: es.ExportAllDeclaration
    ) -> str {
        source = self.generate(<>node.source);
        if <>node.exported {
            exported = self.generate(<>node.exported);
            return f"{self.indent()}export * as {exported} from {source};";
        }
        return f"{self.indent()}export * from {source};";
    }
}

"""Convert an ESTree node to JavaScript code."""
def es_to_js(<>node: (es.Node | None), indent: str = '  ') -> str {
    generator = JSCodeGenerator(indent=indent);
    return generator.generate(<>node);
}
