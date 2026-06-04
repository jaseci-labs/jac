"""Badge component for roles and statuses."""

cl {
    def:pub Badge(text: str, variant: str = "default") -> JsxElement {
        variantClasses = {
            "admin": "bg-indigo-500/15 text-indigo-300 border border-indigo-500/30",
            "user": "bg-slate-800 text-slate-300 border border-slate-700",
            "default": "bg-slate-800 text-slate-300 border border-slate-700",
            "success": "bg-emerald-500/15 text-emerald-300 border border-emerald-500/30",
            "warning": "bg-amber-500/15 text-amber-300 border border-amber-500/30",
            "error": "bg-red-500/15 text-red-300 border border-red-500/30"
        };

        classes = "inline-flex items-center px-2 py-0.5 text-xs font-medium rounded-md " + (
            variantClasses[variant] or variantClasses["default"]
        );

        return <span className={classes}>{text}</span>;
    }

    def:pub RoleBadge(role: str) -> JsxElement {
        return <Badge text={role or "user"} variant={role or "user"}/>;
    }

    def:pub StatusBadge(
        active: bool, activeText: str = "Active", inactiveText: str = "Inactive"
    ) -> JsxElement {
        if active {
            return <span className="text-xs text-emerald-400">{activeText}</span>;
        }
        return <span className="text-xs text-amber-400">{inactiveText}</span>;
    }
}
