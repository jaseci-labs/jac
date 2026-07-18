import from pathlib { Path }
import from jaclang.project.config { JacConfig, PersonConfig }

glob METADATA_VERSION: str = "2.4";

def normalize_package_name(name: str) -> str;

def normalize_constraint(raw: str) -> str;

def build_requires_dist(name: str, raw_ver: str, extra: str | None = None) -> str;

def generate_metadata(config: JacConfig, project_root: Path | None = None) -> str;

def generate_pyproject_toml(config: JacConfig) -> str;
