"""
ECMAScript/JavaScript code generation from ESTree AST.

This module provides functionality to convert ESTree AST nodes back to
JavaScript source code (unparsing).
"""

import from jaclang.compiler.passes.ecmascript { estree as es }
"""Generate JavaScript code from ESTree AST."""
obj JSCodeGenerator {
    def init(indent: str = '  ') -> None;
    def indent -> str;
    def generate(nd: (es.Node | None)) -> str;
    def gen_program(nd: es.Program) -> str;
    def gen_expression_statement(nd: es.ExpressionStatement) -> str;
    def gen_block_statement(nd: es.BlockStatement) -> str;
    def gen_empty_statement(nd: es.EmptyStatement) -> str;
    def gen_return_statement(nd: es.ReturnStatement) -> str;
    def gen_if_statement(nd: es.IfStatement) -> str;
    def gen_while_statement(nd: es.WhileStatement) -> str;
    def gen_do_while_statement(nd: es.DoWhileStatement) -> str;
    def gen_for_statement(nd: es.ForStatement) -> str;
    def gen_for_in_statement(nd: es.ForInStatement) -> str;
    def gen_for_of_statement(nd: es.ForOfStatement) -> str;
    def gen_break_statement(nd: es.BreakStatement) -> str;
    def gen_continue_statement(nd: es.ContinueStatement) -> str;
    def gen_throw_statement(nd: es.ThrowStatement) -> str;
    def gen_try_statement(nd: es.TryStatement) -> str;
    def gen_catch_clause(nd: es.CatchClause) -> str;
    def gen_switch_statement(nd: es.SwitchStatement) -> str;
    def gen_switch_case(nd: es.SwitchCase) -> str;
    def gen_function_declaration(nd: es.FunctionDeclaration) -> str;
    def gen_variable_declaration(nd: es.VariableDeclaration) -> str;
    def gen_variable_declarator(nd: es.VariableDeclarator) -> str;
    def gen_class_declaration(nd: es.ClassDeclaration) -> str;
    def gen_class_expression(nd: es.ClassExpression) -> str;
    def gen_class_body(nd: es.ClassBody) -> str;
    def gen_method_definition(nd: es.MethodDefinition) -> str;
    def gen_property_definition(nd: es.PropertyDefinition) -> str;
    def gen_static_block(nd: es.StaticBlock) -> str;
    def gen_identifier(nd: es.Identifier) -> str;
    def gen_private_identifier(nd: es.PrivateIdentifier) -> str;
    def gen_literal(nd: es.Literal) -> str;
    def gen_this_expression(nd: es.ThisExpression) -> str;
    def gen_array_expression(nd: es.ArrayExpression) -> str;
    def gen_object_expression(nd: es.ObjectExpression) -> str;
    def gen_property(nd: es.Property) -> str;
    def gen_function_expression(nd: es.FunctionExpression) -> str;
    def gen_arrow_function_expression(nd: es.ArrowFunctionExpression) -> str;
    def gen_unary_expression(nd: es.UnaryExpression) -> str;
    def gen_update_expression(nd: es.UpdateExpression) -> str;
    def gen_binary_expression(nd: es.BinaryExpression) -> str;
    def gen_logical_expression(nd: es.LogicalExpression) -> str;
    def gen_assignment_expression(nd: es.AssignmentExpression) -> str;
    def gen_member_expression(nd: es.MemberExpression) -> str;
    def gen_conditional_expression(nd: es.ConditionalExpression) -> str;
    def gen_call_expression(nd: es.CallExpression) -> str;
    def gen_chain_expression(nd: es.ChainExpression) -> str;
    def gen_new_expression(nd: es.NewExpression) -> str;
    def gen_import_expression(nd: es.ImportExpression) -> str;
    def gen_sequence_expression(nd: es.SequenceExpression) -> str;
    def gen_yield_expression(nd: es.YieldExpression) -> str;
    def gen_await_expression(nd: es.AwaitExpression) -> str;
    def gen_template_literal(nd: es.TemplateLiteral) -> str;
    def gen_template_element(nd: es.TemplateElement) -> str;
    def gen_tagged_template_expression(nd: es.TaggedTemplateExpression) -> str;
    def gen_spread_element(nd: es.SpreadElement) -> str;
    def gen_super(nd: es.Super) -> str;
    def gen_meta_property(nd: es.MetaProperty) -> str;
    def gen_array_pattern(nd: es.ArrayPattern) -> str;
    def gen_object_pattern(nd: es.ObjectPattern) -> str;
    def gen_assignment_pattern(nd: es.AssignmentPattern) -> str;
    def gen_rest_element(nd: es.RestElement) -> str;
    def gen_import_declaration(nd: es.ImportDeclaration) -> str;
    def gen_import_specifier(nd: es.ImportSpecifier) -> str;
    def gen_import_default_specifier(nd: es.ImportDefaultSpecifier) -> str;
    def gen_import_namespace_specifier(nd: es.ImportNamespaceSpecifier) -> str;
    def gen_export_named_declaration(nd: es.ExportNamedDeclaration) -> str;
    def gen_export_specifier(nd: es.ExportSpecifier) -> str;
    def gen_export_default_declaration(nd: es.ExportDefaultDeclaration) -> str;
    def gen_export_all_declaration(nd: es.ExportAllDeclaration) -> str;
}

def es_to_js(nd: (es.Node | None), indent: str = '  ') -> str;
