import from jaclang.compiler.ir.types.nodes { TypeBase }
import from jaclang.compiler.pipeline.program_pass { QueryTransform }
import jaclang.compiler.ir.schema as uni;

walker TypeQueryPass(QueryTransform[TypeBase | None]) {
    has query: uni.Expr | uni.Symbol,
        result: TypeBase | None = None;

    def transform(ir_in: uni.Module) -> uni.Module {
        evaluator = self.prog.get_type_evaluator();
        if isinstance(self.query, uni.Expr) {
            self.result = evaluator.get_type_of_expression(self.query);
        } else {
            provider = self.query.provider;
            self.result = provider.resolve_type(self.query)
                if provider is not None
                else evaluator.get_type_of_symbol(self.query);
        }
        return ir_in;
    }
}
