import from collections.abc { Callable }
import from pathlib { Path }

obj ClientUnit {
    has path: Path,
        artifact: ClientArtifact;
}

obj ClientLink {
    has names: list[str] = [],
        forwards: dict[str, list[str]] = {},
        boundary: bool = False;
}

obj ClientGraph {
    has modules: list[ClientUnit] = [],
        refreshed: list[ClientUnit] = [],
        assets: list[Path] = [],
        links: dict[Path, ClientLink] = {};
}

def collect_client_graph(
    roots: list[Path],
    artifact_of: Callable[[Path], ClientArtifact],
    variant_of: Callable[[Path], Path],
    virtual_modules: set[str],
    visited: set[Path],
    demand: (dict[Path, dict[Path, list[str]]] | None) = None
) -> ClientGraph;

def link_exports(
    manifest: ClientManifest, importers: dict[Path, list[str]]
) -> ClientLink;

def link_tail(link: ClientLink) -> str;

def append_link(js: str, link: (ClientLink | None)) -> str;
