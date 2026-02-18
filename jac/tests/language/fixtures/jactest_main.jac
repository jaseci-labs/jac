import jactest_imported;

def fib(n: int) -> int {
    if n <= 1 {
        return n;
    }
    return fib(n - 1) + fib(n - 2);
}

test "first two" {
    print("Testing first 2 fibonacci numbers.");
    assert fib(0) == 0;
    assert fib(1) == 0;
}

test "from 2 to 10" {
    print("Testing fibonacci numbers from 2 to 10.");
    for i in range(2, 10) {
        assert fib(i) == fib(i - 1) + fib(i - 2);
    }
}
