"""Simple test for multi-statement lambda."""

with entry {
    # Test 1: Basic multi-statement lambda
    add = lambda  x: int , y: int  -> int{ sum = x + y;return sum; } ;

    result = add(3, 4);
    print("Result:", result);
}
