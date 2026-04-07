"""Select dropdown component for the Jac client application."""

def:pub Select(value: str = "", onChange: any = None, options: list = [], label: str = "", placeholder: str = "Select...", disabled: bool = False) -> JsxElement {
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

    select_styles = {
        "padding": "0.5rem 0.75rem",
        "fontSize": "1rem",
        "borderRadius": "0.375rem",
        "border": "1px solid #d1d5db",
        "outline": "none",
        "width": "100%",
        "boxSizing": "border-box",
        "backgroundColor": "#f9fafb" if disabled else "#ffffff",
        "color": "#111827",
        "cursor": "not-allowed" if disabled else "pointer"
    };

    return <div style={container_styles}>
        {label and <label style={label_styles}>{label}</label>}
        <select
            value={value}
            onChange={onChange}
            disabled={disabled}
            style={select_styles}
        >
            <option value="" disabled>{placeholder}</option>
            {options.map(lambda opt: Any -> Any {
                return <option value={opt} key={opt}>{opt}</option>;
            })}
        </select>
    </div>;
}
