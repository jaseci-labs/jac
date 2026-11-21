"""A `while` loop in a slot, with a sibling after it."""

def:pub WhileSlot -> JsxElement {
    has n: int = 0;

    return
        <div>
            {while n < 3 {
                <li>tick</li>
            }<input id="footer"/>}
        </div>;
}
