import gzip;
import http.client;
import os;
import sys;
import urllib.error;
import urllib.request;
import zlib;

def _open(url: str, headers: dict[str, str]) -> http.client.HTTPResponse;

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

def _gunzip(gz: bytes) -> bytes;

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
            } except Exception {}
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

impl parse_eocd(tail: bytes, who: str) -> tuple[int, int] {
    eocd = tail.rfind(ZIP_EOCD_SIG);
    if eocd < 0 {
        die(f"{who}: no zip EOCD found");
    }
    return (rd_u32(tail, eocd + 12), rd_u32(tail, eocd + 16));
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

    if _probe_bun(out_path, Source.CHECKOUT).found is not None {
        log(f"fetch-bun: bun {BUN_VERSION} already present at {out_path}");
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

    os.chmod(out_path, 0o755);
    write_bun_record(out_path);
    log(f"fetch-bun: ready at {out_path} ({len(bun_bytes) >> 20} MiB)");
}

impl _open(url: str, headers: dict[str, str]) -> http.client.HTTPResponse {
    hdrs = {"User-Agent": USER_AGENT};
    hdrs.update(headers);
    return urllib.request.urlopen(urllib.request.Request(url, headers=hdrs));
}

impl _gunzip(gz: bytes) -> bytes {
    try {
        return gzip.decompress(gz);
    } except (OSError, EOFError, zlib.error) as e {
        raise PayloadDie(f"gzip decompress failed: {type(e).__name__}: {e}");
    }
}
