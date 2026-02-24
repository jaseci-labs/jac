"""Reusable button component with variants."""

cl {
    def:pub Button(
        children: any,
        onClick: any = None,
        variant: str = "primary",
        size: str = "md",
        type: str = "button",
        disabled: bool = False,
        className: str = ""
    ) -> JsxElement {
        baseClass = "font-medium rounded transition";

        sizeClasses = {
            "sm": "px-2 py-1 text-xs",
            "md": "px-3 py-1.5 text-xs",
            "lg": "px-4 py-2 text-sm"
        };

        variantClasses = {
            "primary": "bg-orange-500 hover:bg-orange-600 text-white",
            "secondary": "bg-slate-800 hover:bg-slate-700 text-white",
            "danger": "bg-red-500/20 hover:bg-red-500/30 text-red-400",
            "ghost": "text-slate-500 hover:text-white",
            "link": "text-slate-500 hover:text-white"
        };

        classes = baseClass + " " + (sizeClasses[size] or sizeClasses["md"]) + " " + (
            variantClasses[variant] or variantClasses["primary"]
        ) + " " + className;

        return
            <button
                type={type}
                onClick={onClick}
                disabled={disabled}
                className={classes}
            >
                {children}
            </button>;
    }
}
