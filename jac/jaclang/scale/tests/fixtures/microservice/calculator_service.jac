"""Calculator service that depends on math_service via sv import.

Simplest possible cross-service scenario: one module calling
functions in another module over the microservice boundary. Every
bridged call is typed-async, so the consumers are async and await it.
"""

import from math_service { add, multiply, divide, DivResult }

"""Sum a list of numbers using the remote add function."""
async def:pub sum_list(numbers: list[int]) -> int {
    result = 0;
    for n in numbers {
        result = await add(result, n);
    }
    return result;
}

"""Compute dot product using remote add and multiply."""
async def:pub dot_product(a: list[int], b: list[int]) -> int {
    result = 0;
    for i in range(len(a)) {
        product = await multiply(a[i], b[i]);
        result = await add(result, product);
    }
    return result;
}

"""Wraps the remote divide, adding extra context."""
async def:pub safe_divide(a: float, b: float) -> DivResult {
    return await divide(a, b);
}

"""Reads attributes off the typed return value of the remote divide.

Unlike `safe_divide` (which passes the DivResult straight back out, so
the cl->sv response re-serializes it), this consumes the archetype IN
the gateway process: `res.result` / `res.error` must resolve as real
attributes. If the sv->sv return value arrives as a plain dict the
attribute access raises `'dict' object has no attribute ...` (#6710)."""
async def:pub describe_divide(a: float, b: float) -> dict {
    res: DivResult = await divide(a, b);
    return {"value": res.result, "error": res.error};
}
