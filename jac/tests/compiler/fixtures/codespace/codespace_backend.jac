"""Server backend consumed across the boundary by infer_sv_client.jac."""

obj ItemView {
    has label: str,
        count: int = 0;
}

def:pub fetch_items(prefix: str) -> list[ItemView] {
    return [ItemView(label=prefix)];
}
