import os;
import re;

obj DerivedApp {
    has name: str,
        kind: str = "",
        entry_point: str = "",
        pins: dict[str, str] = {};
}

obj Space {
    has name: str,
        host: str,
        entry_module: str = "",
        patterns: list[str] = [];
}

glob HOST_PLACEMENT: dict[str, str] = {
         "native": "server",
         "cpython": "server",
         "node": "server",
         "browser": "client",
         "hermes": "client",
         "wasm": "native"
     };

def archwire_apps(root_dir: str) -> dict[str, DerivedApp];

def _braced(text: str, open_at: int) -> tuple[str, int];

def _declarations(
    source: str
) -> tuple[dict[str, Space], list[tuple[str, list[str], list[str]]]];

def _derive(name: str, runs: list[Space], serves: list[Space]) -> DerivedApp | None;

def _entry_of(space: Space) -> str;
