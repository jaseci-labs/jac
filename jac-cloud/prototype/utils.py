"""File covering beanstalk implementation."""

import os
import zipfile


def zip_project(source_dir: str) -> str:
    """Temperary doc string."""
    output_filename = "aws_beanstalk.zip"
    with zipfile.ZipFile(output_filename, "w", zipfile.ZIP_DEFLATED) as zf:
        for root, _, files in os.walk(source_dir):
            for file in files:
                # Skip certain files
                if file in [
                    output_filename,
                    "__pycache__",
                    ".git",
                    ".env",
                    ".DS_Store",
                ]:
                    continue
                if file.endswith(".pyc") or file.startswith("."):
                    continue

                filepath = os.path.join(root, file)
                arcname = os.path.relpath(filepath, source_dir)
                zf.write(filepath, arcname)
                # print(f" Added: {arcname}")
    print(f"Project zipped as {output_filename}")
    return output_filename
