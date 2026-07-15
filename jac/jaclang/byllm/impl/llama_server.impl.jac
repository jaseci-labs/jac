import os;
import platform;
import sys;

import from jaclang.cli.console { console }

"""Binary file name for llama-server on this platform."""
def _binary_name -> str {
    return "llama-server.exe" if platform.system() == "Windows" else "llama-server";
}

"""Absolute path to the bundled `byllm/_llama` directory, or None if absent."""
def _llama_root -> str | None {
    here = os.path.dirname(os.path.abspath(__file__));   # .../byllm/impl
    byllm_dir = os.path.dirname(here);                   # .../byllm
    cand = os.path.join(byllm_dir, "_llama");
    if os.path.isdir(cand) {
        return cand;
    }
    for p in sys.path {
        if not p {
            continue;
        }
        alt = os.path.join(p, "jaclang", "byllm", "_llama");
        if os.path.isdir(alt) {
            return alt;
        }
    }
    return None;
}

"""Resolve the llama-server binary for a named variant ('cpu' / 'vulkan')."""
def _variant_binary(variant: str) -> str | None {
    base = _llama_root();
    if base is None {
        return None;
    }
    cand = os.path.join(base, variant, _binary_name());
    return cand if os.path.isfile(cand) else None;
}

"""Set the executable bit (payload tars are materialized mode-agnostically)."""
def _ensure_executable(path: str) {
    if platform.system() == "Windows" {
        return;
    }
    try {
        os.chmod(path, 0o755);
    } except OSError as e {
        console.warning(
            f"Could not set the executable bit on llama-server at {path}: {e}",
            emoji=False
        );
    }
}

glob _GPU_CACHE: dict = {};

"""True if the bundled GPU runner can actually enumerate a device.

Authoritative and conservative: instead of trusting a proxy signal like
`nvidia-smi` (which reports a CUDA/NVML GPU even where Vulkan has no ICD -- e.g.
WSL2 with the NVIDIA CUDA driver but no Vulkan driver), it asks the *Vulkan
runner we would actually spawn* to list its devices. Any doubt -> False so the
daemon falls back to the always-works CPU runner. Cached (the probe spawns a
subprocess).
"""
impl has_gpu -> bool {
    if "v" in _GPU_CACHE {
        return _GPU_CACHE["v"];
    }
    result = _probe_gpu();
    _GPU_CACHE["v"] = result;
    return result;
}

def _probe_gpu -> bool {
    try {
        # Apple Silicon: the bundled runner has Metal compiled in.
        if platform.system() == "Darwin" and platform.machine() in ("arm64", "aarch64") {
            return True;
        }
        vk = _variant_binary("vulkan");
        if vk is None {
            return False;   # no Vulkan runner bundled for this platform
        }
        _ensure_executable(vk);
        import subprocess;
        import re;
        proc = subprocess.run(
            [vk, "--list-devices"], capture_output=True, text=True, timeout=30
        );
        blob = (proc.stdout or "") + (proc.stderr or "");
        # A usable device prints as "Vulkan0: <name> (...)"; an empty
        # "Available devices:" means the runner sees no GPU on this host.
        return re.search(r"(Vulkan|CUDA|ROCm|SYCL)\d", blob) is not None;
    } except Exception {
        return False;
    }
}

impl llama_server_unavailable_message -> str {
    return (
        "llama-server is not available in this jac runtime. Shipped Linux and "
        "macOS (Apple silicon) binaries bundle it -- a missing copy there "
        "indicates a broken build. Other platforms have no bundled runner yet: "
        "set JAC_LLAMA_SERVER to an absolute llama-server path (get one from "
        "llama.cpp releases). For an editable/source checkout, run "
        "`zig build fetch-llama`."
    );
}

glob _ACCEL_BASE: str = "https://github.com/ggml-org/llama.cpp/releases/download";

"""Parse llama_sums.lock -> (version, {asset: sha256})."""
def _read_sums_lock(lock_path: str) -> tuple[str, dict] {
    import from pathlib { Path }
    version = LLAMA_VERSION;
    sums: dict = {};
    for line in Path(lock_path).read_text().splitlines() {
        s = line.strip();
        if s.startswith("# version:") {
            version = s.split(":", 1)[1].strip() or version;
            continue;
        }
        if not s or s.startswith("#") {
            continue;
        }
        parts = s.split();
        if len(parts) >= 2 {
            sums[parts[1]] = parts[0];
        }
    }
    return (version, sums);
}

