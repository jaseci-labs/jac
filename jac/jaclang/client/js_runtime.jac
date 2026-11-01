import json;
import os;
import platform;

glob BUN_VERSION: str = "1.3.11",
     RECORD_SUFFIX: str = ".artifact.json",
     ENGINE_LIBRARY: str = "libjs_engine.so",
     ENGINE_SOURCES: tuple[str, ...] = ("engine/src", "napi/src", "native", "jac.toml");

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

def _repo_root -> str;

def js_engine_build_dir -> str;

def js_engine_inputs_digest(repo_root: str) -> str;

def installed_engine_dir -> str;

def _installed_engine -> Probe;

def ensure_node_link(engine: str) -> str;

def _install_engine(built: str);

def _engine_record(engine: str) -> str;

obj JsEngineArtifact(Artifact) {
    has name: str = "js-engine",
        kind: ArtifactKind = ArtifactKind.ACCELERATOR,
        release: ReleasePolicy = ReleasePolicy.FLOOR,
        summary: str = "js_engine (the native JavaScript runtime)",
        floor: str = "bun",
        hosts: list[str] = ["linux-x86_64"];

    override def probe_sealed -> (Probe | None);
    override def probe_checkout -> Probe;
    override def probe_kit -> Probe;
    override def checkout_path -> str;
    override def built -> Probe;
    override def build_blocker -> str;
    override def build(log: Callable[[str], None], force: bool, exact: bool);
    override def floor_present -> bool;
    override def provide_floor(log: Callable[[str], None]);
}

def _engine -> (str | None);

def js_runtime_path -> str;

def run_pm(args: list[str], cwd: str, capture: bool = False) -> tuple[int, str];
