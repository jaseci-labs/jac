"""Regression fixture: union return type JsxElement | None still triggers component ABI.

Production pattern from client_runtime (e.g. renderError): a helper may return
None or JSX. Direct call sites must still wrap positional args into a props
object when the annotated return type includes JsxElement.
"""

cl {
    def:pub ErrorBanner(error: any) -> JsxElement | None {
        if not error {
            return None;
        }
        return <p>{error["message"]}</p>;
    }

    def:pub direct_call -> any {
        return ErrorBanner({"message": "oops"});
    }
}
