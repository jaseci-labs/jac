import os;
import shutil;
import subprocess;
import from pathlib { Path }

obj ToolArtifact(Artifact) {
    has kind: ArtifactKind = ArtifactKind.CAPABILITY,
        release: ReleasePolicy = ReleasePolicy.ON_DEMAND,
        provision: bool = True;

    def pinned -> (Download | None) abst;
    def marker(download: Download) -> str abst;
    def located(slot: Path, download: Download) -> Path;
    def on_system -> str;
    def works(path: Path) -> bool;
    override def probe_checkout -> Probe;
    override def checkout_path -> str;
    override def build(log: Callable[[str], None], force: bool, exact: bool);
}

def _runs(argv: list[str]) -> str;

obj NodeArtifact(ToolArtifact) {
    has name: str = "node",
        summary: str = "Node.js 22 (native build steps: Expo autolinking, Gradle, CocoaPods)";

    override def pinned -> (Download | None);
    override def marker(download: Download) -> str;
    override def on_system -> str;
    override def works(path: Path) -> bool;
}

def compatible_jdk(home: Path) -> bool;

obj JdkArtifact(ToolArtifact) {
    has name: str = "jdk",
        summary: str = "JDK 21 (Android builds)";

    override def pinned -> (Download | None);
    def _home(download: Download) -> str;
    override def marker(download: Download) -> str;
    override def located(slot: Path, download: Download) -> Path;
    override def on_system -> str;
    override def works(path: Path) -> bool;
}

obj PatchelfArtifact(ToolArtifact) {
    has name: str = "patchelf",
        summary: str = "patchelf (desktop bundles on Linux)",
        hosts: list[str] = ["linux"];

    override def pinned -> (Download | None);
    override def marker(download: Download) -> str;
    override def on_system -> str;
}

def tool_path(name: str) -> Path;
