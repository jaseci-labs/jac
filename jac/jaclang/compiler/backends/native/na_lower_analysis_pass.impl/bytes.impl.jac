impl NativeLowering._decode_literal(arg_node: (uni.UniNode | None)) -> (str | None) {
    if isinstance(arg_node, uni.MultiString) and len(arg_node.strings) == 1 {
        arg_node = arg_node.strings[0];
    }
    if not isinstance(arg_node, uni.String) {
        return None;
    }
    value: any = None;
    try {
        value = arg_node.lit_value;
    } except Exception {
        return None;
    }
    return value if isinstance(value, str) else None;
}
