"""Text component for the Jac client application."""

def:pub Text(content: str = "", size: str = "1rem", weight: str = "400", color: str = "#374151") -> JsxElement {
    text_styles = {
        "fontSize": size,
        "fontWeight": weight,
        "color": color,
        "margin": "0",
        "lineHeight": "1.5"
    };

    return <p style={text_styles}>
        {content}
    </p>;
}
