"""Sample Jac module with cl import from @jac/runtime."""

cl import from "@jac/runtime" { renderJsxTree, jacLogin, }

cl glob: pub APP_TITLE: str = "Import Test App";

cl def: pub test_page() {
    return <div class="container">
        <h1>
            {APP_TITLE}
        </h1>
        <p>
            This page uses imported functions from client_runtime
        </p>
    </div>;
}
