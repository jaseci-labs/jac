"""ECMAScript/JavaScript code generation from ESTree AST.

This module provides functionality to convert ESTree AST nodes back to
JavaScript source code (unparsing).
"""

from __future__ import annotations

from jaclang.compiler.passes.ecmascript import estree as es
from jaclang.utils.helpers import pascal_to_snake


class JSCodeGenerator:
    """Generate JavaScript code from ESTree AST."""

    def __init__(self, indent: str = "  ") -> None:
        """Initialize the code generator."""
        self.indent_str = indent
        self.indent_level = 0

    def indent(self) -> str:
        """Get current indentation."""
        return self.indent_str * self.indent_level

    def generate(self, node: es.Node) -> str:
        """Generate JavaScript code for a node."""
        method_name = f"gen_{pascal_to_snake(node.type)}"
        method = getattr(self, method_name, None)
        if method:
            return method(node)
        else:
            return f"/* Unsupported node type: {node.type} */"

    # Program and Statements
    # ======================

    def gen_program(self, node: es.Program) -> str:
        """Generate program."""
        return "\n".join(self.generate(stmt) for stmt in node.body)

    def gen_expression_statement(self, node: es.ExpressionStatement) -> str:
        """Generate expression statement."""
        return f"{self.indent()}{self.generate(node.expression)};"

    def gen_block_statement(self, node: es.BlockStatement) -> str:
        """Generate block statement."""
        if not node.body:
            return "{}"
        self.indent_level += 1
        body = "\n".join(self.generate(stmt) for stmt in node.body)
        self.indent_level -= 1
        return f"{{\n{body}\n{self.indent()}}}"

    def gen_empty_statement(self, node: es.EmptyStatement) -> str:
        """Generate empty statement."""
        return f"{self.indent()};"

    def gen_return_statement(self, node: es.ReturnStatement) -> str:
        """Generate return statement."""
        if node.argument:
            return f"{self.indent()}return {self.generate(node.argument)};"
        return f"{self.indent()}return;"

    def gen_if_statement(self, node: es.IfStatement) -> str:
        """Generate if statement."""
        test = self.generate(node.test)
        consequent = self.generate(node.consequent)
        result = f"{self.indent()}if ({test}) {consequent}"
        if node.alternate:
            if isinstance(node.alternate, es.IfStatement):
                # else if
                result += f" else {self.generate(node.alternate).lstrip()}"
            else:
                result += f" else {self.generate(node.alternate)}"
        return result

    def gen_while_statement(self, node: es.WhileStatement) -> str:
        """Generate while statement."""
        test = self.generate(node.test)
        body = self.generate(node.body)
        return f"{self.indent()}while ({test}) {body}"

    def gen_do_while_statement(self, node: es.DoWhileStatement) -> str:
        """Generate do-while statement."""
        body = self.generate(node.body)
        test = self.generate(node.test)
        return f"{self.indent()}do {body} while ({test});"

    def gen_for_statement(self, node: es.ForStatement) -> str:
        """Generate for statement."""
        init = self.generate(node.init) if node.init else ""
        test = self.generate(node.test) if node.test else ""
        update = self.generate(node.update) if node.update else ""
        body = self.generate(node.body)
        return f"{self.indent()}for ({init}; {test}; {update}) {body}"

    def gen_for_in_statement(self, node: es.ForInStatement) -> str:
        """Generate for-in statement."""
        left = self.generate(node.left)
        right = self.generate(node.right)
        body = self.generate(node.body)
        return f"{self.indent()}for ({left} in {right}) {body}"

    def gen_for_of_statement(self, node: es.ForOfStatement) -> str:
        """Generate for-of statement."""
        await_str = "await " if node.await_ else ""
        if isinstance(node.left, es.VariableDeclaration):
            declarators = ", ".join(
                self.generate(decl) for decl in node.left.declarations
            )
            left = f"{node.left.kind} {declarators}"
        else:
            left = self.generate(node.left)
        right = self.generate(node.right)
        body = self.generate(node.body)
        return f"{self.indent()}for {await_str}({left} of {right}) {body}"

    def gen_break_statement(self, node: es.BreakStatement) -> str:
        """Generate break statement."""
        if node.label:
            return f"{self.indent()}break {self.generate(node.label)};"
        return f"{self.indent()}break;"

    def gen_continue_statement(self, node: es.ContinueStatement) -> str:
        """Generate continue statement."""
        if node.label:
            return f"{self.indent()}continue {self.generate(node.label)};"
        return f"{self.indent()}continue;"

    def gen_throw_statement(self, node: es.ThrowStatement) -> str:
        """Generate throw statement."""
        return f"{self.indent()}throw {self.generate(node.argument)};"

    def gen_try_statement(self, node: es.TryStatement) -> str:
        """Generate try statement."""
        result = f"{self.indent()}try {self.generate(node.block)}"
        if node.handler:
            result += f" {self.generate(node.handler)}"
        if node.finalizer:
            result += f" finally {self.generate(node.finalizer)}"
        return result

    def gen_catch_clause(self, node: es.CatchClause) -> str:
        """Generate catch clause."""
        if node.param:
            return f"catch ({self.generate(node.param)}) {self.generate(node.body)}"
        return f"catch {self.generate(node.body)}"

    def gen_switch_statement(self, node: es.SwitchStatement) -> str:
        """Generate switch statement."""
        discriminant = self.generate(node.discriminant)
        self.indent_level += 1
        cases = "\n".join(self.generate(case) for case in node.cases)
        self.indent_level -= 1
        return f"{self.indent()}switch ({discriminant}) {{\n{cases}\n{self.indent()}}}"

    def gen_switch_case(self, node: es.SwitchCase) -> str:
        """Generate switch case."""
        if node.test:
            result = f"{self.indent()}case {self.generate(node.test)}:\n"
        else:
            result = f"{self.indent()}default:\n"
        self.indent_level += 1
        for stmt in node.consequent:
            result += f"{self.generate(stmt)}\n"
        self.indent_level -= 1
        return result.rstrip()

    # Declarations
    # ============

    def gen_function_declaration(self, node: es.FunctionDeclaration) -> str:
        """Generate function declaration."""
        async_str = "async " if node.async_ else ""
        generator_str = "*" if node.generator else ""
        name = self.generate(node.id) if node.id else ""
        params = ", ".join(self.generate(p) for p in node.params)
        body = self.generate(node.body)
        return (
            f"{self.indent()}{async_str}function{generator_str} {name}({params}) {body}"
        )

    def gen_variable_declaration(self, node: es.VariableDeclaration) -> str:
        """Generate variable declaration."""
        declarators = ", ".join(self.generate(d) for d in node.declarations)
        return f"{self.indent()}{node.kind} {declarators};"

    def gen_variable_declarator(self, node: es.VariableDeclarator) -> str:
        """Generate variable declarator."""
        id_str = self.generate(node.id)
        if node.init:
            return f"{id_str} = {self.generate(node.init)}"
        return id_str

    def gen_class_declaration(self, node: es.ClassDeclaration) -> str:
        """Generate class declaration."""
        name = self.generate(node.id) if node.id else ""
        extends = (
            f" extends {self.generate(node.superClass)}" if node.superClass else ""
        )
        body = self.generate(node.body)
        return f"{self.indent()}class {name}{extends} {body}"

    def gen_class_expression(self, node: es.ClassExpression) -> str:
        """Generate class expression."""
        name = self.generate(node.id) if node.id else ""
        extends = (
            f" extends {self.generate(node.superClass)}" if node.superClass else ""
        )
        body = self.generate(node.body)
        return f"class {name}{extends} {body}"

    def gen_class_body(self, node: es.ClassBody) -> str:
        """Generate class body."""
        if not node.body:
            return "{}"
        self.indent_level += 1
        methods = "\n".join(self.generate(m) for m in node.body)
        self.indent_level -= 1
        return f"{{\n{methods}\n{self.indent()}}}"

    def gen_method_definition(self, node: es.MethodDefinition) -> str:
        """Generate method definition."""
        static_str = "static " if node.static else ""
        key = self.generate(node.key)
        value = self.generate(node.value)

        # Extract function parts
        if isinstance(node.value, es.FunctionExpression):
            async_str = "async " if node.value.async_ else ""
            params = ", ".join(self.generate(p) for p in node.value.params)
            body = self.generate(node.value.body)

            if node.kind == "constructor":
                return f"{self.indent()}constructor({params}) {body}"
            elif node.kind == "get":
                return f"{self.indent()}{static_str}get {key}() {body}"
            elif node.kind == "set":
                return f"{self.indent()}{static_str}set {key}({params}) {body}"
            else:
                return f"{self.indent()}{static_str}{async_str}{key}({params}) {body}"

        return f"{self.indent()}{static_str}{key}{value}"

    def gen_property_definition(self, node: es.PropertyDefinition) -> str:
        """Generate class field definition."""
        static_str = "static " if node.static else ""
        key = self.generate(node.key) if node.key else ""
        if node.computed:
            key = f"[{key}]"
        value = f" = {self.generate(node.value)}" if node.value else ""
        return f"{self.indent()}{static_str}{key}{value};"

    def gen_static_block(self, node: es.StaticBlock) -> str:
        """Generate static initialization block."""
        block = self.generate(es.BlockStatement(body=node.body))
        return f"{self.indent()}static {block}"

    # Expressions
    # ===========

    def gen_identifier(self, node: es.Identifier) -> str:
        """Generate identifier."""
        return node.name

    def gen_private_identifier(self, node: es.PrivateIdentifier) -> str:
        """Generate private identifier."""
        return f"#{node.name}"

    def gen_literal(self, node: es.Literal) -> str:
        """Generate literal."""
        if node.raw:
            return node.raw
        if isinstance(node.value, str):
            return f'"{node.value}"'
        elif node.value is None:
            return "null"
        elif isinstance(node.value, bool):
            return "true" if node.value else "false"
        else:
            return str(node.value)

    def gen_this_expression(self, node: es.ThisExpression) -> str:
        """Generate this expression."""
        return "this"

    def gen_array_expression(self, node: es.ArrayExpression) -> str:
        """Generate array expression."""
        elements = ", ".join(self.generate(e) if e else "" for e in node.elements)
        return f"[{elements}]"

    def gen_object_expression(self, node: es.ObjectExpression) -> str:
        """Generate object expression."""
        if not node.properties:
            return "{}"
        props = ", ".join(self.generate(p) for p in node.properties)
        return f"{{{props}}}"

    def gen_property(self, node: es.Property) -> str:
        """Generate property."""
        key = self.generate(node.key)
        value = self.generate(node.value)

        if node.shorthand:
            return key
        elif node.computed:
            return f"[{key}]: {value}"
        elif node.kind == "get":
            return f"get {key}() {value}"
        elif node.kind == "set":
            return f"set {key}({value})"
        else:
            return f"{key}: {value}"

    def gen_function_expression(self, node: es.FunctionExpression) -> str:
        """Generate function expression."""
        async_str = "async " if node.async_ else ""
        generator_str = "*" if node.generator else ""
        name = self.generate(node.id) if node.id else ""
        params = ", ".join(self.generate(p) for p in node.params)
        body = self.generate(node.body)
        return f"{async_str}function{generator_str} {name}({params}) {body}".strip()

    def gen_arrow_function_expression(self, node: es.ArrowFunctionExpression) -> str:
        """Generate arrow function expression."""
        async_str = "async " if node.async_ else ""
        params = ", ".join(self.generate(p) for p in node.params)
        if len(node.params) == 1:
            params = self.generate(node.params[0])
        else:
            params = f"({params})"

        if node.expression:
            body = self.generate(node.body)
            return f"{async_str}{params} => {body}"
        else:
            body = self.generate(node.body)
            return f"{async_str}{params} => {body}"

    def gen_unary_expression(self, node: es.UnaryExpression) -> str:
        """Generate unary expression."""
        arg = self.generate(node.argument)
        if node.prefix:
            if node.operator in ("typeof", "void", "delete"):
                return f"{node.operator} {arg}"
            return f"{node.operator}{arg}"
        else:
            return f"{arg}{node.operator}"

    def gen_update_expression(self, node: es.UpdateExpression) -> str:
        """Generate update expression."""
        arg = self.generate(node.argument)
        if node.prefix:
            return f"{node.operator}{arg}"
        else:
            return f"{arg}{node.operator}"

    def gen_binary_expression(self, node: es.BinaryExpression) -> str:
        """Generate binary expression."""
        left = self.generate(node.left)
        right = self.generate(node.right)
        if isinstance(node.left, es.AssignmentExpression):
            left = f"({left})"
        if isinstance(node.right, es.AssignmentExpression):
            right = f"({right})"
        return f"{left} {node.operator} {right}"

    def gen_logical_expression(self, node: es.LogicalExpression) -> str:
        """Generate logical expression."""
        left = self.generate(node.left)
        right = self.generate(node.right)
        return f"{left} {node.operator} {right}"

    def gen_assignment_expression(self, node: es.AssignmentExpression) -> str:
        """Generate assignment expression."""
        left = self.generate(node.left)
        right = self.generate(node.right)
        return f"{left} {node.operator} {right}"

    def gen_member_expression(self, node: es.MemberExpression) -> str:
        """Generate member expression."""
        obj = self.generate(node.object)
        optional = "?." if node.optional else ""
        if node.computed:
            prop = self.generate(node.property)
            return f"{obj}{optional}[{prop}]"
        else:
            prop = self.generate(node.property)
            if optional:
                return f"{obj}{optional}{prop}"
            return f"{obj}.{prop}"

    def gen_conditional_expression(self, node: es.ConditionalExpression) -> str:
        """Generate conditional expression."""
        test = self.generate(node.test)
        consequent = self.generate(node.consequent)
        alternate = self.generate(node.alternate)
        return f"{test} ? {consequent} : {alternate}"

    def gen_call_expression(self, node: es.CallExpression) -> str:
        """Generate call expression."""
        callee = self.generate(node.callee)
        optional = "?." if node.optional else ""
        args = ", ".join(self.generate(arg) for arg in node.arguments)
        return f"{callee}{optional}({args})"

    def gen_chain_expression(self, node: es.ChainExpression) -> str:
        """Generate optional chaining expression."""
        return self.generate(node.expression)

    def gen_new_expression(self, node: es.NewExpression) -> str:
        """Generate new expression."""
        callee = self.generate(node.callee)
        args = ", ".join(self.generate(arg) for arg in node.arguments)
        return f"new {callee}({args})"

    def gen_import_expression(self, node: es.ImportExpression) -> str:
        """Generate dynamic import expression."""
        source = self.generate(node.source) if node.source else ""
        return f"import({source})"

    def gen_sequence_expression(self, node: es.SequenceExpression) -> str:
        """Generate sequence expression."""
        exprs = ", ".join(self.generate(e) for e in node.expressions)
        return f"({exprs})"

    def gen_yield_expression(self, node: es.YieldExpression) -> str:
        """Generate yield expression."""
        delegate = "*" if node.delegate else ""
        if node.argument:
            return f"yield{delegate} {self.generate(node.argument)}"
        return f"yield{delegate}"

    def gen_await_expression(self, node: es.AwaitExpression) -> str:
        """Generate await expression."""
        return f"await {self.generate(node.argument)}"

    def gen_template_literal(self, node: es.TemplateLiteral) -> str:
        """Generate template literal."""
        parts: list[str] = []
        for idx, quasi in enumerate(node.quasis):
            parts.append(self.generate(quasi))
            if idx < len(node.expressions):
                parts.append(f"${{{self.generate(node.expressions[idx])}}}")
        return f"`{''.join(parts)}`"

    def gen_template_element(self, node: es.TemplateElement) -> str:
        """Generate template element."""
        value = node.value.get("raw") if node.value else ""
        return value or ""

    def gen_tagged_template_expression(self, node: es.TaggedTemplateExpression) -> str:
        """Generate tagged template expression."""
        tag = self.generate(node.tag)
        quasi = self.generate(node.quasi)
        return f"{tag}{quasi}"

    def gen_spread_element(self, node: es.SpreadElement) -> str:
        """Generate spread element."""
        return f"...{self.generate(node.argument)}"

    def gen_super(self, node: es.Super) -> str:
        """Generate super."""
        return "super"

    def gen_meta_property(self, node: es.MetaProperty) -> str:
        """Generate meta property (e.g., new.target)."""
        meta = self.generate(node.meta) if node.meta else ""
        prop = self.generate(node.property) if node.property else ""
        return f"{meta}.{prop}"

    # Patterns
    # ========

    def gen_array_pattern(self, node: es.ArrayPattern) -> str:
        """Generate array pattern."""
        elements = ", ".join(self.generate(e) if e else "" for e in node.elements)
        return f"[{elements}]"

    def gen_object_pattern(self, node: es.ObjectPattern) -> str:
        """Generate object pattern."""
        props = ", ".join(self.generate(p) for p in node.properties)
        return f"{{{props}}}"

    def gen_assignment_pattern(self, node: es.AssignmentPattern) -> str:
        """Generate assignment pattern."""
        left = self.generate(node.left)
        right = self.generate(node.right)
        return f"{left} = {right}"

    def gen_rest_element(self, node: es.RestElement) -> str:
        """Generate rest element."""
        return f"...{self.generate(node.argument)}"

    # Modules
    # =======

    def gen_import_declaration(self, node: es.ImportDeclaration) -> str:
        """Generate import declaration."""
        default_spec: str | None = None
        namespace_spec: str | None = None
        named_specs: list[str] = []

        for spec in node.specifiers:
            if isinstance(spec, es.ImportDefaultSpecifier):
                default_spec = self.generate(spec)
            elif isinstance(spec, es.ImportNamespaceSpecifier):
                namespace_spec = self.generate(spec)
            elif isinstance(spec, es.ImportSpecifier):
                named_specs.append(self.generate(spec))

        clause_parts: list[str] = []
        if default_spec:
            clause_parts.append(default_spec)
        if namespace_spec:
            clause_parts.append(namespace_spec)
        if named_specs:
            clause_parts.append("{ " + ", ".join(named_specs) + " }")

        source = self.generate(node.source)
        if clause_parts:
            clause = ", ".join(clause_parts)
            return f"{self.indent()}import {clause} from {source};"
        return f"{self.indent()}import {source};"

    def gen_import_specifier(self, node: es.ImportSpecifier) -> str:
        """Generate import specifier."""
        imported = self.generate(node.imported)
        local = self.generate(node.local)
        if imported != local:
            return f"{imported} as {local}"
        return imported

    def gen_import_default_specifier(self, node: es.ImportDefaultSpecifier) -> str:
        """Generate import default specifier."""
        return self.generate(node.local)

    def gen_import_namespace_specifier(self, node: es.ImportNamespaceSpecifier) -> str:
        """Generate import namespace specifier."""
        return f"* as {self.generate(node.local)}"

    def gen_export_named_declaration(self, node: es.ExportNamedDeclaration) -> str:
        """Generate export named declaration."""
        if node.declaration:
            return f"{self.indent()}export {self.generate(node.declaration).lstrip()}"
        specs = ", ".join(self.generate(s) for s in node.specifiers)
        if node.source:
            source = self.generate(node.source)
            return f"{self.indent()}export {{{specs}}} from {source};"
        return f"{self.indent()}export {{{specs}}};"

    def gen_export_specifier(self, node: es.ExportSpecifier) -> str:
        """Generate export specifier."""
        local = self.generate(node.local)
        exported = self.generate(node.exported)
        if local != exported:
            return f"{local} as {exported}"
        return local

    def gen_export_default_declaration(self, node: es.ExportDefaultDeclaration) -> str:
        """Generate export default declaration."""
        return f"{self.indent()}export default {self.generate(node.declaration)};"

    def gen_export_all_declaration(self, node: es.ExportAllDeclaration) -> str:
        """Generate export all declaration."""
        source = self.generate(node.source)
        if node.exported:
            exported = self.generate(node.exported)
            return f"{self.indent()}export * as {exported} from {source};"
        return f"{self.indent()}export * from {source};"


def es_to_js(node: es.Node, indent: str = "  ") -> str:
    """Convert an ESTree node to JavaScript code."""
    generator = JSCodeGenerator(indent=indent)
    return generator.generate(node)
