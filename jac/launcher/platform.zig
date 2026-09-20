//! Private operations needed before the bundled interpreter can be loaded.
//! Filesystem, hashing, and archive decoding use Zig's standard library. This
//! is not a Python module or an alternate implementation of Python's stdlib.
const std = @import("std");
const Io = std.Io;
const allocator = std.heap.c_allocator;

extern var __jac_argc: c_int;
extern var __jac_argv: [*][*:0]const u8;

// Jac's C string return convention copies borrowed strings into managed
// storage. This exposes an address returned by the embedding API without
// allocating an intermediate strdup buffer.
export fn jac_boot_string(address: usize) ?[*:0]const u8 {
    return if (address == 0) null else @ptrFromInt(address);
}

fn io() Io {
    return Io.Threaded.global_single_threaded.io();
}

export fn jac_boot_argc() i64 {
    return __jac_argc;
}

export fn jac_boot_arg(index: i64) ?[*:0]const u8 {
    if (index < 0 or index >= __jac_argc) return null;
    return __jac_argv[@intCast(index)];
}

fn stat(path: [*:0]const u8) ?Io.File.Stat {
    return Io.Dir.cwd().statFile(io(), std.mem.span(path), .{}) catch null;
}

export fn jac_boot_is_file(path: [*:0]const u8) bool {
    return if (stat(path)) |s| s.kind == .file else false;
}

export fn jac_boot_is_dir(path: [*:0]const u8) bool {
    return if (stat(path)) |s| s.kind == .directory else false;
}

export fn jac_boot_size(path: [*:0]const u8) i64 {
    return if (stat(path)) |s| std.math.cast(i64, s.size) orelse -1 else -1;
}

export fn jac_boot_mtime(path: [*:0]const u8) f64 {
    return if (stat(path)) |s| @as(f64, @floatFromInt(s.mtime.toMicroseconds())) / 1e6 else 0;
}

export fn jac_boot_clock(monotonic: bool) f64 {
    const stamp = (if (monotonic) Io.Clock.awake else Io.Clock.real).now(io());
    return @as(f64, @floatFromInt(stamp.toMicroseconds())) / 1e6;
}

export fn jac_boot_mkdirs(path: [*:0]const u8) bool {
    Io.Dir.cwd().createDirPath(io(), std.mem.span(path)) catch return false;
    return true;
}

export fn jac_boot_remove(path: [*:0]const u8) bool {
    Io.Dir.cwd().deleteFile(io(), std.mem.span(path)) catch return false;
    return true;
}

export fn jac_boot_rmtree(path: [*:0]const u8) bool {
    Io.Dir.cwd().deleteTree(io(), std.mem.span(path)) catch return false;
    return true;
}

export fn jac_boot_rename(source: [*:0]const u8, dest: [*:0]const u8) bool {
    Io.Dir.cwd().rename(std.mem.span(source), Io.Dir.cwd(), std.mem.span(dest), io()) catch return false;
    return true;
}

export fn jac_boot_sha256(data: [*]const u8, len: usize, out: *[64]u8) void {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(data[0..len], &digest, .{});
    out.* = std.fmt.bytesToHex(digest, .lower);
}

/// Returns a static error name, or null on success. The caller owns the staging
/// directory and publishes it only after this function succeeds.
export fn jac_boot_extract(data: [*]const u8, len: usize, path: [*:0]const u8) ?[*:0]const u8 {
    const dir = Io.Dir.cwd().openDir(io(), std.mem.span(path), .{}) catch |err| return @errorName(err);
    defer dir.close(io());
    extract(io(), allocator, data[0..len], dir) catch |err| return @errorName(err);
    return null;
}

