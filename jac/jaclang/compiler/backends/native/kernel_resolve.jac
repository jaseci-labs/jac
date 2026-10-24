import hashlib;
import json;
import os;
import sys;

glob NOT_BUILT: str = "not built",
     LAYOUT_SIDECAR_SUFFIX: str = ".layout.json",
     KERNEL_LINK_MODE: str = NATIVE_LINK_MODE_OBJECTS;

obj ResolvedKernel {
    has lib_path: str,
        layout: dict[str, any],
        source: str,
        plan_digest: str = "";
}

class KernelUnavailable(RuntimeError) {}

class KernelLoadError(SystemExit) {
    static has stops_command: bool = True;
}

def kernel_lib_name -> str;

def source_tree_kernel_path -> str;

def kernel_path_for(spec: TargetSpec) -> str;

def read_sidecar(lib_path: str) -> (dict[str, any] | None);

def sealed_link_refusal(record: dict[str, any], sidecar: dict[str, any]) -> str;

def _from_sealed_image -> (ResolvedKernel | None);

def kernel_options(spec: (TargetSpec | None) = None) -> CompileOptions;

def kernel_plan(
    prog: (JacProgram | None) = None,
    mode: str = "",
    target: (KernelTarget | None) = None,
    spec: (TargetSpec | None) = None
) -> LinkPlan;

def _sha256_file(path: str) -> str;

def _unit_label(path: str) -> str;

def unit_drift(
    sidecar: dict[str, any],
    recorded: dict[str, any],
    units: list[str],
    spec: (TargetSpec | None) = None
) -> list[str];

def _inspect(
    lib_path: str, expected_sha: str = "", spec: (TargetSpec | None) = None
) -> tuple[(dict[str, any] | None), list[str]];


def _bundled_kernel -> tuple[str, dict[str, any]] | None;

def _probe(
    lib_path: str,
    source: Source,
    expected_sha: str = "",
    spec: (TargetSpec | None) = None
) -> Probe;

obj KernelArtifact(Artifact) {
    has name: str = "kernel",
        kind: ArtifactKind = ArtifactKind.ACCELERATOR,
        release: ReleasePolicy = ReleasePolicy.REQUIRED,
        summary: str = "the native compiler kernel",
        floor: str = "the bytecode compiler",
        requires: list[str] = ["llvm-shim", "stubcat"],
        consumes: list[str] = ["stubcat"];

    override def unavailable_reason -> str;
    override def probe_sealed -> (Probe | None);
    override def probe_checkout -> Probe;
    override def probe_kit -> Probe;
    override def checkout_path -> str;
    def spec -> TargetSpec;
    def for_host -> bool;
    override def build(log: Callable[[str], None], force: bool, exact: bool);
}

def refuse_unloadable;

def resolve_kernel -> (ResolvedKernel | None);

def build_kernel(
    dst: str = "",
    log: (Callable[[str], None] | None) = None,
    link_mode: str = KERNEL_LINK_MODE,
    spec: (TargetSpec | None) = None
) -> LinkResult;
