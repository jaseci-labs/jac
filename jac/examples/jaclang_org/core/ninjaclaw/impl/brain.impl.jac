impl respect_deadline(ctx: IterationContext) -> IterationAction {
    at = DEADLINE.get("at", 0.0);
    if at and at - time.monotonic() < 2 * CALL_MAX_S {
        return IterationAction.ABORT_WITH_SUMMARY;
    }
    return IterationAction.CONTINUE;
}
