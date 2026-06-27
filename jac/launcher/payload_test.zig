//! Test-aggregator root for payload.zig.
//!
//! payload.zig defines `pub fn main` (it is the build-time payload CLI), which
//! collides with the `zig build` `--listen=-` test runner when payload.zig is
//! used as the test root directly (the runner hangs). This sibling root -- no
//! `main` of its own -- pulls in payload.zig's inline `test` blocks via the
//! standard aggregator pattern, so they run cleanly under `zig build test`.

test {
    _ = @import("payload.zig");
}
