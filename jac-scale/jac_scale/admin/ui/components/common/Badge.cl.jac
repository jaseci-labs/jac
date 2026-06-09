"""Badge component for roles and statuses."""

cl {
    def:pub Badge(text: str, variant: str = "default") -> JsxElement {
        variantClasses = {
            "admin": "bg-accent-weak text-accent border border-accent-line",
            "user": "bg-surface-2 text-muted border border-line",
            "default": "bg-surface-2 text-muted border border-line",
            "success": "bg-success-weak text-success border border-line",
            "warning": "bg-warning-weak text-warning border border-line",
            "error": "bg-danger-weak text-danger border border-line"
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
            return <span className="text-xs text-success">{activeText}</span>;
        }
        return <span className="text-xs text-faint">{inactiveText}</span>;
    }
}
