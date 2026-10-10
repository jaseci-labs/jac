"""Tar reader and npm-mode extractor for the package manager.

Understands ustar, POSIX pax (`x` extended headers: path / linkpath / size),
GNU long names (`L` / `K`) and base-256 sizes. Operates on an in-memory
archive (ptr, len) — the gunzipped registry tarball.

`tar_extract_npm` reproduces bun's `Archiver.extractToDir(.., .{ .npm = true,
.depth_to_skip = 1 })` (src/libarchive/libarchive.zig):
  - only regular files are materialised (directories, symlinks and hard links
    in the archive are ignored; parent directories appear implicitly);
  - the first path component (`package/`) is dropped, the rest normalised;
  - files are created with `perm | 0o666` (so the executable bits survive and
    the process umask decides the final mode), parents with 0o755.
"""

import from engine.src.runtime.mem { read_byte }
import from engine.src.pm.bytes { bytes_to_str, bytes_eq_str }
import from engine.src.pm.fsx {
    fsx_open_write,
    fsx_fd_write,
    fsx_close,
    fsx_mkdir_p,
    FSX_ENOENT,
    FSX_ENOTDIR
}
import from engine.src.builtins.path_utils { path_dirname }

glob:pub TAR_FILE: int = 1,
     TAR_DIR: int = 2,
     TAR_SYMLINK: int = 3,
     TAR_HARDLINK: int = 4,
     TAR_OTHER: int = 0;

obj:pub TarEntry {
    has path: str = "",
        kind: int = 0,
        mode: int = 0,
        size: int = 0,
        data_off: int = 0,
        linkname: str = "";  # as stored (prefix joined), not stripped
}

# permission bits (0..0o777)

# offset of the file data inside the archive
obj:pub TarResult {
    has ok: bool = False,
        error: str = "",
        files: int = 0,
        paths: list[str] = [];
}

# relative paths written, in archive order
"""Parse an octal numeric field (or base-256 when the high bit of the first
byte is set). Leading spaces/NULs are skipped; stops at space/NUL."""
def _num_field(ptr: int, off: int, width: int) -> int {
    first: int = read_byte(ptr, off);
    if (first & 128) != 0 {
        v: int = 0;
        i: int = 1;
        while i < width {
            v = (v << 8) | read_byte(ptr, off + i);
            i = i + 1;
        }
        return v;
    }
    v2: int = 0;
    i2: int = 0;
    seen: bool = False;
    while i2 < width {
        c: int = read_byte(ptr, off + i2);
        i2 = i2 + 1;
        if c == 32 or c == 0 {
            if seen {
                break;
            }
            continue;
        }
        if c < 48 or c > 55 {
            break;
        }
        seen = True;
        v2 = v2 * 8 + (c - 48);
    }
    return v2;
}

"""NUL-terminated (or field-width-limited) string."""
def _field_str(ptr: int, off: int, width: int) -> str {
    n: int = 0;
    while n < width and read_byte(ptr, off + n) != 0 {
        n = n + 1;
    }
    return bytes_to_str(ptr, off, n);
}

def _block_is_zero(ptr: int, off: int) -> bool {
    i: int = 0;
    while i < 512 {
        if read_byte(ptr, off + i) != 0 {
            return False;
        }
        i = i + 1;
    }
    return True;
}

"""pax extended header records: "<len> <key>=<value>\n"…  Returns the
(path, linkpath, size) overrides; size -1 when absent."""
def _parse_pax(ptr: int, off: int, n: int) -> tuple[str, str, int] {
    path: str = "";
    link: str = "";
    size: int = -1;
    pos: int = off;
    end: int = off + n;
    while pos < end {
        # record length (decimal) up to a space
        sp: int = pos;
        while sp < end and read_byte(ptr, sp) != 32 {
            sp = sp + 1;
        }
        if sp >= end {
            break;
        }
        len_s: str = bytes_to_str(ptr, pos, sp - pos);
        if not len_s.isdigit() {
            break;
        }
        rec_len: int = int(len_s);
        if rec_len <= 0 or pos + rec_len > end {
            break;
        }
        body: str = bytes_to_str(ptr, sp + 1, pos + rec_len - (sp + 1));
        if body.endswith("\n") {
            body = body[0:len(body) - 1];
        }
        eq: int = body.find("=");
        if eq > 0 {
            key: str = body[0:eq];
            val: str = body[eq + 1:];
            if key == "path" {
                path = val;
            } elif key == "linkpath" {
                link = val;
            } elif key == "size" and val.isdigit() {
                # 19+ digits would overflow an int: no archive is that big.
                if len(val) > 18 {
                    size = 9223372036854775807;
                } else {
                    size = int(val);
                }
            }
        }
        pos = pos + rec_len;
    }
    return (path, link, size);
}

