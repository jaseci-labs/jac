import from jaclang.compiler.passes.compose { kotlin_ast as kt }

obj KotlinCodeGenerator {
    def init(indent: str = "    ") -> None;

    has indent_str: str = "    ",
        indent_level: int = 0;

    def indent -> str;
    def generate(nd: (kt.KtNode | None)) -> str;
    def gen_kt_identifier(nd: kt.KtIdentifier) -> str;
    def gen_kt_literal(nd: kt.KtLiteral) -> str;
    def gen_kt_string_template(nd: kt.KtStringTemplate) -> str;
    def gen_kt_this(nd: kt.KtThis) -> str;
    def gen_kt_member_access(nd: kt.KtMemberAccess) -> str;
    def gen_kt_call(nd: kt.KtCall) -> str;
    def gen_kt_binary(nd: kt.KtBinary) -> str;
    def gen_kt_unary(nd: kt.KtUnary) -> str;
    def gen_kt_conditional(nd: kt.KtConditional) -> str;
    def gen_kt_assignment(nd: kt.KtAssignment) -> str;
    def gen_kt_lambda(nd: kt.KtLambda) -> str;
    def gen_kt_list_literal(nd: kt.KtListLiteral) -> str;
    def gen_kt_map_literal(nd: kt.KtMapLiteral) -> str;
    def gen_kt_spread(nd: kt.KtSpread) -> str;
    def gen_kt_raw(nd: kt.KtRaw) -> str;
    def gen_kt_expr_stmt(nd: kt.KtExprStmt) -> str;
    def gen_kt_block(nd: kt.KtBlock) -> str;
    def gen_kt_property(nd: kt.KtProperty) -> str;
    def gen_kt_if(nd: kt.KtIf) -> str;
    def gen_kt_for(nd: kt.KtFor) -> str;
    def gen_kt_while(nd: kt.KtWhile) -> str;
    def gen_kt_return(nd: kt.KtReturn) -> str;
    def gen_kt_try(nd: kt.KtTry) -> str;
    def gen_kt_throw(nd: kt.KtThrow) -> str;
    def gen_kt_break(nd: kt.KtBreak) -> str;
    def gen_kt_continue(nd: kt.KtContinue) -> str;
    def gen_kt_when(nd: kt.KtWhen) -> str;
    def gen_kt_function(nd: kt.KtFunction) -> str;
    def gen_kt_class(nd: kt.KtClass) -> str;
    def gen_kt_object(nd: kt.KtObject) -> str;
    def gen_kt_import(nd: kt.KtImport) -> str;
    def gen_kt_file(nd: kt.KtFile) -> str;
    def gen_kt_modifier_chain(nd: kt.KtModifierChain) -> str;
    def gen_kt_composable_call(nd: kt.KtComposableCall) -> str;
    def _gen_body(stmts: list[kt.KtNode]) -> str;
    def _escape_string(value: str) -> str;
    def _escape_ident(name: str) -> str;
}

def kt_to_source(nd: (kt.KtNode | None), indent: str = "    ") -> str;
def escape_kotlin_string(value: str) -> str;
