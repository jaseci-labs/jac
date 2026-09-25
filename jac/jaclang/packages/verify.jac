import json;
import os;
import shutil;
import subprocess;
import tempfile;
import tomllib;
import from pathlib { Path }
import from urllib.parse { urlsplit }
import from jaclang.cli.console { console }
import from jaclang.dist.archive { extract_tar_gz }
import from jaclang.packages.apidiff { check_bump, diff_surfaces }
import from jaclang.packages.artifact { API_FILE, MANIFEST_DIR, read_package_manifest }
import from jaclang.packages.index {
    API_DIR,
    IndexEntry,
    Registry,
    RegistryError,
    api_rel_path,
    fetch_verified,
    parse_index_lines
}
import from jaclang.packages.publish { previous_release, previous_surface }
import from jaclang.packages.semver { SemverError, Version }
import from jaclang.project.package_scope { is_package_name }

glob ORGS_DIR: str = "orgs",
     INDEX_DIR: str = "index",
     RESERVED_FILE: str = "reserved.txt",
     UPLOAD_HOSTS: tuple[str, ...] = ("github.com", "objects.githubusercontent.com");

obj VerifyReport {
    has problems: list[str] = [],
        mirror: list[dict[str, str]] = [],
        checked: list[str] = [],
        api_files: set[str] = set(),
        any_upload: bool = False;
}

def _git(base_root: Path, args: list[str]) -> str {
    done = subprocess.run(
        ["git", *args], cwd=str(base_root), capture_output=True, text=True, check=False
    );
    if done.returncode != 0 {
        raise RuntimeError(f"git {' '.join(args)}: {done.stderr.strip()}");
    }
    return done.stdout;
}

def _at_base(base_root: Path, base: str, rel: str) -> str | None {
    if not base {
        return None;
    }
    done = subprocess.run(
        ["git", "show", f"{base}:{rel}"],
        cwd=str(base_root),
        capture_output=True,
        text=True,
        check=False
    );
    return done.stdout if done.returncode == 0 else None;
}

def _owners(text: str | None) -> list[str] {
    if not text {
        return [];
    }
    try {
        data = tomllib.loads(text);
    } except tomllib.TOMLDecodeError {
        return [];
    }
    return [str(o).lower() for o in data.get("owners", [])];
}

def _reserved(base_root: Path) -> set[str] {
    path = base_root / RESERVED_FILE;
    if not path.is_file() {
        return set();
    }
    return {
        line.strip()
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.startswith("#")
    };
}

def _changed_files(base_root: Path, base: str) -> list[str] {
    if not base {
        return sorted(
            [
                str(p.relative_to(base_root)).replace(os.sep, "/")
                for p in base_root.rglob("*")
                if p.is_file() and ".git" not in p.parts
            ]
        );
    }
    out = _git(base_root, ["diff", "--name-only", f"{base}...HEAD"]);
    return sorted(
        [
            line.strip()
            for line in out.splitlines()
            if line.strip()
        ]
    );
}

def _check_org(
    base_root: Path, base: str, rel: str, author: str, outcome: VerifyReport
) {
    org = Path(rel).stem;
    before = _at_base(base_root, base, rel);
    after_path = base_root / rel;
    if not after_path.is_file() {
        outcome.problems.append(f"{rel}: an org cannot be deleted in a pull request");
        return;
    }
    after = after_path.read_text(encoding="utf-8");
    if before is None {
        if not is_package_name(f"{org}/x") {
            outcome.problems.append(f"{rel}: '{org}' is not a valid org name");
        }
        if org in _reserved(base_root) {
            outcome.problems.append(f"{rel}: the org '{org}' is reserved");
        }
        if author.lower() not in _owners(after) {
            outcome.problems.append(
                f"{rel}: a new org must list its author ({author}) as an owner"
            );
        }
        return;
    }
    if author.lower() not in _owners(before) {
        outcome.problems.append(
            f"{rel}: only an existing owner of '{org}' may change it"
        );
    }
}