"""Walk the archive, calling back for each real entry. Returns entries with
their resolved (pax / GNU long) names. `error` set on a malformed archive."""
def:pub tar_list(ptr: int, n: int) -> list[TarEntry] {
    out: list[TarEntry] = [];
    pos: int = 0;
    long_name: str = "";
    long_link: str = "";
    pax_path: str = "";
    pax_link: str = "";
    pax_size: int = -1;
    while pos + 512 <= n {
        if _block_is_zero(ptr, pos) {
            break;
        }
        name: str = _field_str(ptr, pos, 100);
        mode: int = _num_field(ptr, pos + 100, 8) & 511;
        size: int = _num_field(ptr, pos + 124, 12);
        typeflag: int = read_byte(ptr, pos + 156);
        linkname: str = _field_str(ptr, pos + 157, 100);
        is_ustar: bool = bytes_eq_str(ptr, pos + 257, n, "ustar")
            and read_byte(ptr, pos + 262) == 0;
        prefix: str = "";
        if is_ustar {
            prefix = _field_str(ptr, pos + 345, 155);
        }
        data_start: int = pos + 512;
        # Written so a huge or negative (base-256) size cannot overflow past
        # the check; data_start <= n by the loop condition.
        if size < 0 or size > n - data_start {
            break;
        }  # truncated archive
        padded: int = ((size + 511) // 512) * 512;
        if typeflag == 120 {  # 'x' pax extended header
            px: tuple[str, str, int] = _parse_pax(ptr, data_start, size);
            if px[0] != "" {
                pax_path = px[0];
            }
            if px[1] != "" {
                pax_link = px[1];
            }
            if px[2] >= 0 {
                pax_size = px[2];
            }
            pos = data_start + padded;
            continue;
        }
        if typeflag == 103 {  # 'g' pax global header
            pos = data_start + padded;
            continue;
        }
        if typeflag == 76 {  # 'L' GNU long name
            long_name = _field_str(ptr, data_start, size);
            pos = data_start + padded;
            continue;
        }
        if typeflag == 75 {  # 'K' GNU long link
            long_link = _field_str(ptr, data_start, size);
            pos = data_start + padded;
            continue;
        }
        full: str = name;
        if prefix != "" {
            full = prefix + "/" + name;
        }
        if long_name != "" {
            full = long_name;
        }
        if pax_path != "" {
            full = pax_path;
        }
        link: str = linkname;
        if long_link != "" {
            link = long_link;
        }
        if pax_link != "" {
            link = pax_link;
        }
        if pax_size >= 0 {
            # A pax size replaces the header's, so it needs the same bound:
            # entries hand data_off + size to raw-pointer file writes, and an
            # unchecked size copied process memory past the archive.
            if pax_size > n - data_start {
                break;
            }  # pax size runs past the archive
            size = pax_size;
            padded = ((size + 511) // 512) * 512;
        }
        long_name = "";
        long_link = "";
        pax_path = "";
        pax_link = "";
        pax_size = -1;
        kind: int = TAR_OTHER;
        if typeflag == 48 or typeflag == 0 or typeflag == 55 {
            kind = TAR_FILE;
        } elif typeflag == 53 {  # '0', NUL, '7'
            kind = TAR_DIR;
        } elif typeflag == 50 {  # '5'
            kind = TAR_SYMLINK;
        } elif typeflag == 49 {  # '2'
            kind = TAR_HARDLINK;
        }  # '1'
        if kind == TAR_FILE and full.endswith("/") {
            kind = TAR_DIR;
        }
        out.append(
            TarEntry(
                path=full,
                kind=kind,
                mode=mode,
                size=size,
                data_off=data_start,
                linkname=link
            )
        );
        pos = data_start + padded;
    }
    return out;
}

"""Drop the first `nskip` path components and normalise the rest ("." and ""
segments removed, ".." resolved). "" means: nothing left / escapes the root."""
def:pub tar_relative_path(path: str, nskip: int) -> str {
    segs: list[str] = [];
    raw: list[str] = path.split("/");
    skipped: int = 0;
    for seg in raw {
        if seg == "" {
            continue;
        }
        if skipped < nskip {
            skipped = skipped + 1;
            continue;
        }
        if seg == "." {
            continue;
        }
        if seg == ".." {
            if len(segs) == 0 {
                return "";
            }
            del segs[len(segs) - 1];
            continue;
        }
        segs.append(seg);
    }
    if skipped < nskip {
        return "";
    }
    return "/".join(segs);
}

"""Extract regular files of the archive into `dest` following npm/bun rules.
`dest` must exist."""
def:pub tar_extract_npm(ptr: int, n: int, dest: str, depth_to_skip: int) -> TarResult {
    res: TarResult = TarResult();
    entries: list[TarEntry] = tar_list(ptr, n);
    for e in entries {
        if e.kind != TAR_FILE {
            continue;
        }
        rel: str = tar_relative_path(e.path, depth_to_skip);
        if rel == "" {
            continue;
        }
        target: str = dest + "/" + rel;
        mode: int = e.mode | 438;  # perm | 0o666
        fd: int = fsx_open_write(target, mode);
        if fd == FSX_ENOENT or fd == FSX_ENOTDIR {
            fsx_mkdir_p(path_dirname(target), 493);  # 0o755
            fd = fsx_open_write(target, mode);
        }
        if fd < 0 {
            res.error = "failed to create " + target + " (errno " + str(-fd) + ")";
            return res;
        }
        if e.size > 0 {
            w: int = fsx_fd_write(fd, ptr + e.data_off, e.size);
            if w != e.size {
                fsx_close(fd);
                res.error = "short write to " + target;
                return res;
            }
        }
        fsx_close(fd);
        res.files = res.files + 1;
        res.paths.append(rel);
    }
    res.ok = True;
    return res;
}
