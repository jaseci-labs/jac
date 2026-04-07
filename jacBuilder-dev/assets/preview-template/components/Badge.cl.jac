"""Badge component for the Jac client application."""

def:pub Badge(label: str = "", variant: str = "default") -> JsxElement {
    base_styles = {
        "display": "inline-block",
        "padding": "0.25rem 0.75rem",
        "fontSize": "0.75rem",
        "fontWeight": "600",
        "borderRadius": "9999px",
        "lineHeight": "1.5"
    };

    variant_styles = {
        "default": {
            "backgroundColor": "#f3f4f6",
            "color": "#374151"
        },
        "success": {
            "backgroundColor": "#d1fae5",
            "color": "#065f46"
        },
        "warning": {
            "backgroundColor": "#fef3c7",
            "color": "#92400e"
        },
        "error": {
            "backgroundColor": "#fee2e2",
            "color": "#991b1b"
        },
        "info": {
            "backgroundColor": "#dbeafe",
            "color": "#1e40af"
        }
    };

    return <span style={{**base_styles, **variant_styles[variant]}}>
        {label}
    </span>;
}
