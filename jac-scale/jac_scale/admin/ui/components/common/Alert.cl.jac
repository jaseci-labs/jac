"""Alert/toast notification component."""

cl {
    def:pub Alert(message: str, type: str = "success") -> JsxElement {
        if not message {
            return
                <></>;
        }

        typeClasses = {
            "success": "bg-emerald-500/20 text-emerald-400 border border-emerald-500/30",
            "error": "bg-red-500/20 text-red-400 border border-red-500/30",
            "warning": "bg-amber-500/20 text-amber-400 border border-amber-500/30",
            "info": "bg-blue-500/20 text-blue-400 border border-blue-500/30"
        };

        classes = "fixed top-4 right-4 z-50 px-4 py-2 rounded text-sm font-medium " + (
            typeClasses[type] or typeClasses["success"]
        );

        return
            <div className={classes}>
                {message}
            </div>;
    }

    def:pub InlineAlert(message: str, type: str = "error") -> JsxElement {
        if not message {
            return
                <></>;
        }

        typeClasses = {
            "success": "bg-emerald-500/10 border border-emerald-500/20 text-emerald-400",
            "error": "bg-red-500/10 border border-red-500/20 text-red-400",
            "warning": "bg-amber-500/10 border border-amber-500/20 text-amber-400"
        };

        classes = "px-3 py-2 rounded text-sm mb-4 " + (
            typeClasses[type] or typeClasses["error"]
        );

        return
            <div className={classes}>
                {message}
            </div>;
    }
}
