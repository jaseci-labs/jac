"""Loading spinner — a thin wrapper over @jac/mobui's ActivityIndicator so
buttons can swap their icon for a spinner while a walker call is in flight.
"""

cl {
    import from "@jac/mobui" { ActivityIndicator }

    def:pub Spinner(color: str) -> JsxElement {
        return <ActivityIndicator size="small" color={color}/>;
    }
}
