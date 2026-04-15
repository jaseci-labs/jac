"""Calculator service — consumer.

Uses sv import to call math_service over HTTP.
Each add()/multiply() call is an RPC to the math_service process.

sum_list: sum a list of numbers (each addition is a cross-service call).
dot_product: dot product using both add and multiply across services.
"""

sv import from math_service { add, multiply }

def:pub sum_list(numbers: list[int]) -> int {
    result = 0;
    for n in numbers {
        result = add(result, n);
    }
    return result;
}

def:pub dot_product(a: list[int], b: list[int]) -> int {
    result = 0;
    for i in range(len(a)) {
        product = multiply(a[i], b[i]);
        result = add(result, product);
    }
    return result;
}
