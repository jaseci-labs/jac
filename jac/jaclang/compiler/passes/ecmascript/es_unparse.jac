import from jaclang.compiler.passes.ecmascript { estree as es }

obj JSCodeGenerator {
    def init(indent: str = '  ') -> None;

    has line_map: list[tuple[int, int, int]] = [],
        _current_line: int = 1,
        _line_to_src: dict[int, tuple[int, int]] = {};

    def indent -> str;
    def generate(nd: (es.Node | None)) -> str;
    def gen_program(nd: es.Program) -> str;
    def gen_expression_statement(nd: es.ExpressionStatement) -> str;
    def gen_block_statement(nd: es.BlockStatement) -> str;
    def gen_return_statement(nd: es.ReturnStatement) -> str;
    def gen_if_statement(nd: es.IfStatement) -> str;
    def gen_while_statement(nd: es.WhileStatement) -> str;
    def gen_for_statement(nd: es.ForStatement) -> str;
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
    def gen_class_body(nd: es.ClassBody) -> str;
    def gen_method_definition(nd: es.MethodDefinition) -> str;
    def gen_property_definition(nd: es.PropertyDefinition) -> str;
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
    def gen_binary_expression(nd: es.BinaryExpression) -> str;
    def gen_logical_expression(nd: es.LogicalExpression) -> str;
    def gen_assignment_expression(nd: es.AssignmentExpression) -> str;
    def gen_member_expression(nd: es.MemberExpression) -> str;
    def gen_conditional_expression(nd: es.ConditionalExpression) -> str;
    def gen_call_expression(nd: es.CallExpression) -> str;
    def gen_new_expression(nd: es.NewExpression) -> str;
    def gen_await_expression(nd: es.AwaitExpression) -> str;
    def gen_template_literal(nd: es.TemplateLiteral) -> str;
    def gen_template_element(nd: es.TemplateElement) -> str;
    def gen_spread_element(nd: es.SpreadElement) -> str;
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
    def gen_jsx_element(nd: es.JsxElement) -> str;
    def gen_jsx_fragment(nd: es.JsxFragment) -> str;
    def gen_jsx_opening_element(nd: es.JsxOpeningElement) -> str;
    def gen_jsx_closing_element(nd: es.JsxClosingElement) -> str;
    def gen_jsx_attribute(nd: es.JsxAttribute) -> str;
    def gen_jsx_spread_attribute(nd: es.JsxSpreadAttribute) -> str;
    def gen_jsx_expression_container(nd: es.JsxExpressionContainer) -> str;
    def gen_jsx_empty_expression(nd: es.JsxEmptyExpression) -> str;
    def gen_jsx_text(nd: es.JsxText) -> str;
    def gen_jsx_identifier(nd: es.JsxIdentifier) -> str;
    def gen_jsx_member_expression(nd: es.JsxMemberExpression) -> str;
}

def es_to_js(nd: (es.Node | None), indent: str = '  ') -> str;
def es_to_js_with_map(
    nd: (es.Node | None), indent: str = '  '
) -> tuple[str, list[tuple[int, int, int]]];
