import hashlib;
import os;
import sys;

glob WASM_FLOOR_MANIFEST: str = "SOURCES.sha256",
     PYTHON_VARIANTS: tuple[str, ...] = ("cpython", "jacpython");

def _repo_root -> str;

def _has_archives(path: str) -> bool;

def _zig_blocker -> str;

def _zig_build(step: str);

def _floor_tier(
    sealed: bool, rel: str, source: Source, check: Callable[[str], bool]
) -> Probe;

def _running_python_variant -> str;

obj CFloorArtifact(Artifact) {
    has name: str = "c-floor",
        kind: ArtifactKind = ArtifactKind.ACCELERATOR,
        release: ReleasePolicy = ReleasePolicy.REQUIRED,
        summary: str = "the C floor archives (static OpenSSL, SQLite, zlib, ...)",
        floor: str = "dynamic linking against the system libraries";

    def target -> str;
    override def probe_sealed -> (Probe | None);
    override def probe_checkout -> Probe;
    override def probe_kit -> Probe;
    override def checkout_path -> str;
    override def build_blocker -> str;
    override def build(log: Callable[[str], None], force: bool, exact: bool);
}

obj MuslArtifact(Artifact) {
    has name: str = "musl",
        kind: ArtifactKind = ArtifactKind.CAPABILITY,
        release: ReleasePolicy = ReleasePolicy.REQUIRED,
        summary: str = "the static musl runtime (statically linked native binaries)",
        hosts: list[str] = ["linux"];

    def target -> str;
    override def probe_sealed -> (Probe | None);
    override def probe_checkout -> Probe;
    override def probe_kit -> Probe;
    override def checkout_path -> str;
    override def build_blocker -> str;
    override def build(log: Callable[[str], None], force: bool, exact: bool);
}

def _has_libc(path: str) -> bool;

def wasm_rt_src_dir -> str;

def wasm_floor_drift(libc_dir: str) -> (list[str] | None);

def _has_bitcode(path: str) -> bool;

def _wasm_probe(path: str, source: Source) -> Probe;

obj WasmLibcArtifact(Artifact) {
    has name: str = "wasm-libc",
        kind: ArtifactKind = ArtifactKind.CAPABILITY,
        release: ReleasePolicy = ReleasePolicy.REQUIRED,
        summary: str = "the wasm32 libc bitcode (the wasm host-contract floor)";

    override def probe_sealed -> (Probe | None);
    override def probe_checkout -> Probe;
    override def probe_kit -> Probe;
    override def checkout_path -> str;
    override def build_blocker -> str;
    override def build(log: Callable[[str], None], force: bool, exact: bool);
}
