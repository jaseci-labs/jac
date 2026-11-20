"""A control-flow-free `elif` chain lifts to one nested conditional."""

def:pub ElifChainClean -> JsxElement {
    has n: int = 0;

    return
        <div>
            {if n == 0 {
                <p>zero</p>
            } elif n == 1 {
                <b>one</b>
            } else {
                <i>many</i>
            }  }
        </div>;
}
