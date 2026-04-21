"""Intrinsic JSX tag names (div, h1, button, etc.) should NOT produce
W1051 'Expression type could not be resolved (Unknown)' warnings.
These are resolved via _JsxIntrinsicElements, not normal scope lookup."""

def:pub Counter -> JsxElement {
    has count: int = 0;

    def increment {
        count += 1;
    }

    return
        <div>
            <h1>Hello</h1>
            <button onClick={lambda -> None { increment();}}>Click ({count})</button>
        </div>;
}
