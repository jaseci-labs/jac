import io;
import json;
import tarfile;
import time;
import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.packages.apidiff {
    ApiChange,
    check_bump,
    diff_surfaces,
    minimum_next
}
import from jaclang.packages.artifact {
    API_FILE,
    ArtifactError,
    BuiltPackage,
    MANIFEST_DIR,
    ROLE_LIB,
    ROLE_TEMPLATE,
    build_package,
    package_identity,
    project_role
}
import from jaclang.packages.index {
    IndexEntry,
    Registry,
    RegistryError,
    api_rel_path,
    index_rel_path,
    parse_index_lines,
    registry_named
}
import from jaclang.packages.semver { SemverError, Version }
import from jaclang.project.config { JacConfig }
import from jaclang.project.package_scope { is_package_name }

glob SOURCE_URL_KEYS: tuple[str, ...] = (
         "repository",
         "Repository",
         "source",
         "Source"
     );

obj PublishError(Exception) {}

obj PublishPlan {
    has built: BuiltPackage,
        item: IndexEntry,
        previous: IndexEntry | None = None,
        changes: list[ApiChange] = [],
        problems: list[str] = [];
}

def source_url(config: JacConfig) -> str {
    for key in SOURCE_URL_KEYS {
        value = str(config.project.urls.get(key, "")).strip();
        if value {
            return value;
        }
    }
    return "";
}

def surface_in_blob(data: bytes) -> dict[str, any] | None {
    wanted = f"{MANIFEST_DIR}/{API_FILE}";
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:*") as tf {
        for member in tf.getmembers() {
            if member.name.lstrip("./") == wanted {
                handle = tf.extractfile(member);
                return json.loads(handle.read().decode("utf-8")) if handle else None;
            }
        }
    }
    return None;
}

def previous_release(entries: list[IndexEntry], version: Version) -> IndexEntry | None {
    best: IndexEntry | None = None;
    best_version: Version | None = None;
    for e in entries {
        if e.yanked {
            continue;
        }
        try {
            v = Version.parse(e.version);
        } except SemverError {
            continue;
        }
        if v >= version or v.is_prerelease() {
            continue;
        }
        if best_version is None or v > best_version {
            best = e;
            best_version = v;
        }
    }
    return best;
}

def previous_surface(
    registry: Registry, previous: IndexEntry
) -> dict[str, any] | None {
    published = registry.api(previous.name, previous.version);
    if published is not None {
        return published;
    }
    return surface_in_blob(registry.fetch_blob(previous));
}

def api_changes(
    registry: Registry, previous: IndexEntry, surface: dict[str, any]
) -> list[ApiChange] {
    old = previous_surface(registry, previous);
    if old is None {
        return [];
    }
    return diff_surfaces(old, surface);
}

def gate_problems(config: JacConfig, role: str) -> list[str] {
    problems: list[str] = [];
    ident = package_identity(config);
    if not is_package_name(ident.name) {
        problems.append(f"'{ident.name}' is not a scoped package name (org/name)");
    }
    try {
        Version.parse(ident.version);
    } except SemverError as e {
        problems.append(str(e));
    }
    if role == ROLE_LIB {
        if not config.project.jac_version {
            problems.append(
                "[project] jac-version must state the jac versions it supports"
            );
        }
        for dep in [*config.dependencies.values()] {
            if dep.kind() != "registry" {
                problems.append(
                    f"{dep.name} is a {dep.kind()} dependency; a published package "
                    "can only depend on registry packages"
                );
            }
        }
        url = source_url(config);
        if not url.startswith("https://") {
            problems.append(
                "[project.urls] repository must name the package's public source "
                "repository (https://...)"
            );
        }
    }
    return problems;
}

def check_gate(config: JacConfig) -> bool {
    import from jaclang.cli.commands.analysis { check }
    return check(
        paths=[str(config.project_root)],
        ignore=[".jac", "node_modules", ".git", "_precompiled"],
        print_errs=True
    )
        == 0;
}

def plan_publish(
    config: JacConfig, registry: Registry, run_check: bool = True
) -> PublishPlan {
    role = project_role(config);
    if role not in (ROLE_LIB, ROLE_TEMPLATE) {
        raise PublishError(
            "only a library (scoped [project] name) or a template ([jacpack]) "
            "can be published; an app ships with 'jac build'"
        );
    }
    problems = gate_problems(config, role);
    if problems {
        raise PublishError("\n  ".join(["the package is not publishable:", *problems]));
    }
    try {
        built = build_package(config);
    } except ArtifactError as e {
        raise PublishError(str(e));
    }
    ident = package_identity(config);
    version = Version.parse(ident.version);
    entries = registry.entries(ident.name);
    plan_problems: list[str] = [];
    if any(e.version == ident.version for e in entries) {
        plan_problems.append(
            f"{ident.name} {ident.version} is already published; versions never change"
        );
    }
    item = IndexEntry(
        name=ident.name,
        version=ident.version,
        sha256=built.sha256,
        role=role,
        description=str(built.manifest.get("description", "")),
        deps=dict(built.manifest.get("deps", {})),
        pypi=dict(built.manifest.get("pypi", {})),
        npm=dict(built.manifest.get("npm", {})),
        jac_version=config.project.jac_version,
        api_digest=str(built.manifest.get("api_digest", "")),
        exports=list(built.manifest.get("exports", [])),
        published=time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        source=source_url(config)
    );
    previous = previous_release(entries, version);
    changes: list[ApiChange] = [];
    if role == ROLE_LIB and previous is not None {
        changes = api_changes(registry, previous, built.surface);
        verdict = check_bump(Version.parse(previous.version), version, changes);
        if verdict {
            suggestion = minimum_next(Version.parse(previous.version), changes);
            plan_problems.append(
                f"{verdict}; the smallest valid version is {suggestion}"
            );
        }
    }
    if run_check and not check_gate(config) {
        plan_problems.append("'jac check' reports errors in the package");
    }
    return PublishPlan(
        built=built,
        item=item,
        previous=previous,
        changes=changes,
        problems=plan_problems
    );
}

