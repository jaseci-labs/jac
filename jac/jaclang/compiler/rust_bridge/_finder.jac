import os;
import platform;
import from pathlib { Path }

glob _STEMS = ("lib{}.so", "lib{}.dylib", "{}.dll");


def _target_triple -> str {
    machine = platform.machine().lower();
    arch_map = {
        "x86_64": "x86_64",
        "amd64": "x86_64",
        "arm64": "aarch64",
        "aarch64": "aarch64"
    };
    arch = arch_map.get(machine, machine);
    sysname = platform.system();
    if sysname == "Linux" {
        return f"{arch}-unknown-linux-gnu";
    }
    if sysname == "Darwin" {
        return f"{arch}-apple-darwin";
    }
    if sysname == "Windows" {
        return f"{arch}-pc-windows-msvc";
    }
    return f"{arch}-unknown-{sysname.lower()}";
}


def _cache_root -> Path {
    base = os.environ.get("XDG_CACHE_HOME") or str(Path.home() / ".cache");
    return Path(base) / "jac" / "rust-bridges";
}


def _lib_stems(crate: str) -> list {
    return [s.format(f"jac_bridge_{crate}") for s in _STEMS];
}


def _search_dirs(crate: str, extra_dirs: object) -> list {
    dirs = [Path(d) for d in (extra_dirs or [])];

    env = os.environ.get("JAC_RUST_BRIDGES_PATH");
    if env {
        dirs.extend(
            [
                Path(p)
                for p in env.split(os.pathsep)
                if p
            ]
        );
    }

    crate_root = _cache_root() / crate;
    if crate_root.is_dir() {
        versions = sorted(
            [
                d
                for d in crate_root.iterdir()
                if d.is_dir()
            ],
            key=lambda d : d.name,
            reverse=True
        );
        triple = _target_triple();
        for v in versions {
            dirs.append(v / triple);
            dirs.append(v);
        }
    }

    if os.environ.get("JAC_BRIDGE_DEV_FALLBACK") {
        cwd = Path.cwd();
        for base in (cwd, cwd.parent) {
            dirs.extend([base / "target" / "release", base / "target" / "debug"]);
        }
    }

    return dirs;
}


def find_bridge_lib(crate: str, extra_dirs: object = None) -> object {
    stems = _lib_stems(crate);
    for d in _search_dirs(crate, extra_dirs) {
        for stem in stems {
            p = d / stem;
            if p.is_file() {
                return p;
            }
        }
    }
    return None;
}
