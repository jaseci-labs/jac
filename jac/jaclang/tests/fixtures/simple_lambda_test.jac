"""Simple test for multi-statement lambda."""

with entry {
    # Test 1: Basic multi-statement lambda
    let add = lambda x: int, y: int -> int {
        let sum = x + y;
        return sum;
    };

    let result = add(3, 4);
    print("Result:", result);
}
