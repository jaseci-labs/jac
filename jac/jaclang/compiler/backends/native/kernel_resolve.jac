import json;
import os;
import sys;

glob STAGE0_UNKNOWN_FORMAT: int = 3,
     LAYOUT_SIDECAR_SUFFIX: str = ".layout.json",
     KERNEL_MODULE_NAME: str = "jac_kernel",
     KERNEL_DIR_NAME: str = "_kernel",
     BUILTIN_KERNEL: str = "<built-in>",
     KERNEL_ROSTER_REL: str = "compiler/kernel_roster.json";

obj ResolvedKernel {
    has path: str,
        source: str,
        plan_digest: str = "";
}

class KernelLoadError(SystemExit) {
    static has stops_command: bool = True;
}

def kernel_lib_name -> str;

def kernel_dir -> str;

def source_tree_kernel_path -> str;

def kernel_path_for(spec: TargetSpec) -> str;

def _from_sealed_image -> (ResolvedKernel | None);

def _probe(lib_path: str, source: Source) -> Probe;

obj KernelArtifact(Artifact) {
    has name: str = "kernel",
        kind: ArtifactKind = ArtifactKind.CAPABILITY,
        release: ReleasePolicy = ReleasePolicy.REQUIRED,
        summary: str = "the compiler kernel",
        requires: list[str] = ["stage0", "llvm-shim", "stubcat"],
        consumes: list[str] = ["stubcat"];

    override def probe_sealed -> (Probe | None);
    override def probe_checkout -> Probe;
    override def probe_kit -> Probe;
    override def checkout_path -> str;
    def spec -> TargetSpec;
    def for_host -> bool;
    override def build(log: Callable[[str], None], force: bool, exact: bool);
}

obj Stage0Artifact(Artifact) {
    has name: str = "stage0",
        kind: ArtifactKind = ArtifactKind.CAPABILITY,
        release: ReleasePolicy = ReleasePolicy.ON_DEMAND,
        summary: str = "the previous jac release that builds the compiler kernel",
        provision: bool = True;

    def pin -> dict[str, str];
    override def probe_checkout -> Probe;
    override def checkout_path -> str;
    override def build(log: Callable[[str], None], force: bool, exact: bool);
}

def require_kernel -> ResolvedKernel;

def load_kernel -> any;

def check_kernel_roster(spec: KernelTarget);

def build_target_kernel(
    spec_path: str,
    output: str,
    triple: str = "",
    log: (Callable[[str], None] | None) = None
) -> int;
