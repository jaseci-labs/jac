"""Audit fixture for the dynamic-view seam (contract §4.2).

Exercises every dynamic JSX position that routes through `lower_view_expr`:
a dynamic expression child `{count}` and a dynamic attribute value `value={count}`.
Event handlers (`onClick={...}`) are NOT view positions — they must be emitted
as-is and never thunked. Static literals (`type="text"`) bypass the seam.

Under a thunking backend (view expr -> `__view(expr)`), the dynamic child and
the dynamic attribute MUST route through the seam, while the `onClick` handler
and the `type` literal MUST NOT. Under React/Preact the seam is a no-op, so this
is also a plain dynamic-JSX fixture.
"""

cl {
    def:pub view_app() -> JsxElement {
        has count: int = 0;

        # dynamic attribute value -> wraps; event handler -> never wraps;
        # static literal -> bypasses the seam; dynamic child -> wraps.
        return <input type="text" value={count} onClick={lambda { count; }}>{count}</input>;
    }
}
