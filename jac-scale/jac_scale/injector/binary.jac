import io;
import platform;
import subprocess;
import tarfile;
import from pathlib { Path }
import from jac_scale.injector.bundle { is_excluded, TOOLCHAIN_SUBDIR }

glob _SHIP_PREFIX: str = ".ship-out",
     _PLUGIN_DIRS: list[str] = ["jac-scale", "jac-byllm", "jac-mcp"],
     BINARY_ARCNAME: str = "bin/jac";


def host_repo_root -> Path {
    return Path(str(__file__)).resolve().parent.parent.parent.parent;
}


def host_arch -> str {
    m = platform.machine();
    return "aarch64" if m in ("arm64", "aarch64") else m;
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


def toolchain_object_key(app_name: str, digest: str) -> str {
    return f"toolchain/{app_name}/{digest}.tar.gz";
}
