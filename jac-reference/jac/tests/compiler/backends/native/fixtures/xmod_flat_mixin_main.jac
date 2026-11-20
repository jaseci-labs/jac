import from xmod_flat_base { FlatSource }

"""Inherits the flat base's `spot` unchanged."""
obj Via(FlatSource) {
    def tag -> str {
        return "via";
    }
}

"""Unrelated to the flat base, with a `spot` of its own that `Both` does
not inherit: `Via`, and through it `FlatSource`, come first."""
obj Other {
    def spot(x: int) -> int {
        return 0;
    }
}

obj Both(Via, Other) {
    def trace(x: int) -> int {
        return x + 7;
    }
}

with entry {
    both = Both();
    print(f"spot={both.spot(1)}");
}
