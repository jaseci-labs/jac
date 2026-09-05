"""Not a route: `JsxPage` on a method, which the scanner skips."""

obj Widget {
    def render -> JsxPage {
        return <div>widget</div>;
    }
}
