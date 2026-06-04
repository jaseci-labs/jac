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
        baseClass = "inline-flex items-center justify-center gap-1.5 font-medium rounded-lg transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-orange-500/50 disabled:opacity-50 disabled:cursor-not-allowed";

        sizeClasses = {
            "sm": "px-2.5 py-1 text-xs",
            "md": "px-3 py-1.5 text-xs",
            "lg": "px-4 py-2 text-sm"
        };

        variantClasses = {
            "primary": "bg-orange-500 hover:bg-orange-400 text-white shadow-sm shadow-orange-500/20",
            "secondary": "bg-slate-800 hover:bg-slate-700 text-slate-100 border border-slate-700",
            "danger": "bg-red-500/15 hover:bg-red-500/25 text-red-300 border border-red-500/30",
            "ghost": "text-slate-400 hover:text-white hover:bg-white/5",
            "link": "text-orange-400 hover:text-orange-300"
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
