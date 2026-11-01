//! pyconfig.h for the JacPython build, without autoconf. Every macro CPython's
//! configure writes there is either a build decision recorded in `probes` or
//! the result of a small program the pinned Zig compiles (and, where configure
//! links, links) for the release target, the same test configure runs. Probes
//! that read another probe's macro run after it, with every result so far in
//! their prelude, as configure's confdefs.h carries them.
const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

pub const Os = enum { linux, macos };
pub const Arch = enum { x86_64, aarch64 };

pub const Target = struct {
    os: Os,
    arch: Arch,
    /// The C compiler command: zig cc, -target and, on macOS, the SDK flags.
    cc: []const []const u8,
    /// The vendored libraries' headers and archives (ffi.h, zlib.h, ...).
    deps: []const u8,
    /// The compiler's environment (its cache directories, deployment target).
    environ: ?*const std.process.Environ.Map = null,
};

pub const Kind = enum {
    /// A build decision: `value` is the definition, "" leaves it undefined.
    value,
    /// `#include <text>` compiles after `includes` (default: AC_INCLUDES_DEFAULT).
    header,
    /// A call through a dummy prototype links (AC_CHECK_FUNCS).
    func,
    /// `includes` declare `text` well enough to take its address (PY_CHECK_FUNC).
    address,
    /// `text` is declared, as a function, variable or macro.
    decl,
    /// sizeof(text), and the alignment of text as AC_CHECK_ALIGNOF measures it.
    sizeof,
    alignof,
    /// "struct tag.member" or "type.member" names a member.
    member,
    /// `text` names a type.
    type,
    /// `symbol` links from the library `text` (-lname).
    lib,
    /// `includes` then a main whose body is `text` compiles; with `text` empty,
    /// `includes` is the whole translation unit.
    compile,
    /// The same, and it links.
    link,
};

pub const Probe = struct {
    name: []const u8,
    kind: Kind,
    text: []const u8 = "",
    includes: ?[]const u8 = null,
    symbol: []const u8 = "",
    /// Extra link arguments, space separated.
    libs: []const u8 = "",
    /// The definition when the probe passes ("" leaves the macro undefined).
    value: []const u8 = "1",
    /// The definition when it fails.
    otherwise: []const u8 = "",
    /// An entry restricted to one OS or architecture; the first entry for a
    /// name that matches the target decides it, and a name no entry matches is
    /// left undefined.
    os: ?Os = null,
    arch: ?Arch = null,
};

/// The definitions in effect for the build, by macro name.
pub const Results = struct {
    map: std.StringArrayHashMapUnmanaged([]const u8) = .empty,

    pub fn get(self: Results, name: []const u8) ?[]const u8 {
        const v = self.map.get(name) orelse return null;
        return if (v.len == 0) null else v;
    }

    pub fn defined(self: Results, name: []const u8) bool {
        return self.get(name) != null;
    }
};

const default_includes =
    \\#include <stddef.h>
    \\#include <stdio.h>
    \\#include <stdlib.h>
    \\#include <string.h>
    \\#include <inttypes.h>
    \\#include <stdint.h>
    \\#include <strings.h>
    \\#include <sys/types.h>
    \\#include <sys/stat.h>
    \\#include <unistd.h>
    \\
;

/// configure's CFLAGS for its tests: build.sh exports these before running it.
const probe_cflags = [_][]const u8{ "-O3", "-fPIC", "-fno-semantic-interposition", "-Wno-unused-command-line-argument" };

fn applies(p: Probe, t: Target) bool {
    if (p.os) |os| if (os != t.os) return false;
    if (p.arch) |arch| if (arch != t.arch) return false;
    return true;
}

fn isIdent(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_';
}

/// Whether `name` occurs as a whole identifier in `text`.
fn mentions(text: []const u8, name: []const u8) bool {
    var start: usize = 0;
    while (std.mem.indexOfPos(u8, text, start, name)) |at| {
        const end = at + name.len;
        if ((at == 0 or !isIdent(text[at - 1])) and (end == text.len or !isIdent(text[end]))) return true;
        start = at + 1;
    }
    return false;
}

const Job = struct {
    probe: Probe,
    round: usize = 0,
    passed: bool = false,
    number: ?u64 = null,
};

