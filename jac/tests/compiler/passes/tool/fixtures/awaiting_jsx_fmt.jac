"""Awaiting-clause formatting inside a JSX slot."""
def:pub Panel -> JsxElement {
    return
        <div>
            {try {
                <p>ready</p>
            } awaiting {
                <p>loading</p>
            } except Exception {
                <p>failed</p>
            }}
        </div>;
}