def report_plan(plan: PublishPlan) {
    e = plan.item;
    console.print(
        f"\n  {e.name} {e.version} ({e.role}), sha256 {e.sha256[:16]}, "
        f"{len(plan.built.data):,} bytes",
        style="bold"
    );
    if plan.previous is not None {
        console.print(f"  Compared with {plan.previous.version}:", style="muted");
        if not plan.changes {
            console.print("    no change to the exported API", style="muted");
        }
        for change in plan.changes {
            console.print(f"    {change.describe()}", style="muted");
        }
    }
    for problem in plan.problems {
        console.error(problem);
    }
}

def index_repo(registry: Registry) -> str {
    repo = str(registry.settings().get("repo", ""));
    if not repo or "/" not in repo {
        raise PublishError(
            f"registry '{registry.name}' does not name its GitHub repository in config.json"
        );
    }
    return repo;
}

def open_index_pull(
    registry: Registry,
    item: IndexEntry,
    data: bytes | None,
    title: str,
    body: str,
    surface: dict[str, any] | None = None
) -> str {
    import from jaclang.packages.github { GitHub }
    gh = GitHub.from_env();
    repo = index_repo(registry);
    login = gh.login();
    fork = gh.ensure_fork(repo, login);
    base_sha = gh.branch_sha(repo, "main");
    slug = item.name.replace("/", "-");
    branch = f"publish-{slug}-{item.version}"
        if data is not None
        else f"yank-{slug}-{item.version}";
    gh.create_branch(fork, branch, base_sha);
    rel = index_rel_path(item.name);
    (current, sha) = gh.read_file(fork, rel, branch);
    lines = [
        line
        for line in (current or "").splitlines()
        if line.strip()
    ];
    if data is not None {
        release = gh.release_for(fork, f"jac-{slug}-{item.version}", branch);
        item.upload = gh.upload_asset(release, f"{item.sha256}.jab", data);
        lines.append(item.to_line());
    } else {
        updated: list[str] = [];
        for line in lines {
            row = IndexEntry.from_json(json.loads(line));
            if row.version == item.version {
                row.yanked = True;
                line = row.to_line();
            }
            updated.append(line);
        }
        lines = updated;
    }
    gh.write_file(fork, rel, branch, "\n".join(lines) + "\n", title, sha);
    if surface {
        gh.write_file(
            fork,
            api_rel_path(item.name, item.version),
            branch,
            json.dumps(surface, sort_keys=True, indent=1) + "\n",
            title,
            None
        );
    }
    return gh.open_pull(repo, f"{login}:{branch}", "main", title, body);
}

def publish_project(
    config: JacConfig, dry_run: bool = False, registry_name: str = "", output: str = ""
) -> int {
    try {
        registry = registry_named(registry_name, config.registries);
        plan = plan_publish(config, registry);
    } except (PublishError, RegistryError) as e {
        console.error(str(e));
        return 1;
    }
    report_plan(plan);
    if output {
        out = Path(output);
        out.mkdir(parents=True, exist_ok=True);
        target = out / f"{plan.item.name.replace('/', '-')}-{plan.item.version}.jab";
        target.write_bytes(plan.built.data);
        console.print(f"  Wrote {target}", style="muted");
    }
    if plan.problems {
        return 1;
    }
    if dry_run {
        console.success("Dry run: every publish gate passed; nothing was uploaded.");
        return 0;
    }
    body = (
        f"Publishes `{plan.item.name}` {plan.item.version}.\n\n"
        f"- sha256: `{plan.item.sha256}`\n- source: {plan.item.source}\n"
    );
    if plan.changes {
        body += "\nAPI changes since "
            + (plan.previous.version if plan.previous else "")
            + ":\n";
        body += "\n".join([f"- {c.describe()}" for c in plan.changes]) + "\n";
    }
    try {
        url = open_index_pull(
            registry,
            plan.item,
            plan.built.data,
            f"publish {plan.item.name} {plan.item.version}",
            body,
            plan.built.surface
        );
    } except Exception as e {
        console.error(f"Publishing failed: {e}");
        return 1;
    }
    console.success(f"Opened {url}");
    console.print(
        "  The index CI checks the package again, stores it and merges; the "
        "version installs once the pull request is merged.",
        style="muted"
    );
    return 0;
}

def yank_version(config: JacConfig, version: str, registry_name: str = "") -> int {
    ident = package_identity(config);
    try {
        registry = registry_named(registry_name, config.registries);
        item = registry.find(ident.name, version);
    } except RegistryError as e {
        console.error(str(e));
        return 1;
    }
    if item is None {
        console.error(f"{ident.name} {version} is not in the index");
        return 1;
    }
    if item.yanked {
        console.info(f"{ident.name} {version} is already yanked");
        return 0;
    }
    try {
        url = open_index_pull(
            registry,
            item,
            None,
            f"yank {ident.name} {version}",
            f"Yanks `{ident.name}` {version}: new resolutions skip it; existing locks keep it."
        );
    } except Exception as e {
        console.error(f"Yanking failed: {e}");
        return 1;
    }
    console.success(f"Opened {url}");
    return 0;
}
