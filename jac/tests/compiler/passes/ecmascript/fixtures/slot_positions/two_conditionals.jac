"""Two conditionals sharing one slot: positions must not collapse."""

def:pub TwoConditionals -> JsxElement {
    has a: bool = True,
        b: bool = True;

    return
        <div>
            {if a {
                <p>A</p>
            }if b {
                <span>B</span>
            }}
        </div>;
}
