"""Test fixture for reactive state (has variables) in an inferred-client module.

This tests that has variables work correctly with inferred client placement,
without any wrapper or marker.
"""


def:pub counter_app() -> JsxElement {
    has count: int = 0;
    has name: str = "test";

    count = count + 1;
    count = 42;
    name = "hello";

    return <div>
        <p>Count: {count}</p>
        <p>Name: {name}</p>
    </div>;
}
