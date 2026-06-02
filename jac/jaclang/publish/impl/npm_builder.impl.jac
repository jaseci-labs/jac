"""Implementation of the NpmBuilder."""

import importlib.metadata;
import from pathlib { Path }
import from jaclang.publish.npm_tarball { pack_tarball }
import from jaclang.publish.npm_sources {
    collect_npm_sources,
    resolve_npm_entry,
    runtime_pkg_name
}
import from jaclang.publish.package_json { generate_package_json, npm_tarball_filename }

"""Aggregate per-module external imports into npm dependencies + peerDependencies.

   The Jac client runtime package lands in `dependencies` (pinned to a caret range
   on the installed jaclang version); react/react-dom land in `peerDependencies`."""
def _resolve_externals(
    config: any, files: list[any]
) -> tuple[dict[str, str], dict[str, str]] {
    externals: set = set();
    for f in files {
        for ext in f.external_imports {
            externals.add(ext);
        }
    }
    deps: dict[str, str] = {};
    peers: dict[str, str] = {};
    if not externals {
        return (deps, peers);
    }

    rt_pkg = runtime_pkg_name(config);
    npm = config._raw_data.get("npm", {});
    npm = npm if isinstance(npm, dict) else {};

    if rt_pkg in externals {
        rt_ver = npm.get("runtime_version", "");
        if not rt_ver {
            try {
                rt_ver = "^" + importlib.metadata.version("jaclang");
            } except Exception {
                rt_ver = "*";
            }
        }
        deps[rt_pkg] = rt_ver;
    }
    if "react" in externals {
        peers["react"] = npm.get("react_version", ">=18.0.0");
    }
    if "react-dom" in externals {
        peers["react-dom"] = npm.get("react_dom_version", ">=18.0.0");
    }
    return (deps, peers);
}

impl NpmBuilder.postinit -> None {
    if self.project_root is None {
        self.project_root = self.config.project_root;
    }
}

impl NpmBuilder.build -> bytes {
    if not self.config.project.name {
        raise ValueError(
            "Cannot build npm package: [project] name is missing in jac.toml."
        );
    }
    proj_root = self.project_root;
    if proj_root is None {
        raise ValueError("Cannot build npm package: project_root is not set.");
    }

    files = collect_npm_sources(self.config, project_root=proj_root);
    entry = resolve_npm_entry(self.config, files);
    (extra_deps, extra_peers) = _resolve_externals(self.config, files);

    # The entry's `.d.ts` (when it has one) becomes package.json `types`.
    types = None;
    if entry {
        for f in files {
            if f.npm_path == entry and f.dts {
                types = entry[:-3] + ".d.ts";  # strip ".js"
            }
        }
    }
    pj = generate_package_json(
        self.config,
        project_root=proj_root,
        main=entry,
        types=types,
        extra_dependencies=extra_deps,
        extra_peer_dependencies=extra_peers,
    );

    members: list[tuple[str, bytes]] = [("package/package.json", pj.encode("utf-8"))];
    for f in files {
        members.append((f"package/{f.npm_path}", f.js.encode("utf-8")));
        if f.dts {
            dts_path = f.npm_path[:-3] + ".d.ts";
            members.append((f"package/{dts_path}", f.dts.encode("utf-8")));
        }
    }
    readme = self.config.project.readme;
    if readme {
        readme_path = proj_root / readme;
        if readme_path.exists() {
            members.append((f"package/{readme}", readme_path.read_bytes()));
        }
    }
    return pack_tarball(members);
}

impl NpmBuilder.build_to(output_dir: Path) -> Path {
    output_dir.mkdir(parents=True, exist_ok=True);
    dest = output_dir / npm_tarball_filename(self.config);
    dest.write_bytes(self.build());
    return dest;
}
