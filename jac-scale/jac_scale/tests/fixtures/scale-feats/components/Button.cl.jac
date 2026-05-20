"""Button component for the Jac client application."""

def:pub Button(label: str, onClick: any, variant: str = "primary", disabled: bool = False) -> JsxElement {
    base_styles = {
        "padding": "0.75rem 1.5rem",
        "fontSize": "1rem",
        "fontWeight": "600",
        "borderRadius": "0.5rem",
        "border": "none",
        "cursor": "not-allowed" if disabled else "pointer",
        "transition": "all 0.2s ease"
    };

    variant_styles = {
        "primary": {
            "backgroundColor": "#9ca3af" if disabled else "#3b82f6",
            "color": "#ffffff"
        },
        "secondary": {
            "backgroundColor": "#e5e7eb" if disabled else "#6b7280",
            "color": "#ffffff"
        }
    };

    return <button
        style={{**base_styles, **variant_styles[variant]}}
        onClick={onClick}
        disabled={disabled}
    >
        {label}
    </button>;
}
