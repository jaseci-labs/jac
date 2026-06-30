import io;
import platform;
import subprocess;
import tarfile;
import from pathlib { Path }
import from jaclang.scale.injector.bundle { is_excluded, TOOLCHAIN_SUBDIR }

glob _SHIP_PREFIX: str = ".ship-out",
     _PLUGIN_DIRS: list[str] = ["jac-scale", "jac-byllm"],
     BINARY_ARCNAME: str = "bin/jac";


def host_repo_root -> Path {
    # This file lives at <repo>/jac/jaclang/scale/injector/binary.jac, so the
    # repo root (which holds jac/, jac-scale/, jac-byllm/) is 5 parents up.
    return Path(str(__file__)).resolve().parent.parent.parent.parent.parent;
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


def _package_dir(plugin_dir: Path) -> (Path | None) {
    for child in sorted(plugin_dir.iterdir()) {
        if child.is_dir() and not is_excluded(child.relative_to(plugin_dir)) {
            if (child / "__init__.py").is_file()
            or (child / "__init__.jac").is_file() {
                return child;
            }
        }
    }
    return None;
}


def precompile_plugins(repo_root: Path) -> int {
    import marshal;
    import from jaclang.jac0core.compiler { patch_co_filenames_bytes }
    import from jaclang.jac0core.jir {
        write_precompiled_jir,
        FLAG_PRECOMPILED,
        compute_module_key,
        jir_matches_source,
        PRECOMPILE_SENTINEL
    }
    import from jaclang.jac0core.runtime { JacRuntime as Jac }
    import from jaclang.jac0core.program { JacProgram }

    import sys;
    pyver = f"cpython-{sys.version_info.major}{sys.version_info.minor}";
    compiler = Jac.get_compiler();
    written = 0;
    for name in _PLUGIN_DIRS {
        pkg = _package_dir(repo_root / name) if (repo_root / name).is_dir() else None;
        if pkg is None {
            continue;
        }
        out_dir = pkg / "_precompiled" / pyver;
        for jac_path in sorted(pkg.rglob("*.jac")) {
            rel = jac_path.relative_to(pkg);
            if is_excluded(rel) {
                continue;
            }
            dest = out_dir / rel.with_suffix(".jir");

            if dest.is_file()
            and jir_matches_source(dest.read_bytes(), str(jac_path)) {
                continue;
            }
            try {
                code = compiler.get_bytecode(
                    full_target=str(jac_path), target_program=JacProgram()
                );
                if code is None {
                    continue;
                }
                patched = patch_co_filenames_bytes(
                    marshal.dumps(code), str(pkg), PRECOMPILE_SENTINEL
                );
                jir = write_precompiled_jir(
                    patched, compute_module_key(str(jac_path)), FLAG_PRECOMPILED
                );
                dest.parent.mkdir(parents=True, exist_ok=True);
                dest.write_bytes(jir);
                written += 1;
            } except Exception {
                continue;
            }
        }
    }
    return written;
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
