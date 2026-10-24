import shutil;
import tempfile;
import from pathlib { Path }

obj TemplateError(Exception) {}

def is_template_spec(spec: str) -> bool;

def pick_template(
    entries: list[IndexEntry], requirement: Requirement, jac: Version
) -> IndexEntry | None;

def unpack_template(data: bytes, label: str) -> Path;

def fetch_template(spec: str, registries: dict[str, str] | None = None) -> Path;

def load_template_jab(path: Path) -> Path;
