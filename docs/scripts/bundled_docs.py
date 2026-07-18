"""Mount the jaclang-bundled documentation corpus into the mkdocs build.

The reference/, quick-guide/, tutorials/, and internals/ sections (plus
community/breaking-changes.md and community/codebase-guide.md) live in
jac/jaclang/cli/docs/ -- the same files `jac guide` serves offline -- so the
package ships them without a generated mirror. This hook mounts every one of
them into the site at its usual path, which keeps the nav, redirects, and
relative links working unchanged and guarantees the site and the CLI can
never drift.

The site's edit_uri points at docs/docs; on_pre_page rewrites the "edit this
page" link for mounted pages to their real location in the package tree.
"""

from pathlib import Path

from mkdocs.config.defaults import MkDocsConfig
from mkdocs.exceptions import PluginError
from mkdocs.plugins import event_priority
from mkdocs.structure.files import File, Files
from mkdocs.structure.pages import Page

REPO_ROOT = Path(__file__).resolve().parents[2]
BUNDLED_ROOT = REPO_ROOT / "jac" / "jaclang" / "cli" / "docs"
# A wildly low file count means the corpus moved or the checkout is partial;
# fail the build rather than publish a site with half its pages missing.
MIN_EXPECTED_DOCS = 50


# Hooks run after plugins within an event; the elevated priority mounts the
# corpus before the redirects plugin validates its targets against the file
# collection.
@event_priority(100)
def on_files(files: Files, config: MkDocsConfig) -> Files:
    """Add every bundled doc to the build at its site-relative path."""
    if not BUNDLED_ROOT.is_dir():
        raise PluginError(f"bundled docs corpus missing: {BUNDLED_ROOT}")
    taken = {f.src_uri for f in files}
    mounted = 0
    for path in sorted(BUNDLED_ROOT.rglob("*.md")):
        src_uri = path.relative_to(BUNDLED_ROOT).as_posix()
        if src_uri in taken:
            raise PluginError(
                f"{src_uri} exists in both docs/docs and {BUNDLED_ROOT}; "
                "the bundled corpus is canonical -- delete the docs/docs copy"
            )
        files.append(
            File(
                src_uri,
                str(BUNDLED_ROOT),
                config["site_dir"],
                config["use_directory_urls"],
            )
        )
        mounted += 1
    if mounted < MIN_EXPECTED_DOCS:
        raise PluginError(
            f"only {mounted} bundled docs found under {BUNDLED_ROOT}; "
            "the corpus looks broken"
        )
    return files


def on_pre_page(page: Page, config: MkDocsConfig, files: Files) -> Page:
    """Point 'edit this page' at the bundled file's real repo path."""
    abs_src = page.file.abs_src_path
    if abs_src is None:
        return page
    try:
        rel = Path(abs_src).resolve().relative_to(BUNDLED_ROOT)
    except ValueError:
        return page
    repo_rel = f"jac/jaclang/cli/docs/{rel.as_posix()}"
    page.edit_url = f"{config['repo_url'].rstrip('/')}/edit/main/{repo_rel}"
    return page
