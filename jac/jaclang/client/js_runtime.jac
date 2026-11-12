import json;
import os;
import platform;

glob BUN_VERSION: str = "1.3.11",
     RECORD_SUFFIX: str = ".artifact.json";

def bun_name -> str;

def bun_path_in(pkg_dir: str) -> str;

def write_bun_record(path: str);

def _recorded_version(path: str) -> str;

def _reported_version(path: str) -> str;

def _probe_bun(path: str, source: Source) -> Probe;

def _pkg_dir -> str;

obj BunArtifact(Artifact) {
    has name: str = "bun",
        kind: ArtifactKind = ArtifactKind.CAPABILITY,
        release: ReleasePolicy = ReleasePolicy.REQUIRED,
        summary: str = "bun (the shipped JavaScript runtime)";

    override def probe_sealed -> (Probe | None);
    override def probe_checkout -> Probe;
    override def probe_kit -> Probe;
    override def checkout_path -> str;
    override def build(log: Callable[[str], None], force: bool, exact: bool);
}

def js_runtime_path -> str;

def run_pm(args: list[str], cwd: str, capture: bool = False) -> tuple[int, str];
