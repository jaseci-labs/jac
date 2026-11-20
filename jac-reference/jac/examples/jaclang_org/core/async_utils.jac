async def:pub sleep(ms: int) {
    await new(
        Promise,  # jac:ignore[E1053]
        lambda (resolve: any, _reject: any) { _ = setTimeout(
            lambda { resolve.call(None, True); }, ms
        ); }
    );
}
