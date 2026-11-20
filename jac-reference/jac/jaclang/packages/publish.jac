import io;
import json;
import tarfile;
import time;
import from pathlib { Path }

glob SOURCE_URL_KEYS: tuple[str, ...] = (
         "repository",
         "Repository",
         "source",
         "Source"
     );

obj PublishError(Exception) {}

obj PublishPlan {
    has built: BuiltPackage,
        item: IndexEntry,
        previous: IndexEntry | None = None,
        changes: list[ApiChange] = [],
        problems: list[str] = [];
}

def source_url(config: JacConfig) -> str;

def surface_in_blob(data: bytes) -> dict[str, any] | None;

def previous_release(entries: list[IndexEntry], version: Version) -> IndexEntry | None;

def previous_surface(
    registry: Registry, previous: IndexEntry
) -> dict[str, any] | None;

def api_changes(
    registry: Registry, previous: IndexEntry, surface: dict[str, any]
) -> list[ApiChange];

def gate_problems(config: JacConfig, role: str) -> list[str];

def check_gate(config: JacConfig) -> bool;

def plan_publish(
    config: JacConfig, registry: Registry, run_check: bool = True
) -> PublishPlan;

def report_plan(plan: PublishPlan);

def index_repo(registry: Registry) -> str;

def open_index_pull(
    registry: Registry,
    item: IndexEntry,
    data: bytes | None,
    title: str,
    body: str,
    surface: dict[str, any] | None = None
) -> str;

def publish_project(
    config: JacConfig, dry_run: bool = False, registry_name: str = "", output: str = ""
) -> int;

def yank_version(config: JacConfig, version: str, registry_name: str = "") -> int;
