import from byllm.lib { MockLLM, MockToolCall }

node Calculator {
    def add(num1: int, num2: int) -> int {
        print(f"Calculator.add called with {num1}, {num2}");
        return num1 + num2;
    }

    # Defining the model here cause we need the reference to self.
    def eval_expr(expression: str) -> str by MockLLM(
        model_name="mockllm",
        config={
            "outputs": [
                MockToolCall(tool=self.add, args={"num1": 12, "num2": 34}),
                "46"
            ],
            "verbose": False
        },
    )(
        tools=[self.add]
    );
}

glob calc = Calculator(),
     result = calc.eval_expr("What is 12 + 34?");

with entry {
    print(f"Result: {result}");
}
