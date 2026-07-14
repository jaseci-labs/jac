"""Safely evaluate a math expression"""
def calculate(expr: str) -> str {
    import ast;
    import operator;
    _ops = {
        ast.Add: operator.add,
        ast.Sub: operator.sub,
        ast.Mult: operator.mul,
        ast.Div: operator.truediv,
        ast.Pow: operator.pow,
        ast.USub: operator.neg,
    };
    def _eval(n: ast.AST) -> float {
        if isinstance(n, ast.Expression) { return _eval(n.body); }
        if isinstance(n, ast.Constant) and isinstance(n.value, (int, float)) { return n.value; }
        if isinstance(n, ast.BinOp) and type(n.op) in _ops { return _ops[type(n.op)](_eval(n.left), _eval(n.right)); }
        if isinstance(n, ast.UnaryOp) and type(n.op) in _ops { return _ops[type(n.op)](_eval(n.operand)); }
        raise ValueError(f"Unsupported expression: {ast.dump(n)}");
    }
    try {
        return str(_eval(ast.parse(expr, mode='eval')));
    } except Exception as e {
        return "Error while evaluating expression.";
    }
}

"""Run and verify Python code."""
def run_and_test_python_code(code: str) -> str {
    # TEST FIXTURE ONLY — This function is for integration testing with MockLLM
    # and should NEVER be used as a template for production tools.
    # Executing arbitrary code is inherently unsafe; restrict to numeric-only
    # evaluation (ast.literal_eval) or sandboxed environments in production.
    try {
        exec(code, {}, {});
        return "Code executed successfully.";
    } except Exception as e {
        return "Execution error while running code.";
    }
}
