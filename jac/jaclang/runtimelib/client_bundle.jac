"""Client bundle generation utilities for Jac web front-ends."""
import hashlib;
import os;
import from collections.abc { Iterable }
import from pathlib { Path }
import from types { ModuleType }
import from typing { Any }
import type from jaclang.jac0core.codeinfo { ClientManifest }
import type from jaclang.jac0core.unitree { Module }

"""Raised when the client bundle cannot be generated."""
class ClientBundleError(RuntimeError) {}

"""Look up a module in one program's hub (single-hub, recompiles on miss in the
caller); see the impl for why the bundler must not span programs."""
def _lookup_module_in_hub(path_key: str, hub: dict) -> (Module | None);

"""Run EsastGenPass if JS missing (Windows may skip ES pass during initial compile)."""
def _ensure_js_generated(mod: Module, program: any) -> None;

"""Container for a compiled client bundle."""
obj ClientBundle {
    has module_name: str,
        code: str,
        client_functions: list[str],
        client_globals: list[str],
        hash: str;
}

obj _CachedBundle {
    has signature: str,
        bundle: ClientBundle;
}

"""Shared base for client bundle builders: compiles Jac modules to JS, extracts
the client manifest surface, and caches by source signature. Concrete bundling
(`_compile_bundle`) is provided by the jac-client plugin's Vite/Bun builder; the
base raises if invoked standalone."""
obj ClientBundleBuilder {
    has runtime_path: (Path | None) = None,
        _cache: dict[(str, _CachedBundle)] = {};

    def postinit -> None;
    def build(module: ModuleType, force: bool = False) -> ClientBundle;
    def _extract_client_exports(manifest: (ClientManifest | None)) -> list[str];
    def _extract_client_globals(
        manifest: (ClientManifest | None), module: ModuleType
    ) -> dict[str, any];

    def _compile_bundle(module: ModuleType, module_path: Path) -> ClientBundle;
    def _compile_to_js(source_path: Path) -> tuple[str, Module];
    static def _signature(paths: Iterable[Path]) -> str;
}
