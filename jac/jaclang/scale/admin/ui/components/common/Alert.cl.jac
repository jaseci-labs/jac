"""Alert/toast notification component."""

def:pub Alert(message: str, type: str = "success") -> JsxElement {
    if not message {
        return <></>;
    }

    typeClasses = {
        "success": "bg-success-weak text-success border border-line",
        "error": "bg-danger-weak text-danger border border-line",
        "warning": "bg-warning-weak text-warning border border-line",
        "info": "bg-surface-2 text-fg border border-line"
    };

    classes = "fixed top-4 right-4 z-50 px-4 py-2 rounded-md text-sm font-medium shadow-md " + (
        typeClasses[type] or typeClasses["success"]
    );

    return <div className={classes}>{message}</div>;
}

def:pub InlineAlert(message: str, type: str = "error") -> JsxElement {
    if not message {
        return <></>;
    }

    typeClasses = {
        "success": "bg-success-weak border border-line text-success",
        "error": "bg-danger-weak border border-line text-danger",
        "warning": "bg-warning-weak border border-line text-warning"
    };

    classes = "px-3 py-2 rounded-md text-sm mb-4 " + (
        typeClasses[type] or typeClasses["error"]
    );

    return <div className={classes}>{message}</div>;
}
