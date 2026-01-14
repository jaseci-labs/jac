cl import from ".components.GraphCanvas" { GraphCanvas }
cl import '.style.css';

cl {
    def:pub app() -> any {
        return <div style={{ "width": "100vw", "height": "100vh" }}>
            <GraphCanvas />
        </div>;
    }
}
