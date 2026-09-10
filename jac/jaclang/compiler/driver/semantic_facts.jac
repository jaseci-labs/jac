import from jaclang.compiler.frontend.constant { CodeContext }

obj ImportEdge {
    has target: str,
        jac: bool,
        is_comptime: bool,
        context: CodeContext,
        top_level: bool,
        from_import: bool = False;
}

obj PlacementSpaces {
    has spaces: set[CodeContext] = set(),
        native_module: bool = False,
        has_native: bool = False;
}

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

obj NativeEligibility {
    has reason: str = '',
        dependencies: list[str] = [];
}
