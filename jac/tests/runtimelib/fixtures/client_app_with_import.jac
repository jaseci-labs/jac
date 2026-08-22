"""Sample Jac module with cl import from @jac/runtime."""

import from "@jac/runtime" { renderJsxTree, jacLogin, }

glob:pub APP_TITLE: str = "Import Test App";

def:pub test_page -> JsxElement {
    <div class="container">
        <h1>{APP_TITLE}</h1>
        <p>This page uses imported functions from client_runtime</p>
    </div>
}
