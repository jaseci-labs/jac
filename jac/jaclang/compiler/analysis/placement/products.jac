import from jaclang.compiler.ir.enums { CodeContext }

obj PlacementSpaces {
    has spaces: set[CodeContext] = set(),
        native_module: bool = False,
        has_native: bool = False;
}

obj NativeEligibility {
    has reason: str = '',
        dependencies: list[str] = [];
}