/// Run the probes for `target` in `dir` (created; probe sources, objects and
/// diagnostics stay there) and return the definitions.
pub fn run(io: Io, a: Allocator, target: Target, dir: []const u8, jobs: usize) !Results {
    try Io.Dir.cwd().createDirPath(io, dir);
    var results: Results = .{};
    var pending: std.ArrayList(Job) = .empty;
    var seen: std.StringHashMapUnmanaged(void) = .empty;
    var names: std.ArrayList([]const u8) = .empty;
    for (probes) |p| {
        if (!seen.contains(p.name)) {
            try seen.put(a, p.name, {});
            try names.append(a, p.name);
        }
    }
    var decided: std.StringHashMapUnmanaged(void) = .empty;
    for (probes) |p| {
        if (decided.contains(p.name) or !applies(p, target)) continue;
        try decided.put(a, p.name, {});
        if (p.kind == .value) {
            try results.map.put(a, p.name, p.value);
        } else {
            try pending.append(a, .{ .probe = p });
        }
    }
    for (names.items) |name| {
        if (!decided.contains(name)) try results.map.put(a, name, "");
    }
    // A probe reading another probe's macro runs in a later round.
    var changed = true;
    var guard: usize = 0;
    while (changed) : (guard += 1) {
        if (guard > pending.items.len + 1) return error.ProbeDependencyCycle;
        changed = false;
        for (pending.items) |*job| {
            const src = try std.mem.concat(a, u8, &.{ job.probe.includes orelse "", "\n", job.probe.text });
            for (pending.items) |other| {
                if (std.mem.eql(u8, other.probe.name, job.probe.name)) continue;
                if (mentions(src, other.probe.name) and job.round <= other.round) {
                    job.round = other.round + 1;
                    changed = true;
                }
            }
        }
    }
    var round: usize = 0;
    var remaining = pending.items.len;
    while (remaining > 0) : (round += 1) {
        var batch: std.ArrayList(*Job) = .empty;
        for (pending.items) |*job| if (job.round == round) try batch.append(a, job);
        try runRound(io, a, target, dir, &results, batch.items, jobs);
        for (batch.items) |job| {
            const value = if (job.number) |n|
                try std.fmt.allocPrint(a, "{d}", .{n})
            else if (job.passed) job.probe.value else job.probe.otherwise;
            try results.map.put(a, job.probe.name, value);
        }
        remaining -= batch.items.len;
    }
    return results;
}

/// confdefs.h: the system extensions configure enables first, then every
/// definition decided so far.
fn prelude(a: Allocator, results: *const Results) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    try out.appendSlice(a, system_extensions);
    var it = results.map.iterator();
    while (it.next()) |e| {
        if (e.value_ptr.len == 0 or !validMacroName(e.key_ptr.*)) continue;
        try out.print(a, "#define {s} {s}\n", .{ e.key_ptr.*, e.value_ptr.* });
    }
    return out.toOwnedSlice(a);
}

/// Lower-case names (`const`, `signed`, `mode_t`) are type and keyword
/// replacements; defining them in a prelude would rewrite the probe itself.
fn validMacroName(name: []const u8) bool {
    return std.ascii.isUpper(name[0]) or name[0] == '_';
}

const Step = enum { compile, link, assemble };

