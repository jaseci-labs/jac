"""Handle jac compile data for docs.jaseci.org.

This script is used to handle the jac compile data for the in-docs playground.
"""

import os
import time
import zipfile

from jaclang.utils.lang_tools import AstTool

EXTRACTED_FOLDER = "docs/playground"
PLAYGROUND_ZIP_PATH = os.path.join(EXTRACTED_FOLDER, "jaclang.zip")
ZIP_FOLDER_NAME = "jaclang"
UNIIR_NODE_DOC = "docs/internals/uniir_node.md"
AST_TOOL = AstTool()
# Directory basenames to exclude
EXCLUDE_DIRS = {"__pycache__", ".pytest_cache", ".git", "tests"}
EXCLUDE_EXTS = {".pyc", ".pyo", ".pyi"}
# Subdirectory paths within jaclang to exclude entirely
EXCLUDE_SUBDIRS = {
    os.path.join("compiler", "passes", "native"),
    os.path.join("vendor", "typeshed"),
}


def resolve_jaclang_dir() -> str:
    """Locate the host jaclang package directory for the playground zip.

    jaclang is no longer published to PyPI -- it ships inside the self-contained
    `jac` binary, whose bundled copy already carries the pre-compiled .jir files
    the playground needs. Use that installed package directly instead of
    `pip install --target`. Caller must NOT delete the returned directory.
    """
    import jaclang

    jaclang_dir = os.path.dirname(os.path.abspath(jaclang.__file__))
    jir_count = sum(
        1 for _, _, files in os.walk(jaclang_dir) for f in files if f.endswith(".jir")
    )
    print(f"Using host jaclang at {jaclang_dir} ({jir_count} pre-compiled .jir files)")
    return jaclang_dir


def pre_build_hook(**kwargs: dict) -> None:
    """Run pre-build tasks for preparing files.

    This function is called before the build process starts.
    """
    print("Running pre-build hook...")
    if os.path.exists(PLAYGROUND_ZIP_PATH):
        print(f"Removing existing zip file: {PLAYGROUND_ZIP_PATH}")
        os.remove(PLAYGROUND_ZIP_PATH)

    try:
        # The host jaclang package (do not delete it -- it belongs to the binary).
        jaclang_dir = resolve_jaclang_dir()
        create_playground_zip(jaclang_dir)
        print("Jaclang zip file created successfully.")
    except Exception:
        # Non-fatal (docs build without a playground beats no docs), but loud:
        # the full traceback is the only diagnostic a CI log will have.
        import traceback

        traceback.print_exc()
        print(
            "Warning: failed to build playground zip; docs will ship WITHOUT a playground."
        )

    if is_file_older_than_minutes(UNIIR_NODE_DOC, 5):
        with open(UNIIR_NODE_DOC, "w") as f:
            f.write(AST_TOOL.autodoc_uninode())
    else:
        print(f"File is recent: {UNIIR_NODE_DOC}. Skipping creation.")


def is_file_older_than_minutes(file_path: str, minutes: int) -> bool:
    """Check if a file is older than the specified number of minutes."""
    if not os.path.exists(file_path):
        return True

    file_time = os.path.getmtime(file_path)
    current_time = time.time()
    time_diff_minutes = (current_time - file_time) / 60

    return time_diff_minutes > minutes


def should_exclude(path: str, jaclang_dir: str) -> bool:
    """Check if file/directory should be excluded."""
    if os.path.basename(path) in EXCLUDE_DIRS:
        return True
    # Drop the sealed-image manifest: it ships alongside the .jir, but the
    # in-browser playground runs jaclang UNSEALED (source-primary, .jir as a
    # validated cache). A manifest would flip it into sealed source-free loading,
    # which the Pyodide runtime does not support -- so the .jac source stays the
    # source of truth in the browser (#7135).
    if os.path.basename(path) == "MANIFEST.json":
        return True
    if os.path.splitext(path)[1] in EXCLUDE_EXTS:
        return True
    rel = os.path.relpath(path, jaclang_dir)
    return any(rel == ex or rel.startswith(ex + os.sep) for ex in EXCLUDE_SUBDIRS)


def create_playground_zip(jaclang_dir: str) -> None:
    """Create a zip from the jaclang directory with pre-compiled .jir files."""
    print(f"Creating zip from: {jaclang_dir}")

    if not os.path.exists(jaclang_dir):
        raise FileNotFoundError(f"Folder not found: {jaclang_dir}")

    os.makedirs(EXTRACTED_FOLDER, exist_ok=True)

    with zipfile.ZipFile(PLAYGROUND_ZIP_PATH, "w", zipfile.ZIP_DEFLATED) as zipf:
        for root, dirs, files in os.walk(jaclang_dir):
            dirs[:] = [
                d
                for d in dirs
                if not should_exclude(os.path.join(root, d), jaclang_dir)
            ]

            for file in files:
                file_path = os.path.join(root, file)
                if not should_exclude(file_path, jaclang_dir):
                    arcname = os.path.join(
                        ZIP_FOLDER_NAME, os.path.relpath(file_path, jaclang_dir)
                    )
                    zipf.write(file_path, arcname)

    # Verify and report
    with zipfile.ZipFile(PLAYGROUND_ZIP_PATH, "r") as zf:
        names = zf.namelist()
        native = [n for n in names if "/passes/native/" in n]
        typeshed = [n for n in names if "/typeshed/" in n]
        pyi_files = [n for n in names if n.endswith(".pyi")]
        jir_files = [n for n in names if n.endswith(".jir")]

        if native or typeshed or pyi_files:
            issues = []
            if native:
                issues.append(f"{len(native)} native codegen files")
            if typeshed:
                issues.append(f"{len(typeshed)} typeshed files")
            if pyi_files:
                issues.append(f"{len(pyi_files)} .pyi stub files")
            print(f"  WARNING: Zip contains unnecessary files: {', '.join(issues)}")
        else:
            print("  Verified: zip is clean (no native/typeshed/pyi files)")

        zip_size = os.path.getsize(PLAYGROUND_ZIP_PATH) / 1024 / 1024
        print(f"  Precompiled .jir files: {len(jir_files)}")
        print(f"  Total files: {len(names)}, Size: {zip_size:.1f} MB")


pre_build_hook()
