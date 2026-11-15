import os;
import shutil;
import tempfile;
import from pathlib { Path }

def cef_artifact(sums: Path) -> Artifact;

def ensure_cef(directory: Path, headers_only: bool = False) -> Path;
