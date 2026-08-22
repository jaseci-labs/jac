import gzip;
import http.client;
import json;
import os;
import sys;
import urllib.error;
import urllib.request;
import zlib;

import from jaclang.payload.fsutil {
    PayloadDie,
    copy_file,
    copy_tree,
    delete_tree,
    die,
    extract_tar,
    file_exists,
    find_sum_line,
    host_os_arch,
    log,
    make_dirs,
    rd_u16,
    rd_u32,
    read_trimmed,
    sha256_hex,
    skip_typeshed_tests,
    write_bytes,
    write_text
}
import from jaclang.payload.pins { llvm_release, pins }
import from compression.zstd { decompress as zstd_decompress }

impl HttpSource.get(url: str) -> bytes {
    return http_get(url);
}

impl HttpSource.get_range(url: str, start: int, end: int) -> bytes {
    return http_get_range(url, start, end);
}

def _open(url: str, headers: dict[str, str]) -> http.client.HTTPResponse {
    hdrs = {"User-Agent": USER_AGENT};
    hdrs.update(headers);
    return urllib.request.urlopen(urllib.request.Request(url, headers=hdrs));
}

impl http_get(url: str) -> bytes {
    status = 0;
    body = b"";
    try {
        with _open(url, {}) as resp {
            status = resp.status;
            body = resp.read();
        }
    } except urllib.error.HTTPError as e {
        die(f"http {e.code} for {url}");
    } except (OSError, ValueError) as e {
        die(f"http fetch failed for {url}: {type(e).__name__}: {e}");
    }
    if status != 200 {
        die(f"http {status} for {url}");
    }
    return body;
}

impl http_get_range(url: str, start: int, end: int) -> bytes {
    rng = f"bytes={start}-{end}";
    status = 0;
    body = b"";
    try {
        with _open(url, {"Range": rng}) as resp {
            status = resp.status;
            body = resp.read();
        }
    } except urllib.error.HTTPError as e {
        die(
            f"fetch-llvm: expected 206 for range {rng}, got {e.code} (server ignored Range)"
        );
    } except (OSError, ValueError) as e {
        die(f"fetch-llvm: range fetch failed for {url}: {type(e).__name__}: {e}");
    }
    if status != 206 {
        die(
            f"fetch-llvm: expected 206 for range {rng}, got {status} (server ignored Range)"
        );
    }
    return body;
}

impl pbs_platform(osarch: str) -> str | None {
    return {
        "macos-aarch64": "aarch64-apple-darwin",
        "macos-x86_64": "x86_64-apple-darwin",
        "linux-x86_64": "x86_64-unknown-linux-gnu",
        "linux-aarch64": "aarch64-unknown-linux-gnu"
    }.get(
        osarch
    );
}

impl bun_asset_name(osarch: str) -> str | None {
    return {
        "macos-aarch64": "bun-darwin-aarch64",
        "macos-x86_64": "bun-darwin-x64",
        "linux-x86_64": "bun-linux-x64",
        "linux-aarch64": "bun-linux-aarch64",
        "windows-x86_64": "bun-windows-x64"
    }.get(
        osarch
    );
}

impl fetch_pbs(osarch: str, dest: str) {
    marker = os.path.join(dest, "python", "PYTHON.json");
    if file_exists(marker) {
        log(f"fetch-pbs: already present at {dest}/python");
        return;
    }
    pbs = pins().pbs;
    plat = pbs_platform(osarch);
    if plat is None {
        die(f"fetch-pbs: unsupported platform '{osarch}'");
    }
    asset = f"cpython-{pbs.python}+{pbs.tag}-{plat}-{pbs.flavor}.tar.zst";
    url = f"{pbs.base}/{pbs.tag}/{asset}";

    log(f"fetch-pbs: downloading {asset}");
    tarzst = http_get(url);

    sums = http_get(f"{pbs.base}/{pbs.tag}/SHA256SUMS").decode(
        "utf-8", errors="replace"
    );
    expected = find_sum_line(sums, asset);
    if expected is None {
        die(f"fetch-pbs: no checksum for {asset} in SHA256SUMS");
    }
    actual = sha256_hex(tarzst);
    if actual != expected {
        die(
            f"fetch-pbs: checksum mismatch for {asset}\n  expected {expected}\n  actual   {actual}"
        );
    }

    make_dirs(dest);
    try {
        tar = zstd_decompress(tarzst);
        extract_tar(tar, dest, 0, True);
    } except (OSError, ValueError, Exception) as e {
        die(f"fetch-pbs: extract failed: {type(e).__name__}: {e}");
    }

