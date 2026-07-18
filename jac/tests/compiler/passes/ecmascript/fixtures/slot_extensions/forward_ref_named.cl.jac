"""#6520 — named props alongside a trailing `ref: Ref`.

The named props (`title`, `body`) destructure from `props` as usual; the trailing
`ref` is excluded from that destructure and lands as the 2nd positional arg of
the `forwardRef` render fn.
"""

def:pub Card(title: str, body: str, ref: Ref[HTMLElement]) -> JsxElement {
    return <div ref={ref}><h1>{title}</h1><p>{body}</p></div>;
}
