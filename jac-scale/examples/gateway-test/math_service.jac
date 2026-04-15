"""Math service — provider.

Exposes basic math operations as public functions.
Auto-spawned when a consumer does: sv import from math_service { add, multiply }
"""

def:pub add(a: int, b: int) -> int {
    return a + b;
}

def:pub multiply(a: int, b: int) -> int {
    return a * b;
}

def:pub divide(a: float, b: float) -> float {
    if b == 0.0 {
        return 0.0;
    }
    return a / b;
}
