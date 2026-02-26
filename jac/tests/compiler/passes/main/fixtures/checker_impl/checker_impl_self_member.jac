"""Test self-member assignment in impl files creates valid archetype attributes."""

obj TypeEvaluator {
    def init(program: str) -> None {
        self.program = program;
    }
}

obj TypeEvaluator2 {
    def init(program: str) -> None;
}

glob t1 = TypeEvaluator("test1");
with entry {
    print(t1.program);
}

glob t2 = TypeEvaluator2("test2");
with entry {
    print(t2.program);
    print(t2.type_evaluator.program);
}
