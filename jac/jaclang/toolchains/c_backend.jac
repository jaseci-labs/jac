import os;
import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }

glob LLVM_MAJOR: int = 22,
     C_BACKEND: Artifact = Artifact(
         'llvm-cbe',
         'a13fcf3b27079f4989902594b7c72f81f75c5357',
         'source',
         'https://codeload.github.com/JuliaHubOSS/llvm-cbe/tar.gz/a13fcf3b27079f4989902594b7c72f81f75c5357',
         'd425227fe3bd6a69299b188754403e20b0c840cf1609955c0ccbb68827e34ab9'
     );

def _c_backend_slot -> Path;

def _c_backend_binary -> Path;

def _llvm_config -> (str | None);

obj CBackendArtifact(ArtifactBase) {
    has name: str = 'llvm-cbe',
        kind: ArtifactKind = ArtifactKind.CAPABILITY,
        release: ReleasePolicy = ReleasePolicy.ON_DEMAND,
        summary: str = 'the LLVM C backend (C source export)';

    override def probe_checkout -> Probe;
    override def checkout_path -> str;
    override def build_blocker -> str;
    override def build(log: Callable[[str], None], force: bool, exact: bool);
}

def ensure_c_backend -> Path;

def _build_c_backend;


def c_backend_provenance -> dict[str, str | int];

def c_backend_license -> Path;
