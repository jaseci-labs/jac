"""
ECMAScript/JavaScript code generation from ESTree AST.

This module provides functionality to convert ESTree AST nodes back to
JavaScript source code (unparsing).
"""
import from __future__ { annotations }
import from jaclang.compiler.passes.ecmascript { estree as es }
"""Generate JavaScript code from ESTree AST."""
class JSCodeGenerator {
    def init(self: JSCodeGenerator, indent: str = '  ') -> None;
    def indent(self: JSCodeGenerator) -> str;
    def generate(self: JSCodeGenerator, <>node: (es.Node | None)) -> str;
    def gen_program(self: JSCodeGenerator, <>node: es.Program) -> str;
    def gen_expression_statement(
        self: JSCodeGenerator, <>node: es.ExpressionStatement
    ) -> str;

    def gen_block_statement(self: JSCodeGenerator, <>node: es.BlockStatement) -> str;
    def gen_empty_statement(self: JSCodeGenerator, <>node: es.EmptyStatement) -> str;
    def gen_return_statement(self: JSCodeGenerator, <>node: es.ReturnStatement) -> str;
    def gen_if_statement(self: JSCodeGenerator, <>node: es.IfStatement) -> str;
    def gen_while_statement(self: JSCodeGenerator, <>node: es.WhileStatement) -> str;
    def gen_do_while_statement(
        self: JSCodeGenerator, <>node: es.DoWhileStatement
    ) -> str;

    def gen_for_statement(self: JSCodeGenerator, <>node: es.ForStatement) -> str;
    def gen_for_in_statement(self: JSCodeGenerator, <>node: es.ForInStatement) -> str;
    def gen_for_of_statement(self: JSCodeGenerator, <>node: es.ForOfStatement) -> str;
    def gen_break_statement(self: JSCodeGenerator, <>node: es.BreakStatement) -> str;
    def gen_continue_statement(
        self: JSCodeGenerator, <>node: es.ContinueStatement
    ) -> str;

    def gen_throw_statement(self: JSCodeGenerator, <>node: es.ThrowStatement) -> str;
    def gen_try_statement(self: JSCodeGenerator, <>node: es.TryStatement) -> str;
    def gen_catch_clause(self: JSCodeGenerator, <>node: es.CatchClause) -> str;
    def gen_switch_statement(self: JSCodeGenerator, <>node: es.SwitchStatement) -> str;
    def gen_switch_case(self: JSCodeGenerator, <>node: es.SwitchCase) -> str;
    def gen_function_declaration(
        self: JSCodeGenerator, <>node: es.FunctionDeclaration
    ) -> str;

    def gen_variable_declaration(
        self: JSCodeGenerator, <>node: es.VariableDeclaration
    ) -> str;

    def gen_variable_declarator(
        self: JSCodeGenerator, <>node: es.VariableDeclarator
    ) -> str;

    def gen_class_declaration(
        self: JSCodeGenerator, <>node: es.ClassDeclaration
    ) -> str;

    def gen_class_expression(self: JSCodeGenerator, <>node: es.ClassExpression) -> str;
    def gen_class_body(self: JSCodeGenerator, <>node: es.ClassBody) -> str;
    def gen_method_definition(
        self: JSCodeGenerator, <>node: es.MethodDefinition
    ) -> str;

    def gen_property_definition(
        self: JSCodeGenerator, <>node: es.PropertyDefinition
    ) -> str;

    def gen_static_block(self: JSCodeGenerator, <>node: es.StaticBlock) -> str;
    def gen_identifier(self: JSCodeGenerator, <>node: es.Identifier) -> str;
    def gen_private_identifier(
        self: JSCodeGenerator, <>node: es.PrivateIdentifier
    ) -> str;

    def gen_literal(self: JSCodeGenerator, <>node: es.Literal) -> str;
    def gen_this_expression(self: JSCodeGenerator, <>node: es.ThisExpression) -> str;
    def gen_array_expression(self: JSCodeGenerator, <>node: es.ArrayExpression) -> str;
    def gen_object_expression(
        self: JSCodeGenerator, <>node: es.ObjectExpression
    ) -> str;

