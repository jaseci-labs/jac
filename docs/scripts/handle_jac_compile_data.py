"""Handle jac compile data for jaclang.org.

This script is used  to handle the jac compile data for jac playground.
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
    """Locate a jaclang SOURCE tree for the playground zip.

    The playground runs jaclang in-browser (Pyodide) to execute snippets, so it
    needs jaclang *source* (.jac + .py). A sealed `jac` binary (#7135) ships
    source-free, so prefer the in-repo source tree; the binary's built
    ``_precompiled/*.jir`` are overlaid separately (see ``_overlay_precompiled``)
    for the fast in-browser boot. Caller must NOT delete the returned directory.
    """
    repo_src = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", "..", "jac", "jaclang")
    )
    if os.path.isfile(os.path.join(repo_src, "__init__.py")):
        print(f"Using in-repo jaclang source at {repo_src}")
        return repo_src

    import jaclang

    jaclang_dir = os.path.dirname(os.path.abspath(jaclang.__file__))
    print(f"Using host jaclang at {jaclang_dir} (no in-repo source tree found)")
    return jaclang_dir


def _overlay_precompiled(zipf: "zipfile.ZipFile", already: set) -> int:
    """Add the sealed binary's ``jaclang/_precompiled/*.jir`` to the zip so the
    in-browser runtime boots from JIR instead of compiling jaclang from source.
    Source (from resolve_jaclang_dir) carries no .jir; the binary carries them.
    """
    try:
        import jaclang
    except Exception:
        return 0
    pc = os.path.join(
        os.path.dirname(os.path.abspath(jaclang.__file__)), "_precompiled"
    )
    if not os.path.isdir(pc):
        return 0
    added = 0
    for root, _dirs, files in os.walk(pc):
        for file in files:
            # Skip MANIFEST.json: with source present the playground runs jaclang
            # *unsealed* (source-primary, .jir as a validated cache) -- exactly
            # how it behaved before #7135. A manifest would flip it into sealed
            # source-free mode, which is the browser path that does not work.
            if file == "MANIFEST.json":
                continue
            src = os.path.join(root, file)
            arcname = os.path.join(
                ZIP_FOLDER_NAME, "_precompiled", os.path.relpath(src, pc)
            )
            if arcname in already:
                continue
            zipf.write(src, arcname)
            already.add(arcname)
            added += 1
    return added


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
    except Exception as e:
        print(f"Warning: Failed to build playground zip: {e}. Skipping playground zip.")

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

    written: set = set()
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
                    written.add(arcname)

        # Overlay the sealed binary's precompiled JIR (source tree has none).
        overlaid = _overlay_precompiled(zipf, written)
        print(f"  Overlaid {overlaid} precompiled .jir from the binary")

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
