import sys;
import from pathlib { Path }
import from importlib.abc { MetaPathFinder, Loader }
import from importlib.machinery { ModuleSpec }
import from jaclang.compiler.rust_bridge._blob { parse }
import from jaclang.compiler.rust_bridge._ctypes_codegen { build_module }
import from jaclang.compiler.rust_bridge._elf { read_jac_bridge_section }
import from jaclang.compiler.rust_bridge._finder { find_bridge_lib }

glob _RUST_PREFIX = "rust.";


class RustBridgeFinder(MetaPathFinder) {
    def init(self: RustBridgeFinder, extra_dirs: object = None) {
        self._extra = [Path(d) for d in (extra_dirs or [])];
    }

    def find_spec(
        self: RustBridgeFinder,
        fullname: str,
        path: object = None,
        target: object = None
    ) -> object {
        if fullname == "rust" {
            spec = ModuleSpec(fullname, loader=None, is_package=True);
            spec.submodule_search_locations = [];
            return spec;
        }
        if not fullname.startswith(_RUST_PREFIX) {
            return None;
        }
        crate = fullname[len(_RUST_PREFIX):];
        if "." in crate {
            return None;
        }
        lib = find_bridge_lib(crate, self._extra);
        if lib is None {
            return None;
        }
        return ModuleSpec(
            fullname, _RustBridgeLoader(str(lib.resolve()), crate), origin=str(lib)
        );
    }
}


class _RustBridgeLoader(Loader) {
    def init(self: _RustBridgeLoader, so_path: str, crate: str) {
        self._so = so_path;
        self._crate = crate;
    }

    def create_module(self: _RustBridgeLoader, spec: object) -> object {
        return None;
    }

    def exec_module(self: _RustBridgeLoader, module: object) {
        import from jaclang.compiler.rust_bridge { SUPPORTED_ABI }

        meta = parse(read_jac_bridge_section(self._so));
        if meta.abi_version != SUPPORTED_ABI {
            raise ImportError(
                f"rust.{self._crate}: bridge '{self._so}' declares ABI version " + f"{meta.abi_version}, but this jac supports v{SUPPORTED_ABI}. " + "Rebuild the bridge or upgrade jac."
            );
        }
        built = build_module(self._so, meta);
        for k in built.__dict__ {
            if not k.startswith("__") {
                module.__dict__[k] = built.__dict__[k];
            }
        }
        module.__file__ = self._so;
        module.__package__ = module.__name__;
    }
}


def install_rust_namespace(search_dirs: object = None) -> RustBridgeFinder {
    for f in sys.meta_path {
        if isinstance(f, RustBridgeFinder) {
            return f;
        }
    }
    finder = RustBridgeFinder(search_dirs);
    sys.meta_path.append(finder);
    return finder;
}


glob _JAC_BRIDGE_PREFIX = "jac_bridge_",
     _STEMS = ("lib{}.so", "lib{}.dylib", "{}.dll");


def _find_so(lib_name: str, dirs: list) -> object {
    stems = [s.format(lib_name) for s in _STEMS];
    for d in dirs {
        for stem in stems {
            p = d / stem;
            if p.exists() {
                return p;
            }
        }
    }
    return None;
}


class JacBridgeFinder(MetaPathFinder) {
    def init(self: JacBridgeFinder, extra_dirs: object = None) {
        cwd = Path.cwd();
        defaults = [
            cwd / "target" / "release",
            cwd / "target" / "debug",
            cwd.parent / "target" / "release",
            cwd.parent / "target" / "debug"
        ];
        self._dirs = [Path(d) for d in (extra_dirs or [])] + defaults;
    }

    def find_spec(
        self: JacBridgeFinder, fullname: str, path: object = None, target: object = None
    ) -> object {
        if not fullname.startswith(_JAC_BRIDGE_PREFIX) {
            return None;
        }
        so = _find_so(fullname, self._dirs);
        if so is None {
            return None;
        }
        return ModuleSpec(
            fullname, _RustBridgeLoader(str(so), fullname), origin=str(so)
        );
    }
}


def install_finder(search_dirs: object = None) -> JacBridgeFinder {
    for f in sys.meta_path {
        if isinstance(f, JacBridgeFinder) {
            return f;
        }
    }
    finder = JacBridgeFinder(search_dirs);
    sys.meta_path.append(finder);
    return finder;
}
