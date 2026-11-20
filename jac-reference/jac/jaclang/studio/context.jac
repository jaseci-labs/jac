import os;
import re;

glob WIRE_PREFIX: str = "wire:",
     WIRE_SCHEME: str = "jac://wire/",
     MAP_SCHEME: str = "jac://map/",
     DEPS_SCHEME: str = "jac://deps/",
     JAC_MIME: str = "text/x-jac",
     MAX_DECL_LINES: int = 300,
     MAX_MODULE_SOURCE: int = 120,
     MAX_BLOCK_LINES: int = 600,
     MAX_WIRES: int = 12,
     MAX_OUTLINE: int = 80;

def context_blocks(model: ProjectModel, keys: list[str]) -> list[dict[str, any]];

def context_block(model: ProjectModel, key: str) -> (dict[str, any] | None);

def symbol_context(model: ProjectModel, key: str) -> str;

def resolve_key(model: ProjectModel, query: str) -> str;

def wire_key(w: WireInfo) -> str;

def find_wire(model: ProjectModel, key: str) -> (WireInfo | None);

def module_of(model: ProjectModel, key: str) -> str;

def rel(model: ProjectModel, path: str) -> str;

def read_lines(path: str, first: int, last: int, budget: int) -> list[str];

def source_section(
    model: ProjectModel, label: str, path: str, first: int, last: int, budget: int
) -> list[str];

def wire_line(w: WireInfo, direction: str) -> str;

def tidy_sig(sig: str) -> str;

def sig_suffix(sig: str) -> str;

def names_of(w: WireInfo) -> list[str];

def carrying_wires(model: ProjectModel, nd: StNode) -> list[WireInfo];

def rule_lines(model: ProjectModel, mod_key: str) -> list[str];

def node_header(model: ProjectModel, nd: StNode) -> list[str];

def module_text(model: ProjectModel, mod: StModule) -> str;

def symbol_text(model: ProjectModel, nd: StNode) -> str;

def wire_text(model: ProjectModel, w: WireInfo) -> str;
