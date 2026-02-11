"""Minimal fixture for testing method-based tool extraction."""

import from byllm.lib { MockLLM, MockToolCall }

"""Calculator service with tool-based methods."""
obj CalculatorService {
    has precision: int;

    """Add two numbers."""
    def add(a: int, b: int) -> int {
        return a + b;
    }

    """Multiply two numbers."""
    def multiply(a: int, b: int) -> int {
        return a * b;
    }

    """Evaluate a math expression using tools."""
    def eval_expression(expr: str) -> str by MockLLM(
        model_name="mockllm",
        config={
            "outputs": [
                MockToolCall(tool=self.add, args={"a": 10, "b": 5}),
                "Result: 15"
            ],
            "verbose": False
        }
    )(tools=[self.add, self.multiply]);
}

sem CalculatorService = "A calculator service with basic operations.";
sem CalculatorService.precision = "Decimal precision for calculations.";
sem CalculatorService.add = "Add two numbers together.";
sem CalculatorService.add.a = "First number to add.";
sem CalculatorService.add.b = "Second number to add.";
sem CalculatorService.multiply = "Multiply two numbers.";
sem CalculatorService.multiply.a = "First number to multiply.";
sem CalculatorService.multiply.b = "Second number to multiply.";
sem CalculatorService.eval_expression = "Evaluate a mathematical expression.";
sem CalculatorService.eval_expression.expr = "The expression to evaluate.";
