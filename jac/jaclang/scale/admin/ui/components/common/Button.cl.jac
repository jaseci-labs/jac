"""Reusable button component with variants."""

def:pub Button(
    children: any,
    onClick: any = None,
    variant: str = "primary",
    size: str = "md",
    type: str = "button",
    disabled: bool = False,
    className: str = ""
) -> JsxElement {
    baseClass = "inline-flex items-center justify-center gap-1.5 font-medium rounded-md transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-accent disabled:opacity-50 disabled:cursor-not-allowed";

    sizeClasses = {
        "sm": "px-2.5 py-1 text-xs",
        "md": "px-3 py-1.5 text-xs",
        "lg": "px-4 py-2 text-sm"
    };

    variantClasses = {
        "primary": "bg-accent hover:bg-accent-hover text-accent-fg",
        "secondary": "bg-surface-2 hover:bg-line text-fg border border-line",
        "danger": "bg-danger hover:opacity-90 text-white",
        "ghost": "text-muted hover:text-fg hover:bg-surface-2",
        "link": "text-accent hover:text-accent-hover"
    };

    classes = baseClass + " " + (sizeClasses[size] or sizeClasses["md"]) + " " + (
        variantClasses[variant] or variantClasses["primary"]
    ) + " " + className;

    return
        <button type={type} onClick={onClick} disabled={disabled} className={classes}>
            {children}
        </button>;
}
