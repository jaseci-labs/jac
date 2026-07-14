"""Unified release script for the jaseci monorepo.

Bumps package versions, syncs internal dependencies, updates release notes,
and outputs metadata for the GitHub Actions workflow to create a release PR.

Usage:
    jac run scripts/release.jac --jaclang patch --jac-byllm minor
    jac run scripts/release.jac --jac-byllm patch --dry-run

Each package flag accepts: skip (default), patch, minor, major.
"""

import argparse;
import from pathlib { Path }
import tomlkit;
import from collect_release_notes { assemble_package }
import from release_utils { PACKAGES, bump_version, set_output }
"""Read the version string from a jac.toml file."""
def read_version(jac_toml_path: Path) -> str {
    data = tomlkit.loads(jac_toml_path.read_text());
    return str(data["project"]["version"]);
}

"""Update the version field in a jac.toml file."""
def update_jac_toml_version(jac_toml_path: Path, new_version: str) {
    data = tomlkit.loads(jac_toml_path.read_text());
    data["project"]["version"] = new_version;
    jac_toml_path.write_text(tomlkit.dumps(data));
}

"""Collect release note fragments and assemble into the release notes file.

    Reads fragments from docs/docs/community/release_notes/unreleased/<package>/,
    inserts a new (Latest Release) section, demotes the old one, and deletes
    the consumed fragment files.
    """
def update_release_notes(
    repo_root: Path, pkg_name: str, new_version: str, dry_run: bool = False
) {
    assemble_package(repo_root, pkg_name, new_version, dry_run=dry_run);
}

def parse_args -> argparse.Namespace {
    parser = argparse.ArgumentParser(
        description="Release packages in the jaseci monorepo"
    );
    bump_choices = ["skip", "patch", "minor", "major"];
    for pkg_name in PACKAGES {
        parser.add_argument(
            f"--{pkg_name}",
            choices=bump_choices,
            default="skip",
            help=f"Version bump type for {pkg_name} (default: skip)"
        );
    }
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print what would be done without modifying files"
    );
    return parser.parse_args();
}

def main -> None {
    args = parse_args();
    repo_root = Path(__file__).resolve().parent.parent;
    releases: list[dict] = [];
    for (pkg_name, pkg_info) in PACKAGES.items() {
        attr_name = pkg_name.replace("-", "_");
        bump_type = getattr(args, attr_name);
        if (bump_type != "skip") {
            releases.append(
                {
                    "name": pkg_name,
                    "bump": bump_type,
                    "dir": pkg_info.dir,
                    "jac_toml": f"{pkg_info.dir}/jac.toml",
                    "release_notes": pkg_info.release_notes,
                    "pypi_name": pkg_info.pypi,
                    "notes_display": pkg_info.notes_display
                }
            );
        }
    }
    if not releases {
        print("No packages selected for release (all set to 'skip').");
        return;
    }
    print("Packages to release:");
    for rel in releases {
        print(f"  - {rel['name']}: {rel['bump']}");
    }
    print();
    releasing_packages: set[str] = {rel["name"] for rel in releases};
    modified_files: list[str] = [];
    version_updates: list[tuple[(str, str, str)]] = [];
    for rel in releases {
        pkg_name = rel["name"];
        bump_type = rel["bump"];
        jac_toml_path = repo_root / rel["jac_toml"];
        current_version = read_version(jac_toml_path);
        new_version = bump_version(current_version, bump_type);
        version_updates.append((pkg_name, current_version, new_version));
        print(f"Package:  {pkg_name}");
        print(f"Current:  {current_version}");
        print(f"Bump:     {bump_type}");
        print(f"New:      {new_version}");
        print();
        if args.dry_run {
            if jac_toml_path.exists() {
                print(
                    f"[dry-run] Would update {rel['jac_toml']} -> version {new_version}"
                );
            }
            if rel["release_notes"] {
                print(f"[dry-run] Would collect fragments for {rel['name']}");
                update_release_notes(repo_root, rel["name"], new_version, dry_run=True);
            }
            print();
            continue;
        }
        print("Updating version...");
        if jac_toml_path.exists() {
            update_jac_toml_version(jac_toml_path, new_version);
            if (rel["jac_toml"] not in modified_files) {
                modified_files.append(rel["jac_toml"]);
            }
        }
        if rel["release_notes"] {
            print("Collecting release note fragments...");
            update_release_notes(repo_root, rel["name"], new_version);
            if (rel["release_notes"] not in modified_files) {
                modified_files.append(rel["release_notes"]);
            }
        }
        print();
    }
    if args.dry_run {
        return;
    }
    pkg_versions = [f"{name}-{new_ver}" for (name, _, new_ver) in version_updates];
    branch_name = "release/" + "_".join(pkg_versions);
    pr_title = (
        "release: " + ", ".join(
            f"{name} {new_ver}" for (name, _, new_ver) in version_updates
        )
    );
    pr_body = "## Release\n\n";
    for (name, old, new_ver) in version_updates {
        rel = next(
            r
            for r in releases
            if (r["name"] == name)
        );
        pr_body += f"### {name}\n";
        pr_body += f"- Version: {old} → {new_ver}\n";
        pr_body += f"- Bump type: {rel['bump']}\n\n";
    }
    pr_body += "- Updated release notes\n";
    set_output("branch_name", branch_name);
    set_output("pr_title", pr_title);
    set_output("pr_body", pr_body);
    set_output("modified_files", " ".join(modified_files));
    print(f"Done. Modified files: {', '.join(modified_files)}");
}

with entry:__main__ {
    main();
}
