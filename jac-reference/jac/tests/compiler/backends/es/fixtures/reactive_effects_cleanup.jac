"""Test fixture for reactive effects cleanup (can with exit in client context).

Note: useEffect import is auto-injected from @jac/runtime when `can with entry/exit` is used.
"""

def:pub timer_component -> JsxElement {
    has count: int = 0;

    intervalId = setInterval(lambda { count; }, 1000);

    # Cleanup effect - runs on component unmount
    can with exit {
        clearInterval(intervalId);
    }

    return <div>{count}</div>;
}
