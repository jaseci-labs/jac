# Issue #5885 gap 10: connect/disconnect operators with no right operand
# previously surfaced a misleading 'Unexpected token' / 'Missing ;' chain
# instead of telling the user the RHS is missing. Each line below should
# emit E0026 ("Connect/disconnect operator requires a right operand").

node N {
    has v: int = 0;
}

edge E {
    has weight: int = 0;
}

with entry {
    a = N();

    # Bare disconnect, missing RHS
    a del -->;

    # Typed-edge disconnect, missing RHS
    a del ->:E:->;

    # Bare connect, missing RHS
    a ++>;

    # Typed-edge connect, missing RHS
    a +>:E:+>;

    # Non-canonical disconnect form: 'del a-->;' — user wrote the leading
    # 'del' before the LHS and forgot the RHS. Surface the same E0026
    # diagnostic instead of the cascade of 'Missing ;' / 'Unexpected token'.
    del a-->;
}