    if not file_exists(marker) {
        die("fetch-pbs: extract produced no PYTHON.json");
    }
    log(f"fetch-pbs: ready at {dest}/python");
}

def _gunzip(gz: bytes) -> bytes {
    try {
        return gzip.decompress(gz);
    } except (OSError, EOFError, zlib.error) as e {
        raise PayloadDie(f"gzip decompress failed: {type(e).__name__}: {e}");
    }
}

impl fetch_typeshed(repo_root: str) {
    vendor = os.path.join(repo_root, TYPESHED_VENDOR);
    commit = read_trimmed(os.path.join(vendor, "PIN"));
    if commit is None {
        raise PayloadDie(f"fetch-typeshed: no PIN at {vendor}/PIN");
    }
    expected_sha = read_trimmed(os.path.join(vendor, "TARBALL_SHA256"));
    if expected_sha is None {
        raise PayloadDie(
            f"fetch-typeshed: no TARBALL_SHA256 at {vendor}/TARBALL_SHA256"
        );
    }

    versions = os.path.join(vendor, "stdlib", "VERSIONS");
    stamp_path = os.path.join(vendor, "stdlib", ".typeshed-sha");
    if file_exists(versions) and read_trimmed(stamp_path) == commit {
        return;
    }

    log(f"fetch-typeshed: fetching typeshed @ {commit}");
    gz = http_get(f"{TYPESHED_TARBALL_BASE}/{commit}");
    tar = _gunzip(gz);
    actual = sha256_hex(tar);
    if actual != expected_sha {
        die(
            f"fetch-typeshed: tarball checksum mismatch @ {commit}\n  expected {expected_sha}\n  actual   {actual}"
        );
    }

    tmp = os.path.join(vendor, ".ts-extract");
    delete_tree(tmp);
    make_dirs(tmp);
    try {
        try {
            extract_tar(tar, tmp, 1, False);
        } except (OSError, ValueError, Exception) as e {
            die(f"fetch-typeshed: extract failed: {type(e).__name__}: {e}");
        }

        stdlib_dst = os.path.join(vendor, "stdlib");
        delete_tree(stdlib_dst);
        stdlib_src = os.path.join(tmp, "stdlib");
        if not os.path.isdir(stdlib_src) {
            die("fetch-typeshed: tarball has no stdlib/ (bad commit?)");
        }
        copy_tree(stdlib_src, stdlib_dst, skip_typeshed_tests);

        lic = os.path.join(tmp, "LICENSE");
        if file_exists(lic) {
            try {
                copy_file(lic, os.path.join(vendor, "LICENSE"));
            } except Exception { }
        }
    } finally {
        delete_tree(tmp);
    }

    write_text(stamp_path, commit);
    log(f"fetch-typeshed: ready ({commit})");
}

impl typeshed_sha(commit: str) {
    gz = http_get(f"{TYPESHED_TARBALL_BASE}/{commit}");
    tar = _gunzip(gz);
    sys.stdout.write(sha256_hex(tar) + "\n");
    sys.stdout.flush();
}

impl fetch_llvm(dest: str) {
    osarch = host_os_arch();
    macos = osarch.startswith("macos");
    rel = llvm_release(osarch);
    if rel is None {
        raise PayloadDie(
            f"fetch-llvm: no pinned LLVM release for this host ({osarch}); add a row to bootstrap/pins.json llvm.slices."
        );
    }
    marker_lib = "libLTO.dylib" if macos and rel.upstream else "libLLVMCore.a";
    marker = os.path.join(dest, rel.dirname, "lib", marker_lib);
    if file_exists(marker) {
        log(f"fetch-llvm: already present at {dest}/{rel.dirname}");
        return;
    }
    make_dirs(dest);

    fetch_llvm_slice(dest, rel, HttpSource(), macos);

    if not file_exists(marker) {
        die(f"fetch-llvm: fetch produced no {marker_lib}");
    }
    log(f"fetch-llvm: ready at {dest}/{rel.dirname}");
}

impl slice_wanted(name: str, macos: bool) -> bool {
    if name.startswith("lib/libLLVM") and name.endswith(".a") {
        return True;
    }
    if name.startswith("include/llvm/") or name.startswith("include/llvm-c/") {
        return True;
    }
    return macos and name == "lib/libLTO.dylib";
}

impl parse_eocd(tail: bytes, who: str) -> tuple[int, int] {
    eocd = tail.rfind(ZIP_EOCD_SIG);
    if eocd < 0 {
        die(f"{who}: no zip EOCD found");
    }
    return (rd_u32(tail, eocd + 12), rd_u32(tail, eocd + 16));
}

