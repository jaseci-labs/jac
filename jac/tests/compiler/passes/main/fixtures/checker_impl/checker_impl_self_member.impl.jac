"""Impl file with self-member assignments."""

impl TypeEvaluator2.init(program: str) -> None {
    self.program = program;
    self.type_evaluator = TypeEvaluator(program);
}
