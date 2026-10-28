walker GraphLoweringPass(TreePass) {
    static has contract: PassContract = PassContract(kernel_safe=True);
    has _serial: int = 0,
        _names: set[str] = set(),
        _builder_type: str = "",
        _ports_type: str = "",
        _capture: bool = True;

    can prepare with entry;
    def runtime_import(at: uni.GraphExpr) -> uni.Import;
    def fresh(label: str) -> str;
    def name(value: str, at: uni.UniNode) -> uni.Name;
    def attr(owner: str, member: str, at: uni.UniNode) -> uni.AtomTrailer;
    def call(target: uni.Expr, args: list[uni.Expr]) -> uni.FuncCall;
    def assign(value: uni.Expr, body: list[uni.CodeBlockStmt], at: uni.UniNode) -> str;
    def parallel(
        values: list[uni.Expr],
        builder: str,
        body: list[uni.CodeBlockStmt],
        at: uni.UniNode
    ) -> str;

    def lower(expr: uni.Expr, builder: str, body: list[uni.CodeBlockStmt]) -> str;
    can exit_graph_expr with uni.GraphExpr exit;
}
