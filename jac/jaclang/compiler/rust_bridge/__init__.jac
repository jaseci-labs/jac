import os;
import shutil;
import from pathlib { Path }
import from jaclang.compiler.rust_bridge._blob { BridgeMeta, parse }
import from jaclang.compiler.rust_bridge._ctypes_codegen { build_module }
import from jaclang.compiler.rust_bridge._elf { read_jac_bridge_section }
import from jaclang.compiler.rust_bridge._finder {
    find_bridge_lib,
    is_bridge_module,
    _crate_of
}
import from jaclang.compiler.rust_bridge._synth { NaModule, Skip, render_na_source }

glob SUPPORTED_ABI = 1,
     __all__ = [
         "SUPPORTED_ABI",
         "BridgeSynth",
         "synthesize_bridge",
         "materialize_bridge",
         "install_bridge",
         "find_bridge_lib",
         "is_bridge_module",
         "RustBridgeFinder",
         "install_rust_namespace",
         "load_bridge",
         "install_finder",
         "JacBridgeFinder",
         "build_module"
     ];


def __getattr__(name: str) -> object {
    if name in (
        "RustBridgeFinder",
        "install_rust_namespace",
        "JacBridgeFinder",
        "install_finder"
    ) {
        import from jaclang.compiler.rust_bridge._importer {
            RustBridgeFinder,
            install_rust_namespace,
            JacBridgeFinder,
            install_finder
        }
        table = {
            "RustBridgeFinder": RustBridgeFinder,
            "install_rust_namespace": install_rust_namespace,
            "JacBridgeFinder": JacBridgeFinder,
            "install_finder": install_finder
        };
        return table[name];
    }
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}");
}


def load_bridge(so_path: object) -> object {
    so = str(so_path);
    meta = parse(read_jac_bridge_section(so));
    return build_module(so, meta);
}


def _gen_root -> Path {
    base = os.environ.get("XDG_CACHE_HOME") or str(Path.home() / ".cache");
    return Path(base) / "jac" / "rust-bridges-gen";
}


class BridgeSynth {
    def init(
        self: BridgeSynth,
        crate: str,
        so_path: str,
        so_basename: str,
        source: str,
        meta: object,
        skips: list = None
    ) {
        self.crate = crate;
        self.so_path = so_path;
        self.so_basename = so_basename;
        self.source = source;
        self.meta = meta;
        self.skips = skips if skips is not None else [];
    }
}


def synthesize_bridge(crate: str, extra_dirs: object = None) -> object {
    lib = find_bridge_lib(crate, extra_dirs);
    if lib is None {
        return None;
    }

    meta = parse(read_jac_bridge_section(str(lib)));
    if meta.abi_version != SUPPORTED_ABI {
        raise ImportError(
            f"rust.{crate}: bridge '{lib}' declares ABI version " + f"{meta.abi_version}, but this jac supports v{SUPPORTED_ABI}. " + "Rebuild the bridge or upgrade jac."
        );
    }

    na = render_na_source(meta, lib.name);
    return BridgeSynth(
        crate=crate,
        so_path=str(lib.resolve()),
        so_basename=lib.name,
        source=na.source,
        meta=meta,
        skips=na.skips
    );
}


def materialize_bridge(module_name: str, extra_dirs: object = None) -> object {
    crate = _crate_of(module_name);
    if crate is None {
        return None;
    }
    synth = synthesize_bridge(crate, extra_dirs);
    if synth is None {
        return None;
    }

    out_dir = _gen_root();
    out_dir.mkdir(parents=True, exist_ok=True);
    out = out_dir / f"{crate}.na.jac";
    if not out.is_file() or out.read_text(encoding="utf-8") != synth.source {
        tmp = out.with_name(f"{crate}.na.jac.{os.getpid()}.tmp");
        tmp.write_text(synth.source, encoding="utf-8");
        os.replace(tmp, out);
    }
    return str(out.resolve());
}


def install_bridge(so_path: object, version: str = "local") -> Path {
    import from jaclang.compiler.rust_bridge._finder { _cache_root, _target_triple }

    so_path = Path(so_path).resolve();
    meta = parse(read_jac_bridge_section(str(so_path)));
    crate = meta.module_name;

    dest_dir = _cache_root() / crate / version / _target_triple();
    dest_dir.mkdir(parents=True, exist_ok=True);
    dest = dest_dir / so_path.name;
    shutil.copy2(so_path, dest);
    return dest;
}
