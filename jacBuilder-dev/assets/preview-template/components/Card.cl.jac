"""Card component for the Jac client application."""

def:pub Card(children: any = None, title: str = "", padding: str = "1.5rem") -> JsxElement {
    card_styles = {
        "backgroundColor": "#ffffff",
        "borderRadius": "0.75rem",
        "border": "1px solid #e5e7eb",
        "boxShadow": "0 1px 3px rgba(0,0,0,0.1)",
        "padding": padding,
        "width": "100%",
        "boxSizing": "border-box"
    };

    title_styles = {
        "fontSize": "1.25rem",
        "fontWeight": "600",
        "color": "#111827",
        "marginTop": "0",
        "marginBottom": "1rem"
    };

    return <div style={card_styles}>
        {title and <h3 style={title_styles}>{title}</h3>}
        {children}
    </div>;
}