fn source(a: Allocator, p: Probe, pre: []const u8) !struct { text: []const u8, step: Step } {
    const inc = p.includes orelse default_includes;
    return switch (p.kind) {
        .value => unreachable,
        .header => .{ .step = .compile, .text = try std.fmt.allocPrint(a, "{s}{s}\n#include <{s}>\n", .{ pre, inc, p.text }) },
        .func, .lib => blk: {
            const sym = if (p.kind == .lib) p.symbol else p.text;
            break :blk .{ .step = .link, .text = try std.fmt.allocPrint(a,
                \\{s}
                \\#define {s} innocuous_{s}
                \\#include <limits.h>
                \\#undef {s}
                \\char {s}(void);
                \\#if defined __stub_{s} || defined __stub___{s}
                \\choke me
                \\#endif
                \\int main(void) {{ return {s}(); }}
                \\
            , .{ pre, sym, sym, sym, sym, sym, sym, sym }) };
        },
        .address => .{ .step = .compile, .text = try std.fmt.allocPrint(a, "{s}{s}\nint main(void) {{ void *x = (void *){s}; (void)x; return 0; }}\n", .{ pre, inc, p.text }) },
        .decl => .{ .step = .compile, .text = try std.fmt.allocPrint(a, "{s}{s}\nint main(void) {{\n#ifndef {s}\n  (void){s};\n#endif\n  return 0;\n}}\n", .{ pre, inc, p.text, p.text }) },
        .sizeof => .{ .step = .assemble, .text = try std.fmt.allocPrint(a, "{s}{s}\nconst unsigned long long jac_probe_value = (unsigned long long)sizeof({s}) + 0x10000;\n", .{ pre, inc, p.text }) },
        .alignof => .{ .step = .assemble, .text = try std.fmt.allocPrint(a, "{s}{s}\ntypedef struct {{ char c; {s} x; }} jac_probe_align;\nconst unsigned long long jac_probe_value = (unsigned long long)offsetof(jac_probe_align, x) + 0x10000;\n", .{ pre, inc, p.text }) },
        .member => blk: {
            const dot = std.mem.lastIndexOfScalar(u8, p.text, '.') orelse return error.BadMemberProbe;
            break :blk .{ .step = .compile, .text = try std.fmt.allocPrint(a, "{s}{s}\nint main(void) {{ static {s} jac_aggr; if (sizeof jac_aggr.{s}) return 0; return 0; }}\n", .{ pre, inc, p.text[0..dot], p.text[dot + 1 ..] }) };
        },
        .type => .{ .step = .compile, .text = try std.fmt.allocPrint(a, "{s}{s}\nint main(void) {{ if (sizeof ({s})) return 0; return 0; }}\n", .{ pre, inc, p.text }) },
        .compile, .link => .{
            .step = if (p.kind == .compile) .compile else .link,
            .text = if (p.text.len == 0)
                try std.fmt.allocPrint(a, "{s}{s}\n", .{ pre, inc })
            else
                try std.fmt.allocPrint(a, "{s}{s}\nint main(void) {{\n{s}\n;\n  return 0;\n}}\n", .{ pre, p.includes orelse "", p.text }),
        },
    };
}

fn runRound(io: Io, a: Allocator, target: Target, dir: []const u8, results: *const Results, batch: []*Job, jobs: usize) !void {
    const pre = try prelude(a, results);
    const include_flag = try std.fmt.allocPrint(a, "-I{s}/include", .{target.deps});
    const lib_flag = try std.fmt.allocPrint(a, "-L{s}/lib", .{target.deps});
    var start: usize = 0;
    while (start < batch.len) {
        const end = @min(batch.len, start + @max(jobs, 1));
        var children: std.ArrayList(std.process.Child) = .empty;
        var outputs: std.ArrayList([]const u8) = .empty;
        var logs: std.ArrayList(Io.File) = .empty;
        for (batch[start..end]) |job| {
            const p = job.probe;
            const src = try source(a, p, pre);
            const base = try std.fs.path.join(a, &.{ dir, p.name });
            const c_path = try std.fmt.allocPrint(a, "{s}.c", .{base});
            try Io.Dir.cwd().writeFile(io, .{ .sub_path = c_path, .data = src.text });
            const out_path = try std.fmt.allocPrint(a, "{s}.{s}", .{ base, switch (src.step) {
                .compile => "o",
                .link => "out",
                .assemble => "s",
            } });
            var argv: std.ArrayList([]const u8) = .empty;
            try argv.appendSlice(a, target.cc);
            try argv.appendSlice(a, &probe_cflags);
            try argv.append(a, include_flag);
            switch (src.step) {
                .compile => try argv.append(a, "-c"),
                .assemble => try argv.append(a, "-S"),
                .link => {},
            }
            try argv.appendSlice(a, &.{ c_path, "-o", out_path });
            if (src.step == .link) {
                try argv.append(a, lib_flag);
                if (p.kind == .lib) try argv.append(a, p.text);
                var libs = std.mem.tokenizeScalar(u8, p.libs, ' ');
                while (libs.next()) |l| try argv.append(a, l);
            }
            const log = try Io.Dir.cwd().createFile(io, try std.fmt.allocPrint(a, "{s}.log", .{base}), .{});
            try logs.append(a, log);
            try children.append(a, try std.process.spawn(io, .{ .argv = argv.items, .environ_map = target.environ, .stdin = .ignore, .stdout = .{ .file = log }, .stderr = .{ .file = log } }));
            try outputs.append(a, if (src.step == .assemble) out_path else "");
        }
        for (children.items, outputs.items, logs.items, batch[start..end]) |*child, out, log, job| {
            const term = try child.wait(io);
            log.close(io);
            job.passed = term == .exited and term.exited == 0;
            if (out.len > 0) {
                if (!job.passed) return error.NumericProbeFailed;
                job.number = try readNumber(io, a, out);
            }
        }
        start = end;
    }
}

