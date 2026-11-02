"""The pass base a generic driver constructs through `type[W]`."""

obj Ctx {
    has name: str = "",
        time_taken: float = 0.0;
}

walker PassBase {
    has ctx: Ctx,
        label: str = "";
}

walker CountPass(PassBase) {
    has hits: int = 0;
}
