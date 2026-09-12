import from pathlib { Path }
import type from jaclang.compiler.backends.common.artifacts { ClientArtifact }

obj ClientUnit {
    has path: Path,
        artifact: ClientArtifact;
}

obj ClientGraph {
    has modules: list[ClientUnit] = [],
        assets: list[Path] = [];
}

obj ClientLinkRequest {
    has roots: list[Path],
        artifact_of: Callable[[Path], ClientArtifact],
        variant_of: Callable[[Path], Path],
        virtual_modules: set[str],
        visited: set[Path];
}
