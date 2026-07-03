"""Native variant of the platform header (inline styles only)."""

def:pub PlatformHeader(props: dict) -> JsxElement {
    return
        <div style={{"padding": 16, "backgroundColor": "#f3f4f6"}}>
            <h1 style={{"fontSize": 24, "fontWeight": "bold"}}>{props.title}</h1>
            <span style={{"fontSize": 12, "color": "#6b7280"}}>native</span>
        </div>;
}
