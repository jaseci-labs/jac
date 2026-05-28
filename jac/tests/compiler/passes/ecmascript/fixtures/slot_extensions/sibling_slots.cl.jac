"""Two sibling statement slots in one element's children.

Each `{...}` slot lowers to its own accumulator IIFE. Both must declare
their accumulator with `let` -- if the second reuses the first's binding
name via a bare assignment, it references a name that was scoped to the
first (now-returned) IIFE and throws `ReferenceError: __jac_view_kids is
not defined` under ES-module strict mode.
"""

def:pub app() -> JsxElement {
    a = True;
    b = True;
    return <div>
        {if a { <span>A</span> }}
        {if b { <span>B</span> }}
    </div>;
}
