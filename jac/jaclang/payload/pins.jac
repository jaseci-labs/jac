import os;

glob PINS_FILE: str = os.path.join(
         os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
         "bootstrap",
         "pins.json"
     );

obj PbsPins {
    has tag: str,
        python: str,
        flavor: str,
        base: str;
}

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
    has pbs: PbsPins,
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
