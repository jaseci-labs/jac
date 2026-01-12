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
    def generate(<>node: (es.Node | None)) -> str;
    def gen_program(<>node: es.Program) -> str;
    def gen_expression_statement(<>node: es.ExpressionStatement) -> str;
    def gen_block_statement(<>node: es.BlockStatement) -> str;
    def gen_empty_statement(<>node: es.EmptyStatement) -> str;
    def gen_return_statement(<>node: es.ReturnStatement) -> str;
    def gen_if_statement(<>node: es.IfStatement) -> str;
    def gen_while_statement(<>node: es.WhileStatement) -> str;
    def gen_do_while_statement(<>node: es.DoWhileStatement) -> str;
    def gen_for_statement(<>node: es.ForStatement) -> str;
    def gen_for_in_statement(<>node: es.ForInStatement) -> str;
    def gen_for_of_statement(<>node: es.ForOfStatement) -> str;
    def gen_break_statement(<>node: es.BreakStatement) -> str;
    def gen_continue_statement(<>node: es.ContinueStatement) -> str;
    def gen_throw_statement(<>node: es.ThrowStatement) -> str;
    def gen_try_statement(<>node: es.TryStatement) -> str;
    def gen_catch_clause(<>node: es.CatchClause) -> str;
    def gen_switch_statement(<>node: es.SwitchStatement) -> str;
    def gen_switch_case(<>node: es.SwitchCase) -> str;
    def gen_function_declaration(<>node: es.FunctionDeclaration) -> str;
    def gen_variable_declaration(<>node: es.VariableDeclaration) -> str;
    def gen_variable_declarator(<>node: es.VariableDeclarator) -> str;
    def gen_class_declaration(<>node: es.ClassDeclaration) -> str;
    def gen_class_expression(<>node: es.ClassExpression) -> str;
    def gen_class_body(<>node: es.ClassBody) -> str;
    def gen_method_definition(<>node: es.MethodDefinition) -> str;
    def gen_property_definition(<>node: es.PropertyDefinition) -> str;
    def gen_static_block(<>node: es.StaticBlock) -> str;
    def gen_identifier(<>node: es.Identifier) -> str;
    def gen_private_identifier(<>node: es.PrivateIdentifier) -> str;
    def gen_literal(<>node: es.Literal) -> str;
    def gen_this_expression(<>node: es.ThisExpression) -> str;
    def gen_array_expression(<>node: es.ArrayExpression) -> str;
    def gen_object_expression(<>node: es.ObjectExpression) -> str;
    def gen_property(<>node: es.Property) -> str;
    def gen_function_expression(<>node: es.FunctionExpression) -> str;
    def gen_arrow_function_expression(<>node: es.ArrowFunctionExpression) -> str;
    def gen_unary_expression(<>node: es.UnaryExpression) -> str;
    def gen_update_expression(<>node: es.UpdateExpression) -> str;
    def gen_binary_expression(<>node: es.BinaryExpression) -> str;
    def gen_logical_expression(<>node: es.LogicalExpression) -> str;
    def gen_assignment_expression(<>node: es.AssignmentExpression) -> str;
    def gen_member_expression(<>node: es.MemberExpression) -> str;
    def gen_conditional_expression(<>node: es.ConditionalExpression) -> str;
    def gen_call_expression(<>node: es.CallExpression) -> str;
    def gen_chain_expression(<>node: es.ChainExpression) -> str;
    def gen_new_expression(<>node: es.NewExpression) -> str;
    def gen_import_expression(<>node: es.ImportExpression) -> str;
    def gen_sequence_expression(<>node: es.SequenceExpression) -> str;
    def gen_yield_expression(<>node: es.YieldExpression) -> str;
    def gen_await_expression(<>node: es.AwaitExpression) -> str;
    def gen_template_literal(<>node: es.TemplateLiteral) -> str;
    def gen_template_element(<>node: es.TemplateElement) -> str;
    def gen_tagged_template_expression(<>node: es.TaggedTemplateExpression) -> str;
    def gen_spread_element(<>node: es.SpreadElement) -> str;
    def gen_super(<>node: es.Super) -> str;
    def gen_meta_property(<>node: es.MetaProperty) -> str;
    def gen_array_pattern(<>node: es.ArrayPattern) -> str;
    def gen_object_pattern(<>node: es.ObjectPattern) -> str;
    def gen_assignment_pattern(<>node: es.AssignmentPattern) -> str;
    def gen_rest_element(<>node: es.RestElement) -> str;
    def gen_import_declaration(<>node: es.ImportDeclaration) -> str;
    def gen_import_specifier(<>node: es.ImportSpecifier) -> str;
    def gen_import_default_specifier(<>node: es.ImportDefaultSpecifier) -> str;
    def gen_import_namespace_specifier(<>node: es.ImportNamespaceSpecifier) -> str;
    def gen_export_named_declaration(<>node: es.ExportNamedDeclaration) -> str;
    def gen_export_specifier(<>node: es.ExportSpecifier) -> str;
    def gen_export_default_declaration(<>node: es.ExportDefaultDeclaration) -> str;
    def gen_export_all_declaration(<>node: es.ExportAllDeclaration) -> str;
}

def es_to_js(<>node: (es.Node | None), indent: str = '  ') -> str;
