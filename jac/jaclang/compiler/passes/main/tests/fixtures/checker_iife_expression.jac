with entry {
    # Test: IIFE returning a function
    adder = (
        def make_adder(x: int) {
            return lambda  y: int: x + y;
        }
    )(
        10
    );

    print("Test - IIFE returning function, adder(5):", adder(5));
}