/// The payload writer emits concatenated zstd frames containing complete PAX
/// tar layers. Zero tar padding separates layers; decode every layer and drain
/// the compressed input so a truncated final frame cannot be published.
/// The launcher verifies SHA256 over the compressed bytes before calling this.
pub fn extract(stream_io: Io, gpa: std.mem.Allocator, compressed: []const u8, dir: Io.Dir) !void {
    // Matches the payload packer's window_log=24; bound memory independently
    // of the uncompressed runtime size.
    const window_len = 1 << 24;
    const buffer = try gpa.alloc(u8, window_len + std.compress.zstd.block_size_max);
    defer gpa.free(buffer);
    var source = Io.Reader.fixed(compressed);
    var decoder: std.compress.zstd.Decompress = .init(&source, buffer, .{ .window_len = window_len });
    const reader = &decoder.reader;
    const copy_buffer = try gpa.alloc(u8, 64 * 1024);
    defer gpa.free(copy_buffer);
    var name: [Io.Dir.max_path_bytes]u8 = undefined;
    var link: [Io.Dir.max_path_bytes]u8 = undefined;
    var files: usize = 0;
    while (true) {
        const header = reader.peek(512) catch |err| switch (err) {
            error.EndOfStream => {
                if (reader.buffered().len != 0) return error.TruncatedTarHeader;
                break;
            },
            else => return decoder.err orelse err,
        };
        if (std.mem.allEqual(u8, header, 0)) {
            reader.toss(512);
            continue;
        }
        var entries: std.tar.Iterator = .init(reader, .{
            .file_name_buffer = &name,
            .link_name_buffer = &link,
        });
        while (try entries.next()) |entry| {
            if (!safeRelative(entry.name)) return error.UnsafeArchivePath;
            switch (entry.kind) {
                .directory => try dir.createDirPath(stream_io, entry.name),
                .file => {
                    if (std.fs.path.dirnamePosix(entry.name)) |parent| try dir.createDirPath(stream_io, parent);
                    const permissions: Io.File.Permissions = if (entry.mode & 0o111 != 0) .executable_file else .default_file;
                    const file = try dir.createFile(stream_io, entry.name, .{ .permissions = permissions });
                    defer file.close(stream_io);
                    var writer = file.writer(stream_io, copy_buffer);
                    try entries.streamRemaining(entry, &writer.interface);
                    try writer.interface.flush();
                    files += 1;
                },
                .sym_link => return error.UnsupportedArchiveLink,
            }
        }
    }
    if (files == 0) return error.EmptyRuntimePayload;
}

fn safeRelative(path: []const u8) bool {
    if (path.len == 0 or std.fs.path.isAbsolutePosix(path) or std.mem.indexOfScalar(u8, path, '\\') != null) return false;
    var parts = std.mem.splitScalar(u8, path, '/');
    while (parts.next()) |part| {
        if (std.mem.eql(u8, part, "..")) return false;
    }
    return true;
}

export fn jac_boot_read(path: [*:0]const u8, offset: u64, buffer: [*]u8, length: usize) i64 {
    const file = Io.Dir.cwd().openFile(io(), std.mem.span(path), .{}) catch return -1;
    defer file.close(io());
    return @intCast(file.readPositionalAll(io(), buffer[0..length], offset) catch return -1);
}

export fn jac_boot_write(path: [*:0]const u8, data: [*]const u8, length: usize) bool {
    Io.Dir.cwd().writeFile(io(), .{ .sub_path = std.mem.span(path), .data = data[0..length] }) catch return false;
    return true;
}

const Directory = struct {
    dir: Io.Dir,
    iterator: Io.Dir.Iterator,
    name: [Io.Dir.max_name_bytes:0]u8 = undefined,
};

export fn jac_boot_directory(path: [*:0]const u8) ?*Directory {
    const dir = Io.Dir.cwd().openDir(io(), std.mem.span(path), .{ .iterate = true }) catch return null;
    const cursor = allocator.create(Directory) catch {
        dir.close(io());
        return null;
    };
    cursor.* = .{ .dir = dir, .iterator = dir.iterate() };
    return cursor;
}

export fn jac_boot_directory_next(cursor: *Directory) ?[*:0]const u8 {
    const entry = (cursor.iterator.next(io()) catch return null) orelse return null;
    @memcpy(cursor.name[0..entry.name.len], entry.name);
    cursor.name[entry.name.len] = 0;
    return @ptrCast(&cursor.name);
}

export fn jac_boot_directory_close(cursor: *Directory) void {
    cursor.dir.close(io());
    allocator.destroy(cursor);
}

export fn jac_boot_executable(buffer: [*]u8, length: usize) i64 {
    return @intCast(std.process.executablePath(io(), buffer[0..length]) catch return -1);
}

export fn jac_boot_cache_suffix() [*:0]const u8 {
    return if (@import("builtin").os.tag == .macos) "/Library/Caches/jac" else "/.cache/jac";
}
