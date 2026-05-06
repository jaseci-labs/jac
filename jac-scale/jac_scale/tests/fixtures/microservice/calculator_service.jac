"""Calculator service that depends on math_service via sv import.

Simplest possible cross-service scenario: one module calling
functions in another module over the microservice boundary.
"""

sv import from math_service { add, multiply, divide, DivResult }

"""Sum a list of numbers using the remote add function."""
def:pub sum_list(numbers: list[int]) -> int {
    result = 0;
    for n in numbers {
        result = add(result, n);
    }
    return result;
}

"""Compute dot product using remote add and multiply."""
def:pub dot_product(a: list[int], b: list[int]) -> int {
    result = 0;
    for i in range(len(a)) {
        product = multiply(a[i], b[i]);
        result = add(result, product);
    }
    return result;
}

"""Wraps the remote divide, adding extra context."""
def:pub safe_divide(a: float, b: float) -> DivResult {
    return divide(a, b);
}