def _verify_entry(
    base_root: Path,
    registry: Registry,
    item: IndexEntry,
    history: list[IndexEntry],
    outcome: VerifyReport
) {
    label = f"{item.name} {item.version}";
    try {
        version = Version.parse(item.version);
    } except SemverError as e {
        outcome.problems.append(f"{label}: {e}");
        return;
    }
    upload = urlsplit(item.upload);
    if not outcome.any_upload
        and (upload.scheme != "https" or upload.hostname not in UPLOAD_HOSTS) {
        outcome.problems.append(
            f"{label}: 'upload' must be a GitHub release asset URL"
        );
        return;
    }
    try {
        data = fetch_verified(item.upload, item.sha256, label);
    } except Exception as e {
        outcome.problems.append(f"{label}: {e}");
        return;
    }
    stage = Path(tempfile.mkdtemp(prefix="jac-verify-"));
    try {
        extract_tar_gz(data, stage);
        manifest = read_package_manifest(stage) or {};
        for (key, expected) in (
            ("name", item.name),
            ("version", item.version),
            ("role", item.role),
            ("description", item.description)
        ) {
            if manifest.get(key) != expected {
                outcome.problems.append(
                    f"{label}: the artifact's manifest says {key}={manifest.get(
                        key
                    )!r}, "
                    f"the index line says {expected!r}"
                );
            }
        }
        if item.role == "lib" {
            if dict(manifest.get("deps", {})) != item.deps {
                outcome.problems.append(
                    f"{label}: the index line's deps differ from the artifact's"
                );
            }
            if manifest.get("api_digest") != item.api_digest {
                outcome.problems.append(
                    f"{label}: the index line's api_digest differs from the artifact's"
                );
            }
            _check_api_file(base_root, stage, item, outcome);
            _verify_library(stage, registry, item, version, history, outcome);
        }
    } finally {
        shutil.rmtree(stage, ignore_errors=True);
    }
    outcome.mirror.append({"sha256": item.sha256, "upload": item.upload});
    outcome.checked.append(label);
}

def _check_api_file(
    base_root: Path, stage: Path, item: IndexEntry, outcome: VerifyReport
) {
    label = f"{item.name} {item.version}";
    rel = api_rel_path(item.name, item.version);
    outcome.api_files.add(rel);
    published = base_root / rel;
    shipped = stage / MANIFEST_DIR / API_FILE;
    if not published.is_file() {
        outcome.problems.append(f"{label}: the pull request must add {rel}");
        return;
    }
    if not shipped.is_file() {
        outcome.problems.append(f"{label}: the artifact carries no {API_FILE}");
        return;
    }
    try {
        same = json.loads(published.read_text(encoding="utf-8"))
            == json.loads(shipped.read_text(encoding="utf-8"));
    } except ValueError as e {
        outcome.problems.append(f"{label}: {rel} is not valid JSON: {e}");
        return;
    }
    if not same {
        outcome.problems.append(
            f"{label}: {rel} differs from the artifact's {API_FILE}"
        );
    }
}

def _verify_library(
    tree: Path,
    registry: Registry,
    item: IndexEntry,
    version: Version,
    history: list[IndexEntry],
    outcome: VerifyReport
) {
    import from jaclang.packages.api { package_surface, surface_digest }
    import from jaclang.packages.install { InstallError, sync }
    import from jaclang.project.config { JacConfig }
    label = f"{item.name} {item.version}";
    config = JacConfig.load(tree / "jac.toml");
    try {
        if config.dependencies {
            sync(config);
        }
        surface = package_surface(tree, item.exports);
    } except (InstallError, Exception) as e {
        outcome.problems.append(f"{label}: the package does not build: {e}");
        return;
    }
    if surface_digest(surface) != item.api_digest {
        outcome.problems.append(
            f"{label}: the exported API rebuilt from source does not match the published api_digest"
        );
    }
    previous = previous_release(history, version);
    if previous is None {
        return;
    }
    try {
        old = previous_surface(registry, previous);
    } except (RegistryError, ValueError) as e {
        outcome.problems.append(
            f"{label}: cannot read {previous.version} for the semver check: {e}"
        );
        return;
    }
    if old is None {
        return;
    }
    verdict = check_bump(
        Version.parse(previous.version), version, diff_surfaces(old, surface)
    );
    if verdict {
        outcome.problems.append(f"{label}: {verdict}");
    }
}

