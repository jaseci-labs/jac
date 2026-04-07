"""Input component for the Jac client application."""

def:pub Input(value: str = "", onChange: any = None, placeholder: str = "", label: str = "", type_: str = "text", disabled: bool = False) -> JsxElement {
    container_styles = {
        "display": "flex",
        "flexDirection": "column",
        "gap": "0.25rem"
    };

    label_styles = {
        "fontSize": "0.875rem",
        "fontWeight": "500",
        "color": "#374151"
    };

    input_styles = {
        "padding": "0.5rem 0.75rem",
        "fontSize": "1rem",
        "borderRadius": "0.375rem",
        "border": "1px solid #d1d5db",
        "outline": "none",
        "width": "100%",
        "boxSizing": "border-box",
        "backgroundColor": "#f9fafb" if disabled else "#ffffff",
        "color": "#111827",
        "cursor": "not-allowed" if disabled else "text"
    };

    return <div style={container_styles}>
        {label and <label style={label_styles}>{label}</label>}
        <input
            type={type_}
            value={value}
            onChange={onChange}
            placeholder={placeholder}
            disabled={disabled}
            style={input_styles}
        />
    </div>;
}
