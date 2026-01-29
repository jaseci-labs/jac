"""Test reactive state management primitives."""

cl import from "@jac/runtime" { createSignal, createState, createEffect, }

cl {
    # Test 1: Basic signal get/set
    def test_signal_basic()  -> dict {
        [count, setCount] = createSignal(0);

        initial = count();
        setCount(5);
        updated = count();
        setCount(10);
        final = count();

        return {"initial": initial, "updated": updated, "final": final};
    }

    # Test 2: Signal with effect tracking
    def test_signal_with_effect()  -> dict {
        [count, setCount] = createSignal(0);
        effectRuns = 0;
        lastValue = 0;

        createEffect(
            lambda   -> None{ effectRuns = effectRuns + 1;lastValue = count();  # Track dependency
            }
        );

        # Effect should have run once on creation
        runsAfterCreate = effectRuns;

        setCount(5);  # Should trigger effect
        runsAfterSet = effectRuns;
        valueAfterSet = lastValue;

        return {
            "runsAfterCreate": runsAfterCreate,
            "runsAfterSet": runsAfterSet,
            "valueAfterSet": valueAfterSet
        };
    }

    # Test 3: State object with shallow merge
    def test_state_object()  -> dict {
        [state, setState] = createState({"count": 0, "name": "Alice"});

        initial = state();

        # Update just count
        setState({"count": 5});
        afterCountUpdate = state();

        # Update just name
        setState({"name": "Bob"});
        afterNameUpdate = state();

        return {
            "initialCount": initial.count,
            "initialName": initial.name,
            "afterCountUpdate": afterCountUpdate.count,
            "afterNameUpdate": afterNameUpdate.name,
            "finalCount": afterNameUpdate.count
        };
    }

    # Test 4: Multiple signals
    def test_multiple_signals()  -> dict {
        [firstName, setFirstName] = createSignal("Alice");
        [lastName, setLastName] = createSignal("Smith");

        fullName1 = firstName() + " " + lastName();

        setFirstName("Bob");
        fullName2 = firstName() + " " + lastName();

        setLastName("Jones");
        fullName3 = firstName() + " " + lastName();

        return {"fullName1": fullName1, "fullName2": fullName2, "fullName3": fullName3};
    }

    # Test 5: Signal equality check (should not trigger on same value)
    def test_signal_equality()  -> dict {
        [count, setCount] = createSignal(5);
        effectRuns = 0;

        createEffect(
            lambda   -> None{ effectRuns = effectRuns + 1;count();  # Track dependency
            }
        );

        runsAfterCreate = effectRuns;

        setCount(5);  # Same value - should not trigger
        runsAfterSameSet = effectRuns;

        setCount(10);  # Different value - should trigger
        runsAfterDifferentSet = effectRuns;

        return {
            "runsAfterCreate": runsAfterCreate,
            "runsAfterSameSet": runsAfterSameSet,
            "runsAfterDifferentSet": runsAfterDifferentSet
        };
    }

    # Test entry point
    def test_all_reactive_signals()  -> dict {
        return {
            "basic": test_signal_basic(),
            "withEffect": test_signal_with_effect(),
            "stateObject": test_state_object(),
            "multipleSignals": test_multiple_signals(),
            "equality": test_signal_equality()
        };
    }
}