impl parse_central_directory(cd: bytes) -> list[ZipMember] {
    members: list[ZipMember] = [];
    p = 0;
    while p + 46 <= len(cd) and cd[p:p + 4] == ZIP_CDH_SIG {
        nlen = rd_u16(cd, p + 28);
        elen = rd_u16(cd, p + 30);
        clen = rd_u16(cd, p + 32);
        members.append(
            ZipMember(
                name=cd[p + 46:p + 46 + nlen].decode("utf-8", errors="replace"),
                method=rd_u16(cd, p + 10),
                csize=rd_u32(cd, p + 20),
                crc=rd_u32(cd, p + 16),
                lho=rd_u32(cd, p + 42)
            )
        );
        p += 46 + nlen + elen + clen;
    }
    return members;
}

impl inflate_member(method: int, data: bytes, who: str) -> bytes {
    if method == 0 {
        return bytes(data);
    }
    if method != 8 {
        die(f"{who}: unsupported zip compression method {method}");
    }
    try {
        d = zlib.decompressobj(-15);
        return d.decompress(data) + d.flush();
    } except zlib.error as e {
        raise PayloadDie(f"{who}: inflate failed: {e}");
    }
}

impl member_data(run: bytes, run_start: int, m: ZipMember) -> bytes {
    o = m.lho - run_start;
    if o < 0 or run[o:o + 4] != ZIP_LFH_SIG {
        die(f"fetch-llvm: bad local header for {m.name}");
    }
    data_off = o + 30 + rd_u16(run, o + 26) + rd_u16(run, o + 28);
    return run[data_off:data_off + m.csize];
}

def _manifest_sha_map(manifest: bytes, rel: LlvmSlice) -> dict[str, str] {
    ms = sha256_hex(manifest);
    if ms != rel.manifest_sha256 {
        die(
            f"fetch-llvm: manifest checksum mismatch\n  expected {rel.manifest_sha256}\n  actual   {ms}"
        );
    }
    try {
        parsed = json.loads(manifest);
    } except ValueError as e {
        die(f"fetch-llvm: manifest parse failed: {e}");
    }
    sha_map: dict[str, str] = {};
    libs = parsed.get("libs") if isinstance(parsed, dict) else None;
    if isinstance(libs, dict) {
        for o in libs.values() {
            if not isinstance(o, dict) {
                continue;
            }
            fv = o.get("file");
            sv = o.get("sha256");
            if isinstance(fv, str) and isinstance(sv, str) {
                sha_map[fv] = sv;
            }
        }
    }
    return sha_map;
}

def _run_end(members: list[ZipMember], i: int, cd_off: int) -> int {
    return members[i + 1].lho if i + 1 < len(members) else cd_off;
}

def _write_slice_member(slice_root: str, m: ZipMember, data: bytes) {
    rel_path = os.path.join(slice_root, m.name);
    if m.name.endswith("/") {
        make_dirs(rel_path);
        return;
    }
    make_dirs(os.path.dirname(rel_path));
    write_bytes(rel_path, data);
}

impl fetch_llvm_slice(dest: str, rel: LlvmSlice, src: HttpSource, macos: bool) {
    llvm = pins().llvm;
    slice_tag = "v" + llvm.version;
    zip_url = f"{llvm.slice_base}/{slice_tag}/llvm-{llvm.version}-{rel.triple}-dev.zip";
    man_url = f"{llvm.slice_base}/{slice_tag}/llvm-{llvm.version}-{rel.triple}-manifest.json";
    log(
        f"fetch-llvm: slice range-fetch (~84 MB) from llvm-slice {slice_tag} {rel.triple}"
    );

    sha_map = _manifest_sha_map(src.get(man_url), rel);

    tail_len = min(rel.zip_size, 65536);
    tail = src.get_range(zip_url, rel.zip_size - tail_len, rel.zip_size - 1);
    (cd_size, cd_off) = parse_eocd(tail, "fetch-llvm");

    cd = src.get_range(zip_url, cd_off, cd_off + cd_size - 1);
    members = parse_central_directory(cd);
    members.sort(key=lambda (m: ZipMember) { m.lho; });
    count = len(members);

