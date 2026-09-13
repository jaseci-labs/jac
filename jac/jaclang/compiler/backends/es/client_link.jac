import from pathlib { Path }
import type from jaclang.compiler.backends.common.artifacts { ClientArtifact }
import from jaclang.compiler.backends.es.link_facts {
    ClientUnit,
    ClientGraph,
    ClientLinkRequest
}
import from jaclang.compiler.pipeline.program_pass { QueryTransform }
import type from jaclang.compiler.ir.schema { Module }

walker ClientLinkPass(QueryTransform[ClientGraph]) {
    has request: ClientLinkRequest,
        result: ClientGraph = ClientGraph();

    def transform(ir_in: Module) -> Module {
        roots = self.request.roots;
        artifact_of = self.request.artifact_of;
        variant_of = self.request.variant_of;
        virtual_modules = self.request.virtual_modules;
        visited = self.request.visited;
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
                        f"{path}: runtime import(s) {', '.join(
                            missing
                        )} are not exported "
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
        self.result = result;
        return ir_in;
    }
}
