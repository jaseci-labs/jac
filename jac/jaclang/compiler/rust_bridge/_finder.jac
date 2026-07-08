import os;
import platform;
import from pathlib { Path }

glob _STEMS = ("lib{}.so", "lib{}.dylib", "{}.dll"),
     _PREFIX = "rust.";

glob _EXTRA_DIRS = [];


def register_search_dir(path: object) {
    p = Path(path);
    if p not in _EXTRA_DIRS {
        _EXTRA_DIRS.append(p);
    }
}


def _ver_key(version: str) -> list {
    out = [];
    for part in version.split(".") {
        digits = "";
        for ch in part {
            if ch.isdigit() {
                digits = digits + ch;
            } else {
                break;
            }
        }
        out.append(int(digits) if digits else 0);
    }
    return out;
}


def _matches(version: str, constraint: object) -> bool {
    if constraint in (None, "", "*") {
        return True;
    }
    if version == constraint {
        return True;
    }
    return version.startswith(constraint + ".");
}


def is_bridge_module(module_name: str) -> bool {
    clean = module_name.lstrip(".");
    return clean.startswith(_PREFIX) and clean.count(".") == 1;
}


def _crate_of(module_name: str) -> object {
    if not is_bridge_module(module_name) {
        return None;
    }
    return module_name.lstrip(".")[len(_PREFIX):];
}


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


def _libc_soname -> str {
    sysname = platform.system();
    if sysname == "Darwin" {
        return "libSystem.B.dylib";
    }
    if sysname == "Windows" {
        return "msvcrt.dll";
    }
    return "libc.so.6";
}


def _cache_root -> Path {
    base = os.environ.get("XDG_CACHE_HOME") or str(Path.home() / ".cache");
    return Path(base) / "jac" / "rust-bridges";
}


def crate_lib_stem(crate: str) -> str {
    return crate.replace("-", "_");
}


def _lib_stems(crate: str) -> list {
    return [s.format(f"jac_bridge_{crate_lib_stem(crate)}") for s in _STEMS];
}


def built_lib_candidates(crate: str) -> list[str] {
    stem = crate_lib_stem(crate);
    names: list[str] = [];
    for base in (f"jac_bridge_{stem}", stem) {
        for s in _STEMS {
            names.append(s.format(base));
        }
    }
    return names;
}


def _search_dirs(crate: str, extra_dirs: object, constraint: object = None) -> list {
    dirs = [Path(d) for d in (extra_dirs or [])];
    dirs.extend(_EXTRA_DIRS);

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
                if d.is_dir() and _matches(d.name, constraint)
            ],
            key=lambda d : _ver_key(d.name),
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


def find_bridge_lib(
    crate: str, extra_dirs: object = None, constraint: object = None
) -> object {
    stems = _lib_stems(crate);
    for d in _search_dirs(crate, extra_dirs, constraint) {
        for stem in stems {
            p = d / stem;
            if p.is_file() {
                return p;
            }
        }
    }
    return None;
}
