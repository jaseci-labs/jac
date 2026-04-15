"""Calculator service — consumer.

Uses sv import to call math_service over HTTP.
Each add()/multiply() call is an RPC to the math_service process.
"""

sv import from math_service { add, multiply }

def:pub sum_list(numbers: list[int]) -> int {
    """Sum a list of numbers — each addition is a cross-service call."""
    result = 0;
    for n in numbers {
        result = add(result, n);
    }
    return result;
}

def:pub dot_product(a: list[int], b: list[int]) -> int {
    """Dot product — uses both add and multiply across services."""
    result = 0;
    for i in range(len(a)) {
        result = add(result, multiply(a[i], b[i]));
    }
    return result;
}