/// The value the assemble-only probes store: the first data directive after
/// the `jac_probe_value` label, less the 0x10000 bias that keeps a zero from
/// being emitted as `.zero`.
fn readNumber(io: Io, a: Allocator, path: []const u8) !u64 {
    const text = try Io.Dir.cwd().readFileAlloc(io, path, a, .limited(1024 * 1024));
    return parseAsmValue(text) orelse error.ProbeValueMissing;
}

fn parseAsmValue(text: []const u8) ?u64 {
    var lines = std.mem.splitScalar(u8, text, '\n');
    var after_label = false;
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        if (!after_label) {
            if (std.mem.startsWith(u8, line, "jac_probe_value:") or std.mem.startsWith(u8, line, "_jac_probe_value:")) after_label = true;
            continue;
        }
        for ([_][]const u8{ ".quad", ".xword", ".8byte" }) |directive| {
            if (std.mem.startsWith(u8, line, directive)) {
                var parts = std.mem.tokenizeAny(u8, line[directive.len..], " \t");
                const number = parts.next() orelse return null;
                const value = std.fmt.parseInt(u64, number, 0) catch return null;
                return value - 0x10000;
            }
        }
    }
    return null;
}

/// pyconfig.h, in autoheader's layout: the definitions sorted by name, then
/// the system-extension and byte-order blocks configure's template ends with.
pub fn render(a: Allocator, results: Results, label: []const u8) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    try out.print(a,
        \\/* pyconfig.h for {s}, written by bootstrap/pyconfig.zig from compiler
        \\   probes in place of configure. */
        \\
        \\#ifndef Py_PYCONFIG_H
        \\#define Py_PYCONFIG_H
        \\
        \\
    , .{label});
    const keys = try a.dupe([]const u8, results.map.keys());
    std.mem.sort([]const u8, keys, {}, struct {
        fn less(_: void, l: []const u8, r: []const u8) bool {
            return std.mem.lessThan(u8, l, r);
        }
    }.less);
    for (keys) |name| {
        if (inBlock(name)) continue;
        const value = results.map.get(name).?;
        if (value.len == 0) {
            try out.print(a, "/* #undef {s} */\n\n", .{name});
        } else {
            try out.print(a, "#define {s} {s}\n\n", .{ name, value });
        }
    }
    const xopen = results.get("_XOPEN_SOURCE");
    try out.appendSlice(a, system_extensions);
    if (xopen) |v| try out.print(a, "#ifndef _XOPEN_SOURCE\n# define _XOPEN_SOURCE {s}\n#endif\n\n", .{v}) else try out.appendSlice(a, "#ifndef _XOPEN_SOURCE\n/* # undef _XOPEN_SOURCE */\n#endif\n\n");
    if (results.defined("WORDS_BIGENDIAN")) {
        try out.appendSlice(a, "#ifndef WORDS_BIGENDIAN\n# define WORDS_BIGENDIAN 1\n#endif\n\n");
    } else {
        try out.appendSlice(a, "#ifndef WORDS_BIGENDIAN\n/* #  undef WORDS_BIGENDIAN */\n#endif\n\n");
    }
    try out.appendSlice(a,
        \\/* Define the macros needed if on a UnixWare 7.x system. */
        \\#if defined(__USLC__) && defined(__SCO_VERSION__)
        \\#define STRICT_SYSV_CURSES /* Don't use ncurses extensions */
        \\#endif
        \\
        \\#endif /*Py_PYCONFIG_H*/
        \\
    );
    return out.toOwnedSlice(a);
}

/// Written in the fixed blocks rather than the sorted list.
fn inBlock(name: []const u8) bool {
    return std.mem.eql(u8, name, "WORDS_BIGENDIAN") or std.mem.eql(u8, name, "STRICT_SYSV_CURSES");
}

