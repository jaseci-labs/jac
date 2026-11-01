"""`jac arch` plans, made inside the kernel session: the wiring an
archwire.jac should hold, read from the modules it governs. The host writes
what a plan holds; nothing here touches the file system beyond reading."""
import json;
import os;

def module_files(spec: WiringSpec) -> list[tuple[str, str]];

def parsed_imports(
    host: ProjectHost, path: str
) -> list[tuple[Import, (list[str] | None)]];

def collect_facts(
    host: ProjectHost, spec: WiringSpec, modules: list[tuple[str, str]]
) -> list[tuple[str, WireBinding]];

def unused_facts(
    host: ProjectHost, spec: WiringSpec, modules: list[tuple[str, str]]
) -> set[tuple[str, tuple[str, str, str, str]]];

def feeds(spec: WiringSpec, consumer: str, module: str) -> bool;

def node_id(name: str) -> str;

def render_mermaid(spec: WiringSpec) -> str;

def render_json(spec: WiringSpec) -> str;

def laid_out(plan: ArchPlan, text: str) -> ArchPlan;

def init_plan(host: ProjectHost, arch_path: str) -> ArchPlan;

def sync_plan(host: ProjectHost, arch_path: str, prune: bool) -> ArchPlan;

def graph_plan(arch_path: str, graph_format: str) -> ArchPlan;