    def gen_property(self: JSCodeGenerator, <>node: es.Property) -> str;
    def gen_function_expression(
        self: JSCodeGenerator, <>node: es.FunctionExpression
    ) -> str;

    def gen_arrow_function_expression(
        self: JSCodeGenerator, <>node: es.ArrowFunctionExpression
    ) -> str;

    def gen_unary_expression(self: JSCodeGenerator, <>node: es.UnaryExpression) -> str;
    def gen_update_expression(
        self: JSCodeGenerator, <>node: es.UpdateExpression
    ) -> str;

    def gen_binary_expression(
        self: JSCodeGenerator, <>node: es.BinaryExpression
    ) -> str;

    def gen_logical_expression(
        self: JSCodeGenerator, <>node: es.LogicalExpression
    ) -> str;

    def gen_assignment_expression(
        self: JSCodeGenerator, <>node: es.AssignmentExpression
    ) -> str;

    def gen_member_expression(
        self: JSCodeGenerator, <>node: es.MemberExpression
    ) -> str;

    def gen_conditional_expression(
        self: JSCodeGenerator, <>node: es.ConditionalExpression
    ) -> str;

    def gen_call_expression(self: JSCodeGenerator, <>node: es.CallExpression) -> str;
    def gen_chain_expression(self: JSCodeGenerator, <>node: es.ChainExpression) -> str;
    def gen_new_expression(self: JSCodeGenerator, <>node: es.NewExpression) -> str;
    def gen_import_expression(
        self: JSCodeGenerator, <>node: es.ImportExpression
    ) -> str;

    def gen_sequence_expression(
        self: JSCodeGenerator, <>node: es.SequenceExpression
    ) -> str;

    def gen_yield_expression(self: JSCodeGenerator, <>node: es.YieldExpression) -> str;
    def gen_await_expression(self: JSCodeGenerator, <>node: es.AwaitExpression) -> str;
    def gen_template_literal(self: JSCodeGenerator, <>node: es.TemplateLiteral) -> str;
    def gen_template_element(self: JSCodeGenerator, <>node: es.TemplateElement) -> str;
    def gen_tagged_template_expression(
        self: JSCodeGenerator, <>node: es.TaggedTemplateExpression
    ) -> str;

    def gen_spread_element(self: JSCodeGenerator, <>node: es.SpreadElement) -> str;
    def gen_super(self: JSCodeGenerator, <>node: es.Super) -> str;
    def gen_meta_property(self: JSCodeGenerator, <>node: es.MetaProperty) -> str;
    def gen_array_pattern(self: JSCodeGenerator, <>node: es.ArrayPattern) -> str;
    def gen_object_pattern(self: JSCodeGenerator, <>node: es.ObjectPattern) -> str;
    def gen_assignment_pattern(
        self: JSCodeGenerator, <>node: es.AssignmentPattern
    ) -> str;

    def gen_rest_element(self: JSCodeGenerator, <>node: es.RestElement) -> str;
    def gen_import_declaration(
        self: JSCodeGenerator, <>node: es.ImportDeclaration
    ) -> str;

    def gen_import_specifier(self: JSCodeGenerator, <>node: es.ImportSpecifier) -> str;
    def gen_import_default_specifier(
        self: JSCodeGenerator, <>node: es.ImportDefaultSpecifier
    ) -> str;

    def gen_import_namespace_specifier(
        self: JSCodeGenerator, <>node: es.ImportNamespaceSpecifier
    ) -> str;

    def gen_export_named_declaration(
        self: JSCodeGenerator, <>node: es.ExportNamedDeclaration
    ) -> str;

    def gen_export_specifier(self: JSCodeGenerator, <>node: es.ExportSpecifier) -> str;
    def gen_export_default_declaration(
        self: JSCodeGenerator, <>node: es.ExportDefaultDeclaration
    ) -> str;

    def gen_export_all_declaration(
        self: JSCodeGenerator, <>node: es.ExportAllDeclaration
    ) -> str;
}

def es_to_js(<>node: (es.Node | None), indent: str = '  ') -> str;