"""Extract a .tar.gz, stripping the single top-level directory, into dest_dir."""
def _extract_stripped(tar_path: str, dest_dir: str) -> None {
    import tarfile;
    import os;
    with tarfile.open(tar_path) as tf {
        for member in tf.getmembers() {
            parts = member.name.split("/");
            if len(parts) <= 1 or ".." in parts {
                continue;
            }
            member.name = "/".join(parts[1:]);
            tf.extract(member, dest_dir);
        }
    }
}

impl ensure_accel_runner(accel: str) -> str | None {
    import os;
    import hashlib;
    import from pathlib { Path }
    import from urllib.request { urlopen, Request }
    try {
        here = os.path.dirname(os.path.abspath(__file__));   # .../byllm/impl
        byllm_dir = os.path.dirname(here);
        lock_path = os.path.join(byllm_dir, "llama_sums.lock");
        if not os.path.isfile(lock_path) {
            return None;   # no trust anchor -> refuse to fetch
        }
        (version, sums) = _read_sums_lock(lock_path);
        # Pick the locked asset whose name contains the accel keyword.
        asset = None;
        expected = None;
        for (name, sha) in sums.items() {
            if accel in name {
                asset = name;
                expected = sha;
                break;
            }
        }
        if asset is None {
            return None;
        }
        cache = Path(os.path.expanduser("~")) / ".cache" / "jac" / "llama-accel" / version / accel;
        bin_path = cache / "llama-server";
        if bin_path.exists() {
            _ensure_executable(str(bin_path));
            return str(bin_path);
        }
        cache.mkdir(parents=True, exist_ok=True);
        tmp = cache / (asset + ".part");
        url = f"{_ACCEL_BASE}/{version}/{asset}";
        console.print(f"  Fetching accelerated runner '{accel}' (one-time)...", emoji=False);
        hasher = hashlib.sha256();
        req = Request(url, headers={"User-Agent": "jac-llama-accel"});
        with urlopen(req) as resp , open(tmp, "wb") as fh {
            while True {
                chunk = resp.read(1 << 20);
                if not chunk {
                    break;
                }
                fh.write(chunk);
                hasher.update(chunk);
            }
        }
        if hasher.hexdigest() != str(expected).lower() {
            tmp.unlink(missing_ok=True);
            console.error(
                f"accelerated runner '{accel}' sha256 mismatch; refusing to use it.",
                emoji=False
            );
            return None;
        }
        _extract_stripped(str(tmp), str(cache));
        tmp.unlink(missing_ok=True);
        if bin_path.exists() {
            _ensure_executable(str(bin_path));
            return str(bin_path);
        }
        return None;
    } except Exception as e {
        console.warning(f"could not fetch accelerated runner '{accel}': {e}", emoji=False);
        return None;
    }
}

"""Resolve the llama-server binary path (GPU variant when prefer_gpu + present).

Resolution order:
  1. $JAC_LLAMA_SERVER dev override (absolute binary path).
  2. bundled 'vulkan' variant, when prefer_gpu is set and it exists.
  3. bundled 'cpu' variant (always the fallback; Metal-enabled on macOS).
Returns None (after printing guidance) when nothing is found.
"""
impl get_llama_server(prefer_gpu: bool = False) -> str | None {
    override = os.environ.get("JAC_LLAMA_SERVER", None);
    if override {
        if os.path.isfile(override) {
            _ensure_executable(override);
            return override;
        }
        console.warning(
            f"JAC_LLAMA_SERVER is set to '{override}' but no file exists there; "
            "ignoring it and using the bundled runner.",
            emoji=False
        );
    }

    order = ["vulkan", "cpu"] if prefer_gpu else ["cpu"];
    for variant in order {
        cand = _variant_binary(variant);
        if cand is not None {
            _ensure_executable(cand);
            return cand;
        }
    }
    # Last resort: any variant present (e.g. only vulkan staged in a dev tree).
    for variant in ["cpu", "vulkan"] {
        cand = _variant_binary(variant);
        if cand is not None {
            _ensure_executable(cand);
            return cand;
        }
    }

    console.error(llama_server_unavailable_message(), emoji=False);
    return None;
}
