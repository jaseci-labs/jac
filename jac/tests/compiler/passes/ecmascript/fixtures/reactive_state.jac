"""Test fixture for reactive state (has variables in client context)."""

cl import from react { useState }

cl {
    def:pub counter_app() -> any {
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
