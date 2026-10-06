impl NativeLowering._spread_operand(nd: (uni.UniNode | None)) -> (uni.Expr | None) {
    if isinstance(nd, uni.UnaryExpr)
        and isinstance(nd.op, uni.Token)
        and nd.op.name == Tok.STAR_MUL {
        return nd.operand;
    }
    return None;
}
