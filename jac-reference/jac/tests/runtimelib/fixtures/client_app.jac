"""Sample Jac module containing client-side declarations."""

import from "@jac/runtime" { renderJsxTree, }

glob:pub API_LABEL: str = "Runtime Test";

obj:pub ButtonProps {
    has label: str = "Tap Me",
        color: str = "primary";
}

def:pub client_page -> JsxElement {
    props = ButtonProps(label="Tap Me", color="primary");
    <div class="app">
        <h1>{API_LABEL}</h1>
        <button class={props.color} data-id="button">{props.label}</button>
    </div>
}

# The simple (no pages/) entry template mounts a root component named `app`,
# so a bundleable module must export one -- same convention as `jac create`.
def:pub app -> JsxElement {
    <div class="root">{client_page()}</div>
}
