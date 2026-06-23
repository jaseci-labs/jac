//! Generate stub_index.json from a typeshed stubs/ directory.
//!
//! Maps each typeshed third-party stub (PyPI distribution name, PEP 503
//! normalized) to its PyPI stub package name (`types-*`), version constraint, an
//! obsolete flag (upstream now ships inline types), and the import names it
//! provides. The binary ships only typeshed *stdlib* stubs; this small index is
//! what lets `jac add` know a third-party `types-*` exists and what to install.
//!
//! Built at typeshed-fetch time (launcher/fetch-typeshed.sh runs it via
//! `zig run`) so it needs no Python -- the build already requires Zig.
//!
//!   zig run gen_stub_index.zig -- <typeshed-stubs-dir> <out-json>

const std = @import("std");
const Io = std.Io;
const Dir = std.Io.Dir;
const Allocator = std.mem.Allocator;

const Meta = struct {
    version: []const u8 = "",
    stub_distribution: []const u8 = "",
    obsolete: bool = false,
};

const Entry = struct {
    key: []const u8, // PEP 503 normalized distribution name
    stub_dist: []const u8,
    version: []const u8,
    obsolete: bool,
    imports: [][]const u8,
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const a = init.arena.allocator();

    var args_it = std.process.Args.Iterator.init(init.minimal.args);
    _ = args_it.skip(); // argv[0]
    const stubs_dir = args_it.next() orelse usage();
    const out_path = args_it.next() orelse usage();

    var stubs = Dir.cwd().openDir(io, stubs_dir, .{ .iterate = true }) catch {
        std.debug.print("gen_stub_index: stubs dir not found: {s}\n", .{stubs_dir});
        std.process.exit(1);
    };
    defer stubs.close(io);

    var entries: std.ArrayList(Entry) = .empty;

    var it = stubs.iterate();
    while (try it.next(io)) |dist| {
        if (dist.kind != .directory) continue;
        var pkg = stubs.openDir(io, dist.name, .{ .iterate = true }) catch continue;
        defer pkg.close(io);

        const meta_bytes = pkg.readFileAlloc(io, "METADATA.toml", a, .limited(1 << 20)) catch continue;
        const meta = parseMeta(a, meta_bytes);

        const stub_dist = if (meta.stub_distribution.len > 0)
            meta.stub_distribution
        else
            try std.fmt.allocPrint(a, "types-{s}", .{dist.name});

        // import names the stub provides: package dirs + top-level .pyi modules
        var imports: std.ArrayList([]const u8) = .empty;
        var pit = pkg.iterate();
        while (try pit.next(io)) |m| {
            if (std.mem.eql(u8, m.name, "METADATA.toml")) continue;
            if (std.mem.eql(u8, m.name, "@tests")) continue;
            if (m.name.len > 0 and m.name[0] == '.') continue;
            if (m.kind == .directory) {
                try imports.append(a, try a.dupe(u8, m.name));
            } else if (std.mem.endsWith(u8, m.name, ".pyi")) {
                try imports.append(a, try a.dupe(u8, m.name[0 .. m.name.len - 4]));
            }
        }
        std.mem.sort([]const u8, imports.items, {}, lessStr);

        try entries.append(a, .{
            .key = try normalize(a, dist.name),
            .stub_dist = stub_dist,
            .version = meta.version,
            .obsolete = meta.obsolete,
            .imports = imports.items,
        });
    }

    std.mem.sort(Entry, entries.items, {}, lessEntry);

    // emit JSON (valid; not byte-matched to python -- the index is parsed, not diffed)
    var buf: std.ArrayList(u8) = .empty;
    try buf.appendSlice(a, "{\n");
    for (entries.items, 0..) |e, i| {
        try buf.appendSlice(a, "  ");
        try appendJsonStr(a, &buf, e.key);
        try buf.appendSlice(a, ": {\n    \"imports\": [");
        for (e.imports, 0..) |imp, j| {
            if (j != 0) try buf.appendSlice(a, ", ");
            try appendJsonStr(a, &buf, imp);
        }
        try buf.appendSlice(a, "],\n    \"obsolete\": ");
        try buf.appendSlice(a, if (e.obsolete) "true" else "false");
        try buf.appendSlice(a, ",\n    \"stub_dist\": ");
        try appendJsonStr(a, &buf, e.stub_dist);
        try buf.appendSlice(a, ",\n    \"version\": ");
        try appendJsonStr(a, &buf, e.version);
        try buf.appendSlice(a, "\n  }");
        if (i + 1 != entries.items.len) try buf.appendSlice(a, ",");
        try buf.appendSlice(a, "\n");
    }
    try buf.appendSlice(a, "}\n");

    try Dir.cwd().writeFile(io, .{ .sub_path = out_path, .data = buf.items });
    std.debug.print("gen_stub_index: wrote {d} stub entries -> {s}\n", .{ entries.items.len, out_path });
}

