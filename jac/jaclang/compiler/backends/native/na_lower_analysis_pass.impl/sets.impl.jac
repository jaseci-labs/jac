impl NativeLowering._set_val_decl_args(nd: uni.SetVal) -> list[TypeBase] {
    return nd.type.private.type_args
        if (
            isinstance(nd, uni.Expr)
            and isinstance(nd.type, ClassType)
            and nd.type.private is not None
        )
        else [];
}
