import os;
import sys;

def _pkg_dir -> str;

def bundle_root(pkg_dir: str) -> str;

def _python_tag -> str;

def bundle_misses(pkg_dir: str) -> list[str];

obj PrecompiledArtifact(Artifact) {
    has name: str = "precompiled",
        kind: ArtifactKind = ArtifactKind.ACCELERATOR,
        release: ReleasePolicy = ReleasePolicy.REQUIRED,
        summary: str = "the precompiled compiler bundle (JIR)",
        floor: str = "compiling the compiler from source";

    override def probe_sealed -> (Probe | None);
    override def probe_checkout -> Probe;
    override def probe_kit -> Probe;
    override def checkout_path -> str;
    override def build(log: Callable[[str], None], force: bool, exact: bool);
}
