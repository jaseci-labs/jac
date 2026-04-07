"""Container component for the Jac client application."""

def:pub Container(children: any = None, maxWidth: str = "960px") -> JsxElement {
    container_styles = {
        "maxWidth": maxWidth,
        "marginLeft": "auto",
        "marginRight": "auto",
        "paddingLeft": "1rem",
        "paddingRight": "1rem",
        "width": "100%",
        "boxSizing": "border-box"
    };

    return <div style={container_styles}>
        {children}
    </div>;
}
