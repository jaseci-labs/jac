"""Little X - Entry point combining backend and frontend."""

import from .frontend { app as ClientApp }

def:pub app -> JsxElement {
    return <ClientApp/>;
}
