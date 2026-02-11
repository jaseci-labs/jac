"""Test fixture for reactive state (has variables in client context).

Note: useState import is auto-injected from @jac/runtime when `has` variables are used.
"""

cl {
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
}
