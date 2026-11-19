"""The apps a project's archwire.jac declares.

A `graph spaces` block places modules in spaces and groups spaces into apps. jac
builds each app as one of its kinds: the spaces an app runs and serves decide the
kind and the module it starts at, and every module a space holds is pinned to
the codespace its host runs in.
"""

obj DerivedApp {
    has name: str,
        kind: str = "",
        entry_point: str = "",
        pins: dict[str, str] = {},
        runs: list[str] = [],
        serves: list[str] = [],
        remote: list[str] = [],
        arrangements: dict[str, list[str]] = {},
        hosts: dict[str, str] = {};
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

def _space_entry(space: SpaceRec) -> str;
