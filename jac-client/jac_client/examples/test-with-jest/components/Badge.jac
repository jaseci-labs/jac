cl import from .logic { normalizeVariant }

cl {
    def:pub Badge(
        text: str,
        variant: str = "info"
    ) -> any {

        v = normalizeVariant(
            variant,
            ["info", "success", "warning"],
            "info"
        );

        colors = {
            "info": "#3b82f6",
            "success": "#22c55e",
            "warning": "#f59e0b"
        };

        return <span style={{
            "padding": "0.25rem 0.5rem",
            "borderRadius": "0.25rem",
            "color": "#ffffff",
            "backgroundColor": colors[v]
        }}>
            {text}
        </span>;
    }
}
