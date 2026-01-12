"""Test closure support in Jac client code."""

cl {
    # Test 1: Simple closure with outer variable
    def make_counter()  -> Any {
        count = 0;

        def increment()  -> int {
            count = count + 1;
            return count;
        }

        return increment;
    }

    # Test 2: Closure returning getter/setter pair
    def create_signal_simple(initialValue: Any) -> list {
        value = initialValue;

        def getter()  -> Any {
            return value;
        }

        def setter(newValue: Any) -> None {
            value = newValue;
        }

        return [getter, setter];
    }

    # Test 3: Lambda closures
    def make_adder(x: int) -> Any {
        return lambda  y: int: x + y;
    }

    # Test 4: Multiple closures sharing state
    def create_shared_counter()  -> dict {
        counter = 0;

        def increment()  -> int {
            counter = counter + 1;
            return counter;
        }

        def decrement()  -> int {
            counter = counter - 1;
            return counter;
        }

        def get_value()  -> int {
            return counter;
        }

        return {"inc": increment, "dec": decrement, "get": get_value};
    }

    # Test entry point
    def test_all_closures()  -> dict {
        # Test 1
        counter = make_counter();
        val1 = counter();
        val2 = counter();

        # Test 2
        [get_count, set_count] = create_signal_simple(100);
        initial = get_count();
        set_count(200);
        updated = get_count();

        # Test 3
        add5 = make_adder(5);
        result = add5(10);

        # Test 4
        shared = create_shared_counter();
        shared["inc"]();
        shared["inc"]();
        count_val = shared["get"]();

        return {
            "counter1": val1,
            "counter2": val2,
            "initial": initial,
            "updated": updated,
            "adder_result": result,
            "shared_count": count_val
        };
    }
}
