import hashlib;
import json;
import os;
import sys;

glob TOOLCHAIN_INPUTS: tuple[str, ...] = (
         "build.zig",
         "build.zig.zon",
         "bootstrap/pins.json"
     ),
     NATIVE_SOURCE_SUFFIXES: tuple[str, ...] = (".cpp", ".h", ".hpp"),
     RECORD_SUFFIX: str = ".artifact.json",
     LLVM_PINS: str = "bootstrap/pins.json",
     LLVM_CACHE_DIR: str = ".llvm-build";

def shim_name -> str;

def placed_shim_path -> str;

def llvm_host -> str;

def pinned_llvm_blocker(repo_root: str) -> str;

def _repo_root -> str;

def shim_inputs_digest(repo_root: str) -> str;

def write_shim_record(shim_path: str, repo_root: str);

def _recorded_inputs(shim_path: str) -> str;

def _probe(shim_path: str, source: Source) -> Probe;

obj ShimArtifact(Artifact) {
    has name: str = "llvm-shim",
        kind: ArtifactKind = ArtifactKind.ACCELERATOR,
        release: ReleasePolicy = ReleasePolicy.REQUIRED,
        summary: str = "the LLVM shim (native code generation)",
        floor: str = "Python placement for native-default code";

    override def probe_sealed -> (Probe | None);
    override def probe_checkout -> Probe;
    override def probe_kit -> Probe;
    override def checkout_path -> str;
    override def build_blocker -> str;
    override def build(log: Callable[[str], None], force: bool, exact: bool);
}

def shim_path -> str;
