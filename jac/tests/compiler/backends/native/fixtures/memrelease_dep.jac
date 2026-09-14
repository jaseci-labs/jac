"""Fixture dep: natively imported by memrelease_main; the link loop should
release this module's in-memory IR and compiled unit once its ir_cache and
ir_meta files land."""

def mr_scale(n: int) -> int {
    return n * 3;
}
