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
TOP_VOICES_DOC = "docs/community/top_voices.md"
AST_TOOL = AstTool()
EXAMPLE_SOURCE_FOLDER = "../jac/examples"
EXAMPLE_TARGET_FOLDER = "docs/assets/examples"


def pre_build_hook(**kwargs: dict) -> None:
    """Run pre-build tasks for preparing files.

    This function is called before the build process starts.
    """
    print("Running pre-build hook...")
    if os.path.exists(PLAYGROUND_ZIP_PATH):
        print(f"Removing existing zip file: {PLAYGROUND_ZIP_PATH}")
        os.remove(PLAYGROUND_ZIP_PATH)
    create_playground_zip()
    print("Jaclang zip file created successfully.")

    if is_file_older_than_minutes(UNIIR_NODE_DOC, 5):
        with open(UNIIR_NODE_DOC, "w") as f:
            f.write(AST_TOOL.autodoc_uninode())
    else:
        print(f"File is recent: {UNIIR_NODE_DOC}. Skipping creation.")

    with open(TOP_CONTRIBUTORS_DOC, "w") as f:
        f.write(get_top_contributors())

    # Generate voice data (requires gh CLI - skip if file is recent)
    # In CI/Docker context, if this was already generated, we can skip it
    if is_file_older_than_minutes(TOP_VOICES_DOC, 60):
        with open(TOP_VOICES_DOC, "w") as f:
            f.write(get_top_voices())
    else:
        print(f"File is recent: {TOP_VOICES_DOC}. Skipping generation.")


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
    """
    print("Creating final zip...")

    if not os.path.exists(TARGET_FOLDER):
        raise FileNotFoundError(f"Folder not found: {TARGET_FOLDER}")

    # Files/directories to exclude for faster zipping
    exclude_patterns = {
        ".pyi",  # Type stub files (4427 files!)
        ".pyc",  # Compiled Python
        "__pycache__",  # Cache directories
        ".git",
        ".pytest_cache",
        "tests",  # Test files may not be needed for playground
    }

    def should_exclude(path: str) -> bool:
        """Check if file/directory should be excluded."""
        return any(
            pattern in path or path.endswith(pattern) for pattern in exclude_patterns
        )

    files_added = 0
    with zipfile.ZipFile(PLAYGROUND_ZIP_PATH, "w", zipfile.ZIP_DEFLATED) as zipf:
        for root, dirs, files in os.walk(TARGET_FOLDER):
            # Remove excluded directories from traversal
            dirs[:] = [d for d in dirs if not should_exclude(os.path.join(root, d))]

            for file in files:
                file_path = os.path.join(root, file)
                if not should_exclude(file_path):
                    arcname = os.path.join(
                        ZIP_FOLDER_NAME, os.path.relpath(file_path, TARGET_FOLDER)
                    )
                    zipf.write(file_path, arcname)
                    files_added += 1

    print(f"Zip saved to: {PLAYGROUND_ZIP_PATH} ({files_added} files)")


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


def get_top_voices() -> str:
    """Get the top voices from GitHub discussions."""
    # Get the current directory (docs/scripts)
    current_dir = os.path.dirname(os.path.abspath(__file__))
    # Go to the root directory (two levels up from docs/scripts)
    root_dir = os.path.dirname(os.path.dirname(current_dir))
    cmd = ["jac", "run", "scripts/top_voices.jac"]
    try:
        return subprocess.check_output(
            cmd, cwd=root_dir, stderr=subprocess.DEVNULL
        ).decode("utf-8")
    except subprocess.CalledProcessError as e:
        print(f"Warning: Failed to get top voices: {e}")
        return "# Top Voices\n\nUnable to fetch discussion data at this time.\n"
    except Exception as e:
        print(f"Warning: Unexpected error getting top voices: {e}")
        return "# Top Voices\n\nUnable to fetch discussion data at this time.\n"


pre_build_hook()
