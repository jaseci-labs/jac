"""Main entry point for {{name}}."""

cl import from react { useEffect }
cl import ".global.css";

cl {
    """App shell -- wraps every page in the shadcn theme classes.

    The string below is managed by `jac shadcn init` / `jac shadcn upgrade`.
    Don't hand-edit it; use the CLI flags (--style / --base-color) instead.
    """
    def:pub app(children: Any = None) -> JsxElement {
        # JAC-SHADCN-THEME-CLASSES-BEGIN
        themeClasses = "style-nova base-color-neutral dark";
        # JAC-SHADCN-THEME-CLASSES-END
        useEffect(
            lambda -> Any {
                for cls in themeClasses.split(" ") {
                    document.body.classList.add(cls);
                }
                return lambda -> None { for cls in themeClasses.split(" ") {
                    document.body.classList.remove(cls);
                }};
            },
            []
        );

        return
            <div className="flex min-h-screen flex-col bg-background text-foreground">
                {children}
            </div>;
    }
}
