obj FunctionSource {
    def provides(name: str) -> bool abst;
    def resolve(name: str) -> (ir.Function | None) abst;
}

obj LexicalScope {
    has functions: dict[str, ir.Function] = {},
        closures: dict[str, tuple[ir.Function, list[tuple[str, str]]]] = {},
        lambdas: dict[str, list[tuple[str, ir.Value]]] = {},
        parent: (LexicalScope | None) = None,
        source: (FunctionSource | None) = None;

    def function(name: str) -> (ir.Function | None);
    def binds_function(name: str) -> bool;
    def bind_function(name: str, func: ir.Function);
    def unbind_function(name: str);
    def function_entries -> list[tuple[str, ir.Function]];
    def closure(name: str) -> (tuple[ir.Function, list[tuple[str, str]]] | None);
    def bind_closure(name: str, closure: tuple[ir.Function, list[tuple[str, str]]]);
    def lambda_captures(name: str) -> (list[tuple[str, ir.Value]] | None);
    def bind_lambda(name: str, captures: list[tuple[str, ir.Value]]);
    def child -> LexicalScope;
    def outermost -> LexicalScope;
    def chain -> list[LexicalScope];
}
