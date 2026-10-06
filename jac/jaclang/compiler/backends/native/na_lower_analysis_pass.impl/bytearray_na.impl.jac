impl NativeLowering._struct_pack_into_arity_error(
    params: Sequence[uni.Expr | uni.KWPair], fields: list[tuple[str, int, bool]]
) -> (str | None) {
    _expected = len(
        [
            f
            for f in fields
            if f[0] != "pad"
        ]
    );
    if len(params) - 3 != _expected {
        return f"expected {_expected}, got {len(params) - 3}";
    }
    return None;
}
