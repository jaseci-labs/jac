"""Arms of differing length share one reserved range."""

def:pub IfElseUneven -> JsxElement {
    has a: bool = True;

    return
        <div>
            {if a {
                <p>X</p>
                <p>Y</p>
            } else {
                <p>Z</p>
            } <hr/>}
        </div>;
}
