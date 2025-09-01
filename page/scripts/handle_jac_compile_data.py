"""Handle jac compile data for jaclang.org documentation.

This script handles the generation of documentation for the Jac language.
"""

import os
import subprocess
import time
import zipfile

from jaclang.utils.lang_tools import AstTool

# Calculate absolute paths
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DOCS_DIR = os.path.join(os.path.dirname(SCRIPT_DIR), "docs")

UNIIR_NODE_DOC = os.path.join(DOCS_DIR, "internals", "uniir_node.md")
LANG_REF_DOC = os.path.join(DOCS_DIR, "learn", "jac_ref.md")
TOP_CONTRIBUTORS_DOC = os.path.join(DOCS_DIR, "communityhub", "top_contributors.md")
AST_TOOL = AstTool()
EXAMPLE_SOURCE_FOLDER = os.path.join(
    os.path.dirname(os.path.dirname(SCRIPT_DIR)), "jac", "examples"
)
EXAMPLE_TARGET_FOLDER = os.path.join(DOCS_DIR, "assets", "examples")

# Playground paths (for legacy support)
TARGET_FOLDER = os.path.join(
    os.path.dirname(os.path.dirname(SCRIPT_DIR)), "jac", "jaclang"
)
EXTRACTED_FOLDER = os.path.join(DOCS_DIR, "playground")
PLAYGROUND_ZIP_PATH = os.path.join(EXTRACTED_FOLDER, "jaclang.zip")
ZIP_FOLDER_NAME = "jaclang"


def ensure_directory_exists(file_path: str) -> None:
    """Create directory if it doesn't exist."""
    directory = os.path.dirname(file_path)
    if not os.path.exists(directory):
        os.makedirs(directory)


def pre_build_hook(**kwargs: dict) -> None:
    """Run pre-build tasks for preparing documentation files.

    This function is called before the build process starts.
    """
    print("Running pre-build hook...")

    # Create required directories
    ensure_directory_exists(UNIIR_NODE_DOC)
    ensure_directory_exists(LANG_REF_DOC)
    ensure_directory_exists(TOP_CONTRIBUTORS_DOC)
    ensure_directory_exists(PLAYGROUND_ZIP_PATH)  # For legacy support

    try:
        if is_file_older_than_minutes(UNIIR_NODE_DOC, 5):
            with open(UNIIR_NODE_DOC, "w") as f:
                f.write(AST_TOOL.autodoc_uninode())
        else:
            print(f"File is recent: {UNIIR_NODE_DOC}. Skipping creation.")

        if is_file_older_than_minutes(LANG_REF_DOC, 5):
            with open(LANG_REF_DOC, "w") as f:
                f.write(AST_TOOL.automate_ref())
        else:
            print(f"File is recent: {LANG_REF_DOC}. Skipping creation.")

        if is_file_older_than_minutes(TOP_CONTRIBUTORS_DOC, 5):
            with open(TOP_CONTRIBUTORS_DOC, "w") as f:
                # Add extra repos for tabbed view
                f.write(
                    get_top_contributors(
                        [
                            "jaseci-labs/jaseci",
                            "TrueSelph/jivas",
                            "jaseci-labs/jac_playground",
                        ]
                    )
                )
        else:
            print(f"File is recent: {TOP_CONTRIBUTORS_DOC}. Skipping creation.")
    except ImportError as e:
        print(f"Warning: Some documentation could not be generated: {e}")
        print("This is expected if jaclang is not installed.")


def is_file_older_than_minutes(file_path: str, minutes: int) -> bool:
    """Check if a file is older than the specified number of minutes."""
    if not os.path.exists(file_path):
        return True

    file_time = os.path.getmtime(file_path)
    current_time = time.time()
    time_diff_minutes = (current_time - file_time) / 60

    return time_diff_minutes > minutes


def create_playground_zip() -> None:
    """Create a zip file containing the jaclang folder.

    The zip file is created in the EXTRACTED_FOLDER directory.
    This function is kept for legacy support but may be deprecated.
    """
    print("Creating final zip...")

    try:
        if not os.path.exists(TARGET_FOLDER):
            raise FileNotFoundError(f"Folder not found: {TARGET_FOLDER}")

        with zipfile.ZipFile(PLAYGROUND_ZIP_PATH, "w", zipfile.ZIP_DEFLATED) as zipf:
            for root, _, files in os.walk(TARGET_FOLDER):
                for file in files:
                    file_path = os.path.join(root, file)
                    arcname = os.path.join(
                        ZIP_FOLDER_NAME, os.path.relpath(file_path, TARGET_FOLDER)
                    )
                    zipf.write(file_path, arcname)

        print("Zip saved to:", PLAYGROUND_ZIP_PATH)
    except FileNotFoundError:
        print(f"Warning: Could not create playground zip - {TARGET_FOLDER} not found")
    except Exception as e:
        print(f"Warning: Failed to create playground zip: {e}")


def get_top_contributors(repos: list[str] | None = None) -> str:
    """Get the top contributors for the jaclang repository and extra repos as HTML tabs."""
    try:
        # Get the current directory (docs/scripts)
        current_dir = os.path.dirname(os.path.abspath(__file__))
        # Go to the root directory (two levels up from docs/scripts)
        root_dir = os.path.dirname(os.path.dirname(current_dir))
        cmd = ["python3", "scripts/top_contributors.py"]
        if repos:
            cmd += ["--repo", repos[0], "--extra-repos"] + repos[1:]
        return subprocess.check_output(cmd, cwd=root_dir).decode("utf-8")
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        print(f"Warning: Could not generate top contributors: {e}")
        return "# Top Contributors\n\nContributor information temporarily unavailable."


if __name__ == "__main__":
    pre_build_hook()
