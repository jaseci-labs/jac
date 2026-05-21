"""Main entry point for {{name}}."""

cl import from .components.Button { Button }

# Client-side component
to cl:

def:pub app -> JsxElement {
    has count: int = 0;

    return
        <div style={{"padding": "2rem", "fontFamily": "Arial, sans-serif"}}>
            <h1>Hello, World!</h1>
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
