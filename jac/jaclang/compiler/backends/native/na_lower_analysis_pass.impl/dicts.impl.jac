impl NativeLowering._dict_val_type_args(nd: uni.DictVal) -> list[TypeBase] {
    return nd.type.private.type_args
        if (
            isinstance(nd, uni.Expr)
            and isinstance(nd.type, ClassType)
            and nd.type.private is not None
        )
        else [];
}

impl NativeLowering._dict_unpack_type_args(nd: uni.DictVal) -> list[TypeBase] {
    return nd.type.private.type_args
        if isinstance(nd.type, ClassType) and nd.type.private is not None
        else [];
}
