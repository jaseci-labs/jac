import io;
import json;
import hashlib;
import platform;
import subprocess;
import tarfile;
import from pathlib { Path }
import from urllib.request { urlopen }
import from jaclang.scale.injector.bundle { TOOLCHAIN_SUBDIR }

glob _SHIP_PREFIX: str = ".ship-out",
     BINARY_ARCNAME: str = "bin/jac",
     _HTTP_TIMEOUT: int = 60;


def host_repo_root -> Path {
    # The monorepo source root (the dir containing `jac/build.zig`) the LOCAL
    # channel host-builds from. Under the jac binary, __file__ lives in the
    # runtime cache rather than the checkout, so a fixed __file__-relative guess
    # mis-resolves; prefer an explicit JAC_REPO_ROOT override, then search upward
    # from cwd and __file__ for the build.zig marker.
    import os;
    override = os.environ.get("JAC_REPO_ROOT");
    if override {
        return Path(override).resolve();
    }
    seen: set = set();
    for start in [Path.cwd(), Path(str(__file__)).resolve()] {
        cur: Path = start;
        while True {
            if cur not in seen {
                seen.add(cur);
                if (cur / "jac" / "build.zig").is_file() {
                    return cur;
                }
            }
            if cur.parent == cur {
                break;
            }
            cur = cur.parent;
        }
    }
    # Last resort: <repo>/jac/jaclang/scale/injector/binary.jac -> the repo root
    # (which holds jac/, jac-scale/, jac-byllm/) is 5 parents up.
    return Path(str(__file__)).resolve().parent.parent.parent.parent.parent;
}


def host_arch -> str {
    m = platform.machine();
    return "aarch64" if m in ("arm64", "aarch64") else m;
}


def node_arch -> str {
    # The pods run linux; the asset arch must match the *node*, not necessarily
    # the deploy host. Default to the host arch (the common single-machine and
    # homogeneous-cluster case) and let JAC_NODE_ARCH override for cross-arch
    # deploys (e.g. an x86_64 laptop deploying to aarch64 nodes).
    import os;
    return os.environ.get("JAC_NODE_ARCH", "") or host_arch();
}


def _http_get_bytes(url: str) -> bytes {
    # timeout bounds inactivity (no bytes for _HTTP_TIMEOUT s), not total
    # download time, so a slow but progressing large-binary fetch is fine while a
    # stalled connection fails fast instead of hanging the deploy forever.
    resp = urlopen(url, timeout=_HTTP_TIMEOUT);
    try {
        return bytes(resp.read());
    } finally {
        resp.close();
    }
}


def download_release_binary(channel: str, arch: str) -> bytes {
    # Fetch a prebuilt, self-contained `jac` binary from jaseci-labs releases:
    #   stable -> the latest published release (jac-<ver>-linux-<arch>)
    #   dev    -> the rolling `dev` prerelease, force-moved to main HEAD on every
    #             push (jac-dev-linux-<arch>); see .github/workflows/release-dev.yml
    # scale ships inside this binary, so no plugin source or in-pod build is needed.
    repo = "jaseci-labs/jaseci";
    api = (
        f"https://api.github.com/repos/{repo}/releases/tags/dev"
            if channel == "dev"
            else f"https://api.github.com/repos/{repo}/releases/latest"
    );
    meta = json.loads(_http_get_bytes(api).decode("utf-8"));

    suffix = f"-linux-{arch}";
    binary_url = "";
    checksum_url = "";
    for asset in meta.get("assets", []) {
        name = str(asset.get("name", ""));
        url = str(asset.get("browser_download_url", ""));
        if not name.startswith("jac-") {
            continue;
        }
        if name.endswith(suffix + ".sha256") {
            checksum_url = url;
        } elif name.endswith(suffix) {
            binary_url = url;
        }
    }
    if not binary_url {
        tag = "dev" if channel == "dev" else meta.get("tag_name", "latest");
        raise RuntimeError(
            f"No `jac-*{suffix}` asset on the {channel} release ({tag}). The node "
            f"arch may be unpublished; set JAC_NODE_ARCH or check "
            f"https://github.com/{repo}/releases."
        );
    }

    payload = _http_get_bytes(binary_url);
    if checksum_url {
        want = _http_get_bytes(checksum_url).decode("utf-8").split()[0].strip().lower();
        got = hashlib.sha256(payload).hexdigest();
        if want and got != want {
            raise RuntimeError(
                f"Checksum mismatch for the downloaded jac binary "
                f"(expected {want}, got {got}); refusing to ship it."
            );
        }
    }
    return payload;
}


def pack_binary_bytes(binary_bytes: bytes) -> bytes {
    # Tar just the self-contained `jac` binary into the toolchain layout the
    # pod's unpack init container expects. No plugin source: scale is built in.
    buf = io.BytesIO();
    with tarfile.open(fileobj=buf, mode="w:gz") as tar {
        info = tarfile.TarInfo(name=f"{TOOLCHAIN_SUBDIR}/{BINARY_ARCNAME}");
        info.size = len(binary_bytes);
        info.mode = 0o755;
        tar.addfile(info, io.BytesIO(binary_bytes));
    }
    return buf.getvalue();
}


def build_release_binary(repo_root: Path) -> Path {
    jac_dir = repo_root / "jac";
    prefix = jac_dir / _SHIP_PREFIX;
    subprocess.run(["zig", "build", "fetch-llvm"], cwd=str(jac_dir), check=True);
    subprocess.run(
        ["zig", "build", "--prefix", str(prefix)], cwd=str(jac_dir), check=True
    );
    binary = prefix / "bin" / "jac";
    if not binary.is_file() {
        raise RuntimeError(f"zig build reported success but no binary at {binary}");
    }
    return binary;
}


def toolchain_object_key(app_name: str, digest: str) -> str {
    return f"toolchain/{app_name}/{digest}.tar.gz";
}
