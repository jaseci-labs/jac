"""What JSX means on a JS host, as the language gives it, whatever UI
library a space uses: every program for a `browser`, `hermes` or `node` space
sees these names as it sees the builtins.

A JSX expression is a `JsxElement`. A page returns a `JsxPage`, and a layout a
`JsxLayout`, which are the same. A `Ref` holds a value across a component's
runs without being state: its binding's ref function makes it, and what it
holds is dynamic."""

obj JsxElement {}

type JsxPage = JsxElement;

type JsxLayout = JsxElement;

obj Ref[T] {
    has current: any = None;
}

"""JavaScript's `new C(...)`: a JS class, constructed."""
def new(cls: any, *args: any) -> any;
