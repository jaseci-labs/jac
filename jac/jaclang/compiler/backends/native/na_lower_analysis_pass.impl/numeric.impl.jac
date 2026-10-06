impl NativeLowering._complex_aug_token(aug_op: str) -> (str | None) {
    return {
        "+=": Tok.PLUS,
        "-=": Tok.MINUS,
        "*=": Tok.STAR_MUL,
        "/=": Tok.DIV,
        "**=": Tok.STAR_POW
    }.get(
        aug_op
    );
}
