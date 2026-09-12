# Each compilation owns its options. Symbol scopes and generated units carry
# this value explicitly, so nested and concurrent compiles need no Python TLS.
obj compile_context {
    has optimize: int = 0,
        flags: int = 0;
}
