//! Shared target and optimization policy for distribution build artifacts.
const std = @import("std");

pub fn target(b: *std.Build) std.Build.ResolvedTarget {
    return if (b.user_input_options.contains("target"))
        b.standardTargetOptions(.{})
    else
        b.resolveTargetQuery(.{ .cpu_model = .baseline });
}

pub fn optimize(b: *std.Build) std.builtin.OptimizeMode {
    return b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSmall });
}
