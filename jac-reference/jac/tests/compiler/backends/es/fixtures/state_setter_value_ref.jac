"""Fixture: a client state setter used as a first-class value (#8224).

`has theme` inside a client function names two things: the value `theme` and
the setter `setTheme`. Known write sites (`theme = ...`) are rewritten by the
backend, but a setter used as a VALUE -- handed to an object constructor here,
which is the ordinary "return state plus its setter" hook shape -- reaches
codegen as an ordinary identifier. It has to resolve to a real binding in the
emitted module, or the page dies on load with a ReferenceError.
"""

obj:pub Box {
    has theme: str = "",
        setTheme: (Callable[[str], None] | None) = None;
}

def:pub useThing -> Box {
    has theme: str = "dark";
    return Box(theme=theme, setTheme=setTheme);
}

def:pub app -> JsxElement {
    return <div>{useThing().theme}</div>;
}