def _check_index_file(
    base_root: Path,
    base: str,
    rel: str,
    author: str,
    registry: Registry,
    outcome: VerifyReport
) {
    name = rel[len(INDEX_DIR) + 1:-len(".json")];
    if not is_package_name(name) {
        outcome.problems.append(f"{rel}: '{name}' is not a package name");
        return;
    }
    org = name.split("/")[0];
    owners = _owners(_at_base(base_root, base, f"{ORGS_DIR}/{org}.toml"))
        or _owners(
            (base_root / ORGS_DIR / f"{org}.toml").read_text(encoding="utf-8")
                if (base_root / ORGS_DIR / f"{org}.toml").is_file()
                else None
        );
    if author.lower() not in owners {
        outcome.problems.append(f"{rel}: {author} is not an owner of the org '{org}'");
        return;
    }
    before = parse_index_lines(_at_base(base_root, base, rel) or "");
    current_path = base_root / rel;
    after = parse_index_lines(
        current_path.read_text(encoding="utf-8") if current_path.is_file() else ""
    );
    old_by_version = {e.version: e for e in before};
    seen: set[str] = set();
    for e in after {
        if e.name != name {
            outcome.problems.append(f"{rel}: a line names '{e.name}'");
        }
        if e.version in seen {
            outcome.problems.append(f"{rel}: {e.version} is listed twice");
        }
        seen.add(e.version);
    }
    for (v, old) in old_by_version.items() {
        now = [
            e
            for e in after
            if e.version == v
        ];
        if not now {
            outcome.problems.append(
                f"{rel}: {v} was removed; published versions are never deleted"
            );
            continue;
        }
        expected = old.to_json();
        got = now[0].to_json();
        expected.pop("yanked", None);
        yanked = bool(got.pop("yanked", False));
        if expected != got or (old.yanked and not yanked) {
            outcome.problems.append(
                f"{rel}: {v} was edited; a published line may only change from unyanked to yanked"
            );
        }
    }
    for e in after {
        if e.version not in old_by_version {
            _verify_entry(base_root, registry, e, before, outcome);
        }
    }
}

def verify_index(
    base_root: Path, base: str, author: str, any_upload: bool = False
) -> VerifyReport {
    outcome = VerifyReport(any_upload=any_upload);
    registry = Registry(name="index", url=str(base_root));
    api_changed: list[str] = [];
    for rel in _changed_files(base_root, base) {
        if rel.startswith(f"{ORGS_DIR}/") and rel.endswith(".toml") {
            _check_org(base_root, base, rel, author, outcome);
        } elif rel.startswith(f"{INDEX_DIR}/") and rel.endswith(".json") {
            _check_index_file(base_root, base, rel, author, registry, outcome);
        } elif rel.startswith(f"{API_DIR}/") and rel.endswith(".json") {
            api_changed.append(rel);
        } else {
            outcome.problems.append(
                f"{rel}: a publish pull request may only change index/, api/ and orgs/"
            );
        }
    }
    for rel in api_changed {
        if _at_base(base_root, base, rel) is not None {
            outcome.problems.append(f"{rel}: a published API file never changes");
        } elif rel not in outcome.api_files {
            outcome.problems.append(
                f"{rel}: no library version published in this pull request owns it"
            );
        }
    }
    return outcome;
}

def run_verify(index_dir: str, base: str, author: str, mirror_out: str = "") -> int {
    base_root = Path(index_dir).resolve();
    if not (base_root / "config.json").is_file() {
        console.error(f"{base_root} is not a package index (no config.json)");
        return 1;
    }
    if not author {
        console.error("--author names the GitHub user who opened the pull request");
        return 1;
    }
    previous = os.environ.get("JAC_REGISTRY");
    os.environ["JAC_REGISTRY"] = str(base_root);
    try {
        outcome = verify_index(base_root, base, author);
    } finally {
        if previous is None {
            os.environ.pop("JAC_REGISTRY", None);
        } else {
            os.environ["JAC_REGISTRY"] = previous;
        }
    }
    for label in outcome.checked {
        console.print(f"  ✔ {label}", style="success");
    }
    for problem in outcome.problems {
        console.error(problem);
    }
    if mirror_out {
        Path(mirror_out).write_text(
            json.dumps(outcome.mirror, indent=1) + "\n", encoding="utf-8"
        );
    }
    if outcome.problems {
        return 1;
    }
    console.success("The index change is valid.");
    return 0;
}
