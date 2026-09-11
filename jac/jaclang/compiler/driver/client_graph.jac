import from collections.abc { Callable }
import from pathlib { Path }
import type from jaclang.compiler.frontend.codeinfo { ClientArtifact }

obj ClientUnit {
    has path: Path,
        artifact: ClientArtifact;
}

obj ClientGraph {
    has modules: list[ClientUnit] = [],
        assets: list[Path] = [];
}

def collect_client_graph(
    roots: list[Path],
    artifact_of: Callable[[Path], ClientArtifact],
    variant_of: Callable[[Path], Path],
    virtual_modules: set[str],
    visited: set[Path]
) -> ClientGraph {
    import from jaclang.client.client_bundle { ClientBundleError }
    result = ClientGraph();
    pending: list[Path] = list(reversed(roots));
    artifacts: dict[Path, ClientArtifact] = {};

    def require(path: Path) -> ClientArtifact {
        found = artifacts.get(path);
        if found is None {
            found = artifact_of(path);
            artifacts[path] = found;
        }
        return found;
    }

    while pending {
        path = variant_of(pending.pop().resolve());
        if path in visited {
            continue;
        }
        visited.add(path);
        if path.suffix != '.jac' {
            if path.is_file() {
                result.assets.append(path);
            }
            continue;
        }
        artifact = require(path);
        result.modules.append(ClientUnit(path, artifact));
        for (dependency, names) in artifact.manifest.runtime_imports.items() {
            if not names {
                continue;
            }
            target: Path = variant_of(Path(dependency).resolve());
            provider = require(target).manifest;
            missing = sorted(set(names) - set(provider.exports + provider.globals));
            if missing {
                raise ClientBundleError(
                    f"{path}: runtime import(s) {', '.join(missing)} are not exported "
                    f"by {target}. Use :pub for runtime values; annotation-only "
                    "references must not produce runtime imports."
                );
            }
        }
        imports = [
            Path(str(import_path))
            for (name, import_path) in artifact.manifest.imports.items()
            if name not in virtual_modules
        ];
        pending.extend(reversed(imports));
    }
    return result;
}
