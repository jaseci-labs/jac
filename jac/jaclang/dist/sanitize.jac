import os;
import from pathlib { Path }

glob LOCAL_OVERLAY_NAME: str = "jac.local.toml";

def is_secret_path(name: str) -> bool;

def is_dev_section(name: str) -> bool;

def sanitize_jac_toml_text(text: str) -> str;

def sanitized_jac_toml(base: Path) -> (str | None);

def sanitize_shipped_tree(tree: Path);
