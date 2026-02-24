"""Badge component for roles and statuses."""

cl {
    def:pub Badge(text: str, variant: str = "default") -> JsxElement {
        variantClasses = {
            "admin": "bg-purple-500/20 text-purple-400",
            "user": "bg-slate-700 text-slate-400",
            "default": "bg-slate-700 text-slate-400",
            "success": "text-emerald-400",
            "warning": "text-amber-400",
            "error": "text-red-400"
        };

        classes = "px-2 py-0.5 text-xs font-medium rounded " + (
            variantClasses[variant] or variantClasses["default"]
        );

        return
            <span className={classes}>
                {text}
            </span>;
    }

    def:pub RoleBadge(role: str) -> JsxElement {
        return
            <Badge text={role or "user"} variant={role or "user"}/>;
    }

    def:pub StatusBadge(
        active: bool, activeText: str = "Active", inactiveText: str = "Inactive"
    ) -> JsxElement {
        if active {
            return
                <span className="text-xs text-emerald-400">
                    {activeText}
                </span>;
        }
        return
            <span className="text-xs text-amber-400">
                {inactiveText}
            </span>;
    }
}
