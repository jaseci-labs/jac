import inspect;
import json;
import os;
import from pathlib { Path }

glob API_FORMAT: int = 1,
     DOC_KEYS: tuple[str, ...] = ("doc", "value"),
     MODULE_DOCS: str = "module_docs",
     ARCHETYPE_KINDS: dict[SymbolType, str] = {
         SymbolType.OBJECT_ARCH: "obj",
         SymbolType.NODE_ARCH: "node",
         SymbolType.EDGE_ARCH: "edge",
         SymbolType.WALKER_ARCH: "walker",
         SymbolType.ENUM_ARCH: "enum"
     },
     PARAM_KINDS: dict[int, str] = {
         0: "positional",
         1: "normal",
         2: "varargs",
         3: "keyword",
         4: "kwargs"
     };

obj ApiError(Exception) {}

def _type_text(t: any) -> str;

def _is_public(name: str, sym: Symbol) -> bool;

def _decl_of(sym: Symbol) -> any;

def doc_text(nd: any) -> str;

def source_text(nd: any) -> str;

def _with_doc(desc: dict[str, any], nd: any) -> dict[str, any];

def _param_nodes(decl: any) -> dict[str, any];

def _signature(ftype: any, decl: any = None) -> dict[str, any];

def _field(sym: Symbol, mtype: any) -> dict[str, any];

def _members(sym: Symbol, evaluator: any) -> dict[str, dict[str, any]];

def describe_symbol(sym: Symbol, evaluator: any) -> dict[str, any] | None;

def module_surface(mod: Module, evaluator: any) -> dict[str, dict[str, any]];

def module_path_for(base_root: Path, module: str) -> Path | None;

def package_surface(base_root: Path, exports: list[str]) -> dict[str, any];

def _undocumented(desc: dict[str, any]) -> dict[str, any];

def api_shape(surface: dict[str, any]) -> dict[str, any];

def surface_digest(surface: dict[str, any]) -> str;
