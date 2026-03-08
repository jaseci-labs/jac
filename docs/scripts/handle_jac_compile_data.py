"""Handle jac compile data for jaclang.org.

This script is used to handle the jac compile data for jac playground.
"""

import os
import subprocess
import time
import zipfile

from jaclang.utils.lang_tools import AstTool

TARGET_FOLDER = "../jac/jaclang"
EXTRACTED_FOLDER = "docs/playground"
PLAYGROUND_ZIP_PATH = os.path.join(EXTRACTED_FOLDER, "jaclang.zip")
ZIP_FOLDER_NAME = "jaclang"
UNIIR_NODE_DOC = "docs/community/internals/uniir_node.md"
TOP_CONTRIBUTORS_DOC = "docs/community/top_contributors.md"
AST_TOOL = AstTool()
EXAMPLE_SOURCE_FOLDER = "../jac/examples"
EXAMPLE_TARGET_FOLDER = "docs/assets/examples"

# Directory basenames to exclude
EXCLUDE_DIRS = {"__pycache__", ".pytest_cache", ".git", "tests"}
EXCLUDE_EXTS = {".pyc", ".pyo", ".pyi"}


def precompile_jaclang() -> None:
    """Run the jaclang precompilation script to generate .jir bytecode.

    Precompiles the entire jaclang source, same as PyPI release builds.
    """
    jac_root = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", "..", "jac")
    )
    script_path = os.path.join(jac_root, "scripts", "precompile_bytecode.jac")

    if not os.path.exists(script_path):
        print(f"Warning: Precompile script not found at {script_path}. Skipping.")
        return

    print("Precompiling jaclang bytecode for playground...")
    try:
        subprocess.run(
            ["jac", "run", "scripts/precompile_bytecode.jac", "."],
            check=True,
            cwd=jac_root,
        )
        print("Precompilation complete.")
    except subprocess.CalledProcessError as e:
        print(
            f"Warning: Precompilation failed: {e}. Playground will use on-the-fly compilation."
        )
    except FileNotFoundError:
        print("Warning: 'jac' command not found. Skipping precompilation.")


def pre_build_hook(**kwargs: dict) -> None:
    """Run pre-build tasks for preparing files.

    This function is called before the build process starts.
    """
    print("Running pre-build hook...")
    if os.path.exists(PLAYGROUND_ZIP_PATH):
        print(f"Removing existing zip file: {PLAYGROUND_ZIP_PATH}")
        os.remove(PLAYGROUND_ZIP_PATH)
    precompile_jaclang()
    create_playground_zip()
    print("Jaclang zip file created successfully.")

    if is_file_older_than_minutes(UNIIR_NODE_DOC, 5):
        with open(UNIIR_NODE_DOC, "w") as f:
            f.write(AST_TOOL.autodoc_uninode())
    else:
        print(f"File is recent: {UNIIR_NODE_DOC}. Skipping creation.")

    with open(TOP_CONTRIBUTORS_DOC, "w") as f:
        f.write(get_top_contributors())


def is_file_older_than_minutes(file_path: str, minutes: int) -> bool:
    """Check if a file is older than the specified number of minutes."""
    if not os.path.exists(file_path):
        return True

    file_time = os.path.getmtime(file_path)
    current_time = time.time()
    time_diff_minutes = (current_time - file_time) / 60

    return time_diff_minutes > minutes


def should_exclude(path: str) -> bool:
    """Check if file/directory should be excluded."""
    if os.path.basename(path) in EXCLUDE_DIRS:
        return True
    return os.path.splitext(path)[1] in EXCLUDE_EXTS


def create_playground_zip() -> None:
    """Create a zip from the jaclang source with precompiled .jir files.

    Uses the source repo at ../jac/jaclang, which should be precompiled
    before calling this function.
    """
    jaclang_dir = os.path.abspath(TARGET_FOLDER)
    print(f"Creating zip from source at: {jaclang_dir}")

    if not os.path.exists(jaclang_dir):
        raise FileNotFoundError(f"Folder not found: {jaclang_dir}")

    os.makedirs(EXTRACTED_FOLDER, exist_ok=True)

    files_added = 0
    with zipfile.ZipFile(PLAYGROUND_ZIP_PATH, "w", zipfile.ZIP_DEFLATED) as zipf:
        for root, dirs, files in os.walk(jaclang_dir):
            dirs[:] = [d for d in dirs if not should_exclude(os.path.join(root, d))]

            for file in files:
                file_path = os.path.join(root, file)
                if not should_exclude(file_path):
                    arcname = os.path.join(
                        ZIP_FOLDER_NAME, os.path.relpath(file_path, jaclang_dir)
                    )
                    zipf.write(file_path, arcname)
                    files_added += 1

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


def get_top_contributors() -> str:
    """Get the top contributors for the current repository."""
    # Get the current directory (docs/scripts)
    current_dir = os.path.dirname(os.path.abspath(__file__))
    # Go to the root directory (two levels up from docs/scripts)
    root_dir = os.path.dirname(os.path.dirname(current_dir))
    cmd = ["jac", "run", "scripts/top_contributors.jac"]
    try:
        return subprocess.check_output(cmd, cwd=root_dir).decode("utf-8")
    except subprocess.CalledProcessError as e:
        print(f"Warning: Failed to get top contributors: {e}")
        return "# Top Contributors\n\nUnable to fetch contributor data at this time.\n"
    except Exception as e:
        print(f"Warning: Unexpected error getting top contributors: {e}")
        return "# Top Contributors\n\nUnable to fetch contributor data at this time.\n"


pre_build_hook()
