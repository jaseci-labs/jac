impl collect_client_graph(
    roots: list[Path],
    artifact_of: Callable[[Path], ClientArtifact],
    variant_of: Callable[[Path], Path],
    virtual_modules: set[str],
    visited: set[Path],
    demand: (dict[Path, dict[Path, list[str]]] | None) = None
) -> ClientGraph {
    result = ClientGraph();
    wants: dict[Path, dict[Path, list[str]]] = demand if demand is not None else {};
    pending: list[Path] = list(reversed(roots));
    artifacts: dict[Path, ClientArtifact] = {};
    walked: set[Path] = set();
    refreshed: set[Path] = set();
    linked: list[tuple[Path, Path]] = [];

    def require(path: Path) -> ClientArtifact {
        found = artifacts.get(path);
        if found is None {
            found = artifact_of(path);
            artifacts[path] = found;
        }
        return found;
    }

    def queue_imports(artifact: ClientArtifact) {
        imports = [
            Path(str(import_path))
            for (name, import_path) in artifact.manifest.imports.items()
            if name not in virtual_modules
        ];
        pending.extend(reversed(imports));
    }

    def refresh(path: Path) -> bool {
        return path in visited and path not in walked and path not in refreshed;
    }

    def record_imports(path: Path, artifact: ClientArtifact) {
        for importers in wants.values() {
            importers.pop(path, None);
        }
        for (dependency, names) in artifact.manifest.runtime_imports.items() {
            if not names {
                continue;
            }
            target: Path = variant_of(Path(dependency).resolve());
            provider_artifact = require(target);
            importers = wants.setdefault(target, {});
            importers[path] = sorted(set(importers.get(path, [])) | set(names));
            linked.append((path, target));
            if refresh(target) {
                refreshed.add(target);
                result.refreshed.append(ClientUnit(target, provider_artifact));
                record_imports(target, provider_artifact);
                queue_imports(provider_artifact);
            }
        }
    }

    def forward_reexports -> bool {
        grew = False;
        for (path, artifact) in list(artifacts.items()) {
            manifest = artifact.manifest;
            if not manifest.forwards or path not in wants {
                continue;
            }
            declared = set(manifest.exports + manifest.globals + manifest.linkable);
            hops: dict[Path, set[str]] = {};
            for names in wants[path].values() {
                for name in names {
                    hop = manifest.forwards.get(name);
                    if hop is not None and name not in declared {
                        source: Path = variant_of(Path(hop[1]).resolve());
                        hops.setdefault(source, set()).add(hop[2]);
                    }
                }
            }
            for (source, names) in hops.items() {
                importers = wants.setdefault(source, {});
                current = set(importers.get(path, []));
                if names.issubset(current) {
                    continue;
                }
                importers[path] = sorted(current | names);
                linked.append((path, source));
                source_artifact = require(source);
                if refresh(source) {
                    refreshed.add(source);
                    result.refreshed.append(ClientUnit(source, source_artifact));
                    record_imports(source, source_artifact);
                    queue_imports(source_artifact);
                }
                grew = True;
            }
        }
        return grew;
    }

    grew = True;
    while grew {
        while pending {
            path = variant_of(pending.pop().resolve());
            if path in visited {
                continue;
            }
            visited.add(path);
            walked.add(path);
            if path.suffix != '.jac' {
                if path.is_file() {
                    result.assets.append(path);
                }
                continue;
            }
            artifact = require(path);
            result.modules.append(ClientUnit(path, artifact));
            record_imports(path, artifact);
            queue_imports(artifact);
        }
        grew = forward_reexports();
    }

    checked: set[tuple[Path, Path]] = set();
    for (importer, provider) in linked {
        if (importer, provider) in checked {
            continue;
        }
        checked.add((importer, provider));
        manifest = require(provider).manifest;
        offered = set(
            manifest.exports
                + manifest.globals
                + manifest.linkable
                + list(manifest.forwards.keys())
        );
        missing = sorted(set(wants[provider].get(importer, [])) - offered);
        if missing {
            raise ClientBundleError(
                f"{importer}: runtime import(s) {', '.join(missing)} are not exported "
                f"by {provider}. A client module exports every client declaration "
                "that is not `:priv` and every client import it forwards; "
                "annotation-only references must not produce runtime imports."
            );
        }
    }
    for unit in result.modules + result.refreshed {
        result.links[unit.path] = link_exports(
            unit.artifact.manifest, wants.get(unit.path, {})
        );
    }
    return result;
}

impl link_exports(
    manifest: ClientManifest, importers: dict[Path, list[str]]
) -> ClientLink {
    declared = set(manifest.exports + manifest.globals);
    linkable = set(manifest.linkable);
    link = ClientLink();
    wanted: set[str] = set();
    for names in importers.values() {
        wanted.update(names);
    }
    for name in sorted(wanted - declared) {
        if name in linkable {
            link.names.append(name);
        } elif name in manifest.forwards {
            link.forwards[name] = list(manifest.forwards[name]);
        }
    }
    exported = declared | set(link.names);
    link.boundary = bool(exported)
        and not link.forwards
        and exported.issubset(set(manifest.components));
    return link;
}

impl link_tail(link: ClientLink) -> str {
    lines: list[str] = [];
    if link.boundary {
        lines.append("/*jac:refresh-boundary*/;");
    }
    if link.names {
        lines.append(f"export {{{', '.join(link.names)}}};");
    }
    by_source: dict[str, list[str]] = {};
    for (local, hop) in sorted(link.forwards.items()) {
        by_source.setdefault(hop[0], []).append(
            local if hop[2] == local else f"{hop[2]} as {local}"
        );
    }
    for (specifier, names) in by_source.items() {
        quoted = specifier.replace("\\", "\\\\").replace('"', '\\"');
        lines.append(f"export {{{', '.join(names)}}} from \"{quoted}\";");
    }
    return "".join(f"{line}\n" for line in lines);
}

impl append_link(js: str, link: (ClientLink | None)) -> str {
    tail = link_tail(link) if link is not None else "";
    if tail and js and not js.endswith("\n") {
        return f"{js}\n{tail}";
    }
    return js + tail;
}
