obj ServingBinding {
    has name: str,
        kind: str,
        source: str,
        auth: bool;
}

obj ServingFacts {
    has func_access: dict[str, bool] = {},
        walker_access: dict[str, bool] = {},
        effects: dict = {},
        cross_bindings: list[ServingBinding] = [];
}
