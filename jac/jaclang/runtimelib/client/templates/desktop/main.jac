"""Main entry point for {{name}} (Jac desktop app)."""

cl import from .components.Button { Button }

cl def:pub app -> JsxElement {
    has count: int = 0;

    return
        <div style={{"padding": "2rem", "fontFamily": "system-ui, sans-serif"}}>
            <h1>Hello from {{name}}!</h1>
            <p>This is a Jac desktop app running in an OS webview.</p>
            <p>Count:{count}</p>
            <div style={{"display": "flex", "gap": "1rem", "marginTop": "1rem"}}>
                <Button
                    label="Increment"
                    onClick={lambda { count = count + 1; }}
                    variant="primary"
                />
                <Button
                    label="Reset"
                    onClick={lambda { count = 0; }}
                    variant="secondary"
                />
            </div>
        </div>;
}
