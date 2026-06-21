"""Fixture: augmented assignments on reactive state variables.

Exercises count += 5 and count -= 2 so the test can assert that the emitted
setter call is setCount(count + 5) / setCount(count - 2) rather than the
incorrect setCount(count + (count + 5)) that a double-application bug produces.
"""

def:pub aug_counter() -> JsxElement {
    has count: int = 0;

    count += 5;
    count -= 2;
    count *= 3;

    return <div>{count}</div>;
}
