"""Host-side toolchain prep for binary-shipping deploys: build a self-contained
`jac` binary on the deploy host and pack it (with the plugin source the pod
installs against) for delivery into the cluster, instead of compiling jaclang
from source inside every pod.

Why: the experimental in-pod build compiles LLVM + CPython + the native shim in
each pod, on every restart - minutes and gigabytes that a small node cannot
sustain. When the host has already built jac, shipping the binary makes pod
startup seconds: the init container drops it on PATH and `jac install -e`s the
plugins (a pip step, no compile).

All helpers are build-time and free of cluster I/O (a local `zig build` is fine),
so they run during manifest generation like the rest of an injector's prepare():
  host_repo_root()        the jaseci checkout jac-scale runs from (jac/ + jac-scale/)
  build_release_binary()  a self-contained (non -Ddev) jac binary, built to a
                          dedicated prefix so it never clobbers the dev zig-out
  pack_toolchain()        tar the binary + plugin source into raw bytes

The released binary bundles its own CPython, so it runs on the bare python:3.x
base with no extra runtime libs - the same property Dockerfile.microservice.exp
relies on when it COPYs a host binary in. It is arch-specific: callers must guard
on host_arch() matching the target node before choosing to ship.
"""

import io;
import platform;
import subprocess;
import tarfile;
import from pathlib { Path }
import from jac_scale.injector.bundle { is_excluded, TOOLCHAIN_SUBDIR }

# Release binary build prefix, under jac/. Kept separate from the developer's
# `zig build -Ddev` output in jac/zig-out so shipping never disturbs the live
# edit loop. `zig build --prefix` installs the binary to <prefix>/bin/jac.
glob _SHIP_PREFIX: str = ".ship-out",
     # Plugin packages shipped beside the binary and installed editable in-pod.
     # jac-scale is required; byllm/mcp are optional (a core-only fork may omit them),
     # so pack_toolchain skips any that are absent.
     _PLUGIN_DIRS: list[str] = ["jac-scale", "jac-byllm", "jac-mcp"],
     # Arcname of the shipped binary within the toolchain tar (relative to the tar
     # root, which the init container untars under APP_MOUNT_PATH/TOOLCHAIN_SUBDIR).
     # The binary bootstrap copies it from there onto $HOME/.local/bin/jac.
     BINARY_ARCNAME: str = "bin/jac";


"""The jaseci checkout this jac-scale runs from - the dir holding jac/ and
jac-scale/. Derived from this module's path (jac-scale is installed editable from
<repo>/jac-scale), so it resolves to live source, not a site-packages copy."""
def host_repo_root -> Path {
    # <repo>/jac-scale/jac_scale/injector/binary.jac
    #   .parent(injector) .parent(jac_scale) .parent(jac-scale) .parent(<repo>)
    # str() coerces the str|None typeshed type of __file__ for Path() (it is
    # always a real path at runtime for a file-backed module).
    return Path(str(__file__)).resolve().parent.parent.parent.parent;
}


"""Normalized host CPU arch (x86_64 / aarch64), matching released-asset and zig
naming. Callers compare this against the target node's arch: a shipped binary
only runs on its own arch, so a mismatch must fall back to the in-pod build."""
def host_arch -> str {
    m = platform.machine();
    return "aarch64" if m in ("arm64", "aarch64") else m;
}


"""Build a self-contained release `jac` binary on the host and return its path.

Plain `zig build` (no -Ddev) produces the distributable binary: it bundles its
own CPython + jaclang and does NOT depend on the source tree, unlike the dev
binary. fetch-llvm is the one-time shim prerequisite (idempotent; reuses the
cached .llvm-build). Built to jac/.ship-out so the dev's jac/zig-out is untouched.
Raises (CalledProcessError / RuntimeError) if zig is missing or the build fails -
the caller treats that as "cannot ship, fall back to the in-pod build"."""
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


"""Tar+gzip the release binary (at BINARY_ARCNAME) plus the plugin source dirs
into raw bytes. Build artifacts and secrets are excluded via the shared
bundle.is_excluded rules; absent optional plugins are skipped. Deterministic for a
given tree so content_address() over the result is stable and the bundle caches."""
def pack_toolchain(repo_root: Path, binary: Path) -> bytes {
    buf = io.BytesIO();
    with tarfile.open(fileobj=buf, mode="w:gz") as tar {
        tar.add(str(binary), arcname=f"{TOOLCHAIN_SUBDIR}/{BINARY_ARCNAME}");
        for name in _PLUGIN_DIRS {
            pkg = repo_root / name;
            if not pkg.is_dir() {
                continue;
            }
            for path in sorted(pkg.rglob("*")) {
                if not path.is_file() {
                    continue;
                }
                rel = path.relative_to(repo_root);
                if is_excluded(rel) {
                    continue;
                }
                tar.add(str(path), arcname=f"{TOOLCHAIN_SUBDIR}/{rel}");
            }
            # is_excluded drops jac.toml (it can hold deploy creds in an APP
            # bundle), but a plugin's OWN jac.toml is package metadata that
            # `jac install -e` needs to resolve the package name + extras. Without
            # it the install walks up to /app/jac.toml and mis-installs the app
            # ("Unknown extras: all. Available: none"). Ship it explicitly - the
            # plugin's jac.toml is [project] + [optional-dependencies], not creds.
            plugin_toml = pkg / "jac.toml";
            if plugin_toml.is_file() {
                tar.add(
                    str(plugin_toml), arcname=f"{TOOLCHAIN_SUBDIR}/{name}/jac.toml"
                );
            }
        }
    }
    return buf.getvalue();
}


"""Object-store key for a toolchain bundle: namespaced by app, addressed by
digest, mirroring bundle_object_key so identical content reuses the same on-PVC
path and a changed toolchain gets a fresh one."""
def toolchain_object_key(app_name: str, digest: str) -> str {
    return f"toolchain/{app_name}/{digest}.tar.gz";
}
