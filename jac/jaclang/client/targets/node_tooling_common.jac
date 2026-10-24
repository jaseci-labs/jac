import subprocess;
import hashlib;
import json;
import from pathlib { Path }

def resolve_node_tool_entry(project_dir: Path, tool: str) -> (Path | None);

def resolve_node_tool(project_dir: Path, tool: str) -> list[str];

def run_manifest_install(project_dir: Path);

def _deps_current(project_dir: Path, stamp: Path, signature: str) -> bool;

def manifest_signature(project_dir: Path) -> str;