    slice_root = os.path.join(dest, rel.dirname);
    written = 0;
    i = 0;
    while i < count {
        if not slice_wanted(members[i].name, macos) {
            i += 1;
            continue;
        }
        ra = i;
        rb = i;
        j = i + 1;
        while j < count {
            if slice_wanted(members[j].name, macos) {
                if members[j].lho - _run_end(members, rb, cd_off) >= SLICE_RUN_GAP {
                    break;
                }
                rb = j;
            }
            j += 1;
        }
        run_start = members[ra].lho;
        run_end = _run_end(members, rb, cd_off);
        run = src.get_range(zip_url, run_start, run_end - 1);
        k = ra;
        while k <= rb {
            m = members[k];
            k += 1;
            if not slice_wanted(m.name, macos) {
                continue;
            }
            data = inflate_member(
                m.method, member_data(run, run_start, m), "fetch-llvm"
            );
            if zlib.crc32(data) & 0xFFFFFFFF != m.crc {
                die(f"fetch-llvm: crc mismatch for {m.name}");
            }
            want_sha = sha_map.get(m.name);
            if want_sha is not None and sha256_hex(data) != want_sha {
                die(f"fetch-llvm: sha256 mismatch for {m.name}");
            }
            _write_slice_member(slice_root, m, data);
            written += 1;
        }
        i = rb + 1;
    }
    log(f"fetch-llvm: slice extracted {written} members");
}

impl unzip_member_by_suffix(zip_bytes: bytes, suffix: str) -> bytes {
    if len(zip_bytes) < 22 {
        die("fetch-bun: zip too small");
    }
    (cd_size, cd_off) = parse_eocd(zip_bytes, "fetch-bun");
    if cd_off + cd_size > len(zip_bytes) {
        die("fetch-bun: central directory out of range");
    }
    cd_end = cd_off + cd_size;
    p = cd_off;
    while p + 46 <= cd_end and zip_bytes[p:p + 4] == ZIP_CDH_SIG {
        method = rd_u16(zip_bytes, p + 10);
        csize = rd_u32(zip_bytes, p + 20);
        nlen = rd_u16(zip_bytes, p + 28);
        elen = rd_u16(zip_bytes, p + 30);
        clen = rd_u16(zip_bytes, p + 32);
        lho = rd_u32(zip_bytes, p + 42);
        name = zip_bytes[p + 46:p + 46 + nlen].decode("utf-8", errors="replace");
        if name.endswith(suffix) {
            if lho + 30 > len(zip_bytes) or zip_bytes[lho:lho + 4] != ZIP_LFH_SIG {
                die(f"fetch-bun: bad local header for {name}");
            }
            data_off = lho
                + 30
                + rd_u16(zip_bytes, lho + 26)
                + rd_u16(zip_bytes, lho + 28);
            if data_off + csize > len(zip_bytes) {
                die(f"fetch-bun: member data out of range for {name}");
            }
            return inflate_member(
                method, zip_bytes[data_off:data_off + csize], "fetch-bun"
            );
        }
        p += 46 + nlen + elen + clen;
    }
    raise PayloadDie(f"fetch-bun: no member ending in '{suffix}' found in zip");
}

impl fetch_bun(osarch: str, dest: str) {
    is_windows = osarch.startswith("windows");
    bun_name = "bun.exe" if is_windows else "bun";
    out_path = os.path.join(dest, bun_name);
    if file_exists(out_path) {
        log(f"fetch-bun: already present at {out_path}");
        return;
    }

    asset = bun_asset_name(osarch);
    if asset is None {
        die(f"fetch-bun: unsupported platform '{osarch}'");
    }
    zip_name = f"{asset}.zip";
    url = f"{BUN_BASE}/bun-v{BUN_VERSION}/{zip_name}";

    log(f"fetch-bun: downloading {zip_name}");
    zip_bytes = http_get(url);

    sums = http_get(f"{BUN_BASE}/bun-v{BUN_VERSION}/SHASUMS256.txt").decode(
        "utf-8", errors="replace"
    );
    expected = find_sum_line(sums, zip_name);
    if expected is None {
        die(f"fetch-bun: no checksum for {zip_name} in SHASUMS256.txt");
    }
    actual = sha256_hex(zip_bytes);
    if actual != expected {
        die(
            f"fetch-bun: checksum mismatch for {zip_name}\n  expected {expected}\n  actual   {actual}"
        );
    }

    bun_bytes = unzip_member_by_suffix(zip_bytes, "/" + bun_name);

    make_dirs(dest);
    write_bytes(out_path, bun_bytes);
    if not file_exists(out_path) {
        die(f"fetch-bun: extract produced no {bun_name}");
    }
    log(f"fetch-bun: ready at {out_path} ({len(bun_bytes) >> 20} MiB)");
}
