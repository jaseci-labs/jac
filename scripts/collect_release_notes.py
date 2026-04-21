"""Collect release note fragments and assemble them into release notes files.

Reads fragment files from docs/docs/community/release_notes/unreleased/<package>/
Fragment files follow the flat naming convention: <PR#>.<category>.md
(e.g. 1234.bugfix.md, 5678.feature.md)

Usage:
    Called by release.py during the release process.
    Can also be run standalone for testing:
        python scripts/collect_release_notes.py --package jaclang --version 0.13.6 --dry-run
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

from release_utils import PACKAGES

UNRELEASED_DIR = Path("docs/docs/community/release_notes/unreleased")


def collect_fragments(package_dir: Path) -> dict[str, list[str]]:
    """Read all fragment files from a package's unreleased directory.

    Fragments follow the flat naming convention: <PR#>.<category>.md
    Returns a dict mapping category name to list of entry strings.
    """
    categories: dict[str, list[str]] = {
        "feature": [],
        "bugfix": [],
        "breaking": [],
        "refactor": [],
        "docs": [],
    }
    for fragment in sorted(package_dir.glob("*.md")):
        if fragment.name == "README.md":
            continue
        parts = fragment.stem.split(".")
        if len(parts) != 2 or parts[1] not in categories:
            continue
        category = parts[1]
        content = fragment.read_text(encoding="utf-8").strip()
        if content:
            categories[category].append(content)
    # Remove empty categories
    return {k: v for k, v in categories.items() if v}


def build_section(
    display_name: str, version: str, categories: dict[str, list[str]]
) -> str:
    """Build the markdown section for a new release version."""
    lines = [f"## {display_name} {version} (Latest Release)", ""]

    category_headings = {
        "breaking": "### Breaking Changes",
        "feature": "### New Features",
        "bugfix": "### Bug Fixes",
        "refactor": "### Refactors",
        "docs": "### Documentation",
    }

    for cat_key in ("breaking", "feature", "bugfix", "refactor", "docs"):
        entries = categories.get(cat_key, [])
        if not entries:
            continue
        lines.append(category_headings[cat_key])
        lines.append("")
        for entry in entries:
            lines.append(entry)
        lines.append("")

    return "\n".join(lines)


def inject_section(
    release_notes_path: Path, display_name: str, new_section: str
) -> None:
    """Insert the new version section into the release notes file.

    Demotes the existing (Latest Release) tag and inserts the new section
    right after the file header (title + description paragraph).
    """
    content = release_notes_path.read_text(encoding="utf-8")

    # Demote old (Latest Release)
    content = content.replace(" (Latest Release)", "")

    # Find the first ## header and insert new section before it
    match = re.search(r"^## ", content, re.MULTILINE)
    if match:
        insert_pos = match.start()
        content = content[:insert_pos] + new_section + "\n" + content[insert_pos:]
    else:
        # No existing versions - append after header
        content = content.rstrip() + "\n\n" + new_section + "\n"

    release_notes_path.write_text(content, encoding="utf-8")


def delete_fragments(package_dir: Path) -> list[str]:
    """Delete all fragment files (but keep README.md)."""
    deleted = []
    for fragment in package_dir.glob("*.md"):
        if fragment.name == "README.md":
            continue
        fragment.unlink()
        deleted.append(str(fragment))
    return deleted


def assemble_package(
    repo_root: Path,
    pkg_key: str,
    version: str,
    dry_run: bool = False,
) -> bool:
    """Assemble fragments for a single package into its release notes file.

    Returns True if fragments were found and assembled, False if no fragments.
    """
    pkg_info = PACKAGES[pkg_key]
    if not pkg_info.release_notes:
        return False

    package_dir = repo_root / UNRELEASED_DIR / pkg_info.notes_display
    if not package_dir.is_dir():
        print(f"  No unreleased directory for {pkg_key}")
        return False

    categories = collect_fragments(package_dir)
    if not categories:
        print(f"  No fragments found for {pkg_key}")
        return False

    total = sum(len(v) for v in categories.values())
    print(f"  Found {total} fragment(s) for {pkg_key}")

    section = build_section(pkg_info.notes_display, version, categories)

    if dry_run:
        print(f"  [dry-run] Would insert into {pkg_info.release_notes}:")
        print(section)
        return True

    release_notes_path = repo_root / pkg_info.release_notes
    inject_section(release_notes_path, pkg_info.notes_display, section)
    print(f"  Inserted into {pkg_info.release_notes}")

    deleted = delete_fragments(package_dir)
    print(f"  Deleted {len(deleted)} fragment file(s)")

    return True


def main() -> None:
    """Standalone entry point for testing."""
    parser = argparse.ArgumentParser(description="Collect release note fragments")
    parser.add_argument("--package", required=True, help="Package key (e.g., jaclang)")
    parser.add_argument(
        "--version", required=True, help="Version string (e.g., 0.13.6)"
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="Print without modifying"
    )
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    assemble_package(repo_root, args.package, args.version, args.dry_run)


if __name__ == "__main__":
    main()
