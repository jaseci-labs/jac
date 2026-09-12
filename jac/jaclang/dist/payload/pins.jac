import os;

glob _PKG_DIR: str = os.path.dirname(os.path.abspath(__file__));

glob _PKG_PINS: str = os.path.join(_PKG_DIR, "pins.json");

glob _REPO_PINS: str = os.path.join(
         os.path.dirname(os.path.dirname(os.path.dirname(_PKG_DIR))),
         "bootstrap",
         "pins.json"
     ),
     PINS_FILE: str = _PKG_PINS if os.path.exists(_PKG_PINS) else _REPO_PINS;

obj LlvmSlice {
    has dirname: str,
        triple: str,
        manifest_sha256: str,
        zip_size: int,
        upstream: bool;
}

obj LlvmPins {
    has version: str,
        slice_base: str,
        slices: dict[str, LlvmSlice];
}

obj Pins {
    has python: str,
        llvm: LlvmPins;
}

glob _pins_cache: dict[str, Pins] = {};

def load_pins(path: str | None = None) -> Pins;
def pins -> Pins;
def py_minor(python: str) -> str;
def py_ver -> str;
def host_py_minor -> str;
def llvm_release(osarch: str) -> LlvmSlice | None;
def is_libcxx(rel: LlvmSlice) -> bool;
