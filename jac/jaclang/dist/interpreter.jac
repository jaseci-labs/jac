import ctypes;
import os;
import sys;

def running_jacpython -> bool;

def _repo_root -> str;

def jacpython_binary -> str;

def _this_process(source: Source) -> Probe;

obj JacPythonArtifact(Artifact) {
    has name: str = "jacpython",
        kind: ArtifactKind = ArtifactKind.ACCELERATOR,
        release: ReleasePolicy = ReleasePolicy.FLOOR,
        summary: str = "JacPython (the interpreter whose compiler is native Jac)",
        floor: str = "CPython",
        hosts: list[str] = ["linux", "darwin"];

    override def probe_sealed -> (Probe | None);
    override def probe_checkout -> Probe;
    override def probe_kit -> Probe;
    override def checkout_path -> str;
    override def built -> Probe;
    override def build_blocker -> str;
    override def build(log: Callable[[str], None], force: bool, exact: bool);
}