/// AC_USE_SYSTEM_EXTENSIONS, which configure applies on every platform.
const system_extensions =
    \\#ifndef _ALL_SOURCE
    \\# define _ALL_SOURCE 1
    \\#endif
    \\#ifndef _DARWIN_C_SOURCE
    \\# define _DARWIN_C_SOURCE 1
    \\#endif
    \\#ifndef __EXTENSIONS__
    \\# define __EXTENSIONS__ 1
    \\#endif
    \\#ifndef _GNU_SOURCE
    \\# define _GNU_SOURCE 1
    \\#endif
    \\#ifndef _HPUX_ALT_XOPEN_SOCKET_API
    \\# define _HPUX_ALT_XOPEN_SOCKET_API 1
    \\#endif
    \\#ifndef _MINIX
    \\/* # undef _MINIX */
    \\#endif
    \\#ifndef _NETBSD_SOURCE
    \\# define _NETBSD_SOURCE 1
    \\#endif
    \\#ifndef _OPENBSD_SOURCE
    \\# define _OPENBSD_SOURCE 1
    \\#endif
    \\#ifndef _POSIX_SOURCE
    \\/* # undef _POSIX_SOURCE */
    \\#endif
    \\#ifndef _POSIX_1_SOURCE
    \\/* # undef _POSIX_1_SOURCE */
    \\#endif
    \\#ifndef _POSIX_PTHREAD_SEMANTICS
    \\# define _POSIX_PTHREAD_SEMANTICS 1
    \\#endif
    \\#ifndef __STDC_WANT_IEC_60559_ATTRIBS_EXT__
    \\# define __STDC_WANT_IEC_60559_ATTRIBS_EXT__ 1
    \\#endif
    \\#ifndef __STDC_WANT_IEC_60559_BFP_EXT__
    \\# define __STDC_WANT_IEC_60559_BFP_EXT__ 1
    \\#endif
    \\#ifndef __STDC_WANT_IEC_60559_DFP_EXT__
    \\# define __STDC_WANT_IEC_60559_DFP_EXT__ 1
    \\#endif
    \\#ifndef __STDC_WANT_IEC_60559_EXT__
    \\# define __STDC_WANT_IEC_60559_EXT__ 1
    \\#endif
    \\#ifndef __STDC_WANT_IEC_60559_FUNCS_EXT__
    \\# define __STDC_WANT_IEC_60559_FUNCS_EXT__ 1
    \\#endif
    \\#ifndef __STDC_WANT_IEC_60559_TYPES_EXT__
    \\# define __STDC_WANT_IEC_60559_TYPES_EXT__ 1
    \\#endif
    \\#ifndef __STDC_WANT_LIB_EXT2__
    \\# define __STDC_WANT_LIB_EXT2__ 1
    \\#endif
    \\#ifndef __STDC_WANT_MATH_SPEC_FUNCS__
    \\# define __STDC_WANT_MATH_SPEC_FUNCS__ 1
    \\#endif
    \\#ifndef _TANDEM_SOURCE
    \\# define _TANDEM_SOURCE 1
    \\#endif
    \\
;

pub const probes = @import("pyconfig_probes.zig").probes;

test "assembly values parse on every release target's syntax" {
    try std.testing.expectEqual(@as(?u64, 8), parseAsmValue("jac_probe_value:\n\t.quad\t65544 # 0x10008\n"));
    try std.testing.expectEqual(@as(?u64, 0), parseAsmValue("_jac_probe_value:\n\t.quad\t65536 ; 0x10000\n"));
    try std.testing.expectEqual(@as(?u64, 4), parseAsmValue("jac_probe_value:\n\t.xword\t65540 // 0x10004\n"));
    try std.testing.expectEqual(@as(?u64, null), parseAsmValue("other:\n\t.quad\t1\n"));
}

test "identifiers are matched whole" {
    try std.testing.expect(mentions("#ifdef HAVE_SYS_SOCKET_H\n", "HAVE_SYS_SOCKET_H"));
    try std.testing.expect(!mentions("#ifdef HAVE_SYS_SOCKET_HX\n", "HAVE_SYS_SOCKET_H"));
    try std.testing.expect(!mentions("XHAVE_SYS_SOCKET_H", "HAVE_SYS_SOCKET_H"));
}

test "every probe name is unique per target and every decision is sane" {
    for (probes) |p| {
        if (p.kind == .value) continue;
        try std.testing.expect(p.name.len > 0);
        if (p.kind == .lib) try std.testing.expect(p.symbol.len > 0);
    }
}
