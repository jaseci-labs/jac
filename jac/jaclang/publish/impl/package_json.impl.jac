import json;
import from pathlib { Path }
import from jaclang.project.config { JacConfig, PersonConfig }
import from jaclang.publish.metadata { normalize_package_name }

impl npm_settings(config: JacConfig) -> dict[str, any] {
    raw = config._raw_data.get("npm", {});
    return raw if isinstance(raw, dict) else {};
}

impl npm_package_name(config: JacConfig) -> str {
    npm = npm_settings(config);
    override = npm.get("name", "");
    if override {
        return override;
    }
    if not config.project.name {
        raise ValueError(
            "Cannot determine npm package name: [project] name is missing in jac.toml."
        );
    }
    return normalize_package_name(config.project.name);
}

impl npm_tarball_filename(config: JacConfig) -> str {
    name = npm_package_name(config);

    flat = name.lstrip("@").replace("/", "-");
    return f"{flat}-{config.project.version}.tgz";
}

impl npm_dependencies(config: JacConfig) -> dict[str, str] {
    result: dict[str, str] = {};

    raw = config.plugin_dependencies.get("npm", {});
    for (key, value) in raw.items() {
        if key == "dev" {
            continue;
        }
        if isinstance(value, str) {
            result[key] = value;
        }
    }

    npm = npm_settings(config);
    override = npm.get("dependencies", {});
    if isinstance(override, dict) {
        for (key, value) in override.items() {
            if isinstance(value, str) {
                result[key] = value;
            }
        }
    }
    return result;
}

impl npm_peer_dependencies(config: JacConfig) -> dict[str, str] {
    result: dict[str, str] = {};
    npm = npm_settings(config);

    peers = npm.get("peer_dependencies", npm.get("peerDependencies", {}));
    if isinstance(peers, dict) {
        for (key, value) in peers.items() {
            if isinstance(value, str) {
                result[key] = value;
            }
        }
    }
    return result;
}

def _author_header(persons: list[PersonConfig]) -> str {
    for p in persons {
        if p.name and p.email {
            return f"{p.name} <{p.email}>";
        } elif p.name {
            return p.name;
        } elif p.email {
            return p.email;
        }
    }
    return "";
}

def _repository_url(urls: dict[str, str]) -> str {
    for key in ["repository", "repo", "source", "homepage"] {
        if urls.get(key) {
            return urls[key];
        }
    }
    return "";
}

impl generate_package_json(
    config: JacConfig,
    project_root: Path | None = None,
    main: str | None = None,
    types: str | None = None,
    extra_dependencies: dict[str, str] | None = None,
    extra_peer_dependencies: dict[str, str] | None = None,
) -> str {
    if not config.project.name {
        raise ValueError(
            "Cannot generate package.json: [project] name is missing in jac.toml."
        );
    }

    pkg = config.project;
    doc: dict[str, any] = {};
    doc["name"] = npm_package_name(config);
    doc["version"] = pkg.version;
    if pkg.description {
        doc["description"] = pkg.description;
    }
    if pkg.license {
        doc["license"] = pkg.license;
    }

    author = _author_header(pkg.authors);
    if author {
        doc["author"] = author;
    }
    if pkg.keywords {
        doc["keywords"] = list(pkg.keywords);
    }

    repo_url = _repository_url(pkg.urls);
    if repo_url {
        doc["repository"] = {"type": "git", "url": repo_url};
    }
    if pkg.urls.get("homepage") {
        doc["homepage"] = pkg.urls["homepage"];
    }

    doc["type"] = "module";

    if main {
        rel = main if main.startswith("./") else f"./{main}";
        doc["main"] = main;
        doc["module"] = main;
        condition: dict[str, str] = {};
        if types {
            type_rel = types if types.startswith("./") else f"./{types}";
            doc["types"] = types;
            condition["types"] = type_rel;
        }
        condition["import"] = rel;
        doc["exports"] = {".": condition};
    }

    deps: dict[str, str] = dict(extra_dependencies or {});
    deps.update(npm_dependencies(config));
    if deps {
        doc["dependencies"] = {k: deps[k] for k in sorted(deps)};
    }
    peers: dict[str, str] = dict(extra_peer_dependencies or {});
    peers.update(npm_peer_dependencies(config));
    if peers {
        doc["peerDependencies"] = {k: peers[k] for k in sorted(peers)};
    }

    return json.dumps(doc, indent=2) + "\n";
}
