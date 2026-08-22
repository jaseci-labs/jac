"""An `elif` chain whose `if` arm escapes must stay statements throughout."""

def:pub ElifChainBlocked -> JsxElement {
    has tags: list[str] = [];

    return
        <div>
            {for t in tags {
                if t == "x" {
                    skip;
                } elif t == "y" {
                    <b key={t}>{t}</b>
                } else {
                    <li key={t}>{t}</li>
                }
            }}
        </div>;
}