fn usage() noreturn {
    std.debug.print("usage: gen_stub_index <typeshed-stubs-dir> <out-json>\n", .{});
    std.process.exit(2);
}

/// Read the flat top-level keys we need from a typeshed METADATA.toml, stopping
/// at the first `[table]`. Avoids a real TOML parser (the fields are flat).
fn parseMeta(a: Allocator, bytes: []const u8) Meta {
    var meta: Meta = .{};
    var lines = std.mem.splitScalar(u8, bytes, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        if (line.len == 0) continue;
        if (line[0] == '[') break; // entered a [tool.*] table
        const eq = std.mem.indexOfScalar(u8, line, '=') orelse continue;
        const key = std.mem.trim(u8, line[0..eq], " \t");
        const val = extractValue(a, std.mem.trim(u8, line[eq + 1 ..], " \t"));
        if (std.mem.eql(u8, key, "version")) {
            meta.version = val;
        } else if (std.mem.eql(u8, key, "stub_distribution")) {
            meta.stub_distribution = val;
        } else if (std.mem.eql(u8, key, "obsolete_since") or std.mem.eql(u8, key, "no_longer_updated")) {
            meta.obsolete = true;
        }
    }
    return meta;
}

fn extractValue(a: Allocator, raw: []const u8) []const u8 {
    if (raw.len == 0) return "";
    if (raw[0] == '"' or raw[0] == '\'') {
        const q = raw[0];
        if (std.mem.indexOfScalarPos(u8, raw, 1, q)) |end| {
            return a.dupe(u8, raw[1..end]) catch "";
        }
        return "";
    }
    // bare value: strip a trailing inline comment
    const end = std.mem.indexOfScalar(u8, raw, '#') orelse raw.len;
    return a.dupe(u8, std.mem.trim(u8, raw[0..end], " \t")) catch "";
}

/// PEP 503: lowercase, collapse runs of [-_.] to a single '-'.
fn normalize(a: Allocator, name: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    var prev_sep = false;
    for (name) |c| {
        if (c == '-' or c == '_' or c == '.') {
            if (!prev_sep) {
                try out.append(a, '-');
                prev_sep = true;
            }
        } else {
            try out.append(a, std.ascii.toLower(c));
            prev_sep = false;
        }
    }
    return out.items;
}

fn appendJsonStr(a: Allocator, buf: *std.ArrayList(u8), s: []const u8) !void {
    try buf.append(a, '"');
    for (s) |c| {
        switch (c) {
            '"' => try buf.appendSlice(a, "\\\""),
            '\\' => try buf.appendSlice(a, "\\\\"),
            '\n' => try buf.appendSlice(a, "\\n"),
            '\r' => try buf.appendSlice(a, "\\r"),
            '\t' => try buf.appendSlice(a, "\\t"),
            else => if (c >= 0x20) try buf.append(a, c),
        }
    }
    try buf.append(a, '"');
}

fn lessStr(_: void, x: []const u8, y: []const u8) bool {
    return std.mem.lessThan(u8, x, y);
}

fn lessEntry(_: void, x: Entry, y: Entry) bool {
    return std.mem.lessThan(u8, x.key, y.key);
}
