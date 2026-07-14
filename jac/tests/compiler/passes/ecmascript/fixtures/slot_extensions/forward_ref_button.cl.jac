"""#6520 — a client component becomes a ref target via a trailing `ref: Ref`.

The producer side of refs: a `def:pub` JSX component that declares a trailing
parameter typed `Ref` opts into React's `forwardRef((props, ref) => ...)` render
shape. It must lower to `const Button = forwardRef(function Button(props, ref)
{...})` so radix `asChild` compositions can use it as a positioning anchor. The
`ref` is the 2nd positional arg threaded in by React — never a destructured prop.
"""

def:pub Button(props: dict[str, any], ref: Ref[HTMLButtonElement]) -> JsxElement {
    return <button ref={ref}>{props["children"]}</button>;
}
