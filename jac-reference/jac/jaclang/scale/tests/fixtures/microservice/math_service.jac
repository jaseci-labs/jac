"""Simple math microservice fixture for basic sv import tests.

No dependencies on other services — used to test the simplest
case of one module importing another via `sv import`.
"""

obj DivResult {
    has result: float | None = None,
        error: str = "";
}

def:pub add(a: int, b: int) -> int {
    return a + b;
}

def:pub multiply(a: int, b: int) -> int {
    return a * b;
}

def:pub divide(a: float, b: float) -> DivResult {
    if b == 0.0 {
        return DivResult(error="division by zero");
    }
    return DivResult(result=a / b);
}
