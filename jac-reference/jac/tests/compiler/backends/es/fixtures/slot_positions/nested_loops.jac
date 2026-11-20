"""A loop directly inside a loop, with a sibling after it."""

def:pub NestedLoops(rows: list[list[str]]) -> JsxElement {
    return
        <div>
            {for r in rows {
                for c in r {
                    <span key={c}>{c}</span>
                }
            }<input id="footer"/>}
        </div>;
}
