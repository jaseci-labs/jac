"""Unit tests for validating Markdown documentation files."""

import os

import pytest
import yaml


# -----------------------------------------------------------------
# Utility Functions
# -----------------------------------------------------------------
def get_md_files():
    """Retrieve all Markdown files in the docs directory."""
    docs_dir = os.path.join(os.path.dirname(__file__), "../docs")
    md_files = []
    for root, _, files in os.walk(docs_dir):
        for file in files:
            if file.endswith(".md"):
                md_files.append(os.path.join(root, file))
    return md_files


def extract_md_files_from_nav(nav_item, base_path=""):
    """Recursively extract markdown file paths from mkdocs nav structure."""
    md_files = []
    if isinstance(nav_item, dict):
        for key, value in nav_item.items():
            if isinstance(value, str) and value.endswith(".md"):
                md_files.append(value)
            elif isinstance(value, (list, dict)):
                md_files.extend(extract_md_files_from_nav(value, base_path))
    elif isinstance(nav_item, list):
        for item in nav_item:
            md_files.extend(extract_md_files_from_nav(item, base_path))
    elif isinstance(nav_item, str) and nav_item.endswith(".md"):
        md_files.append(nav_item)
    return md_files

# -----------------------------------------------------------------
# Test Cases
# -----------------------------------------------------------------
@pytest.mark.parametrize("md_file", get_md_files())
def test_md_file_is_valid(md_file):
    """Ensure all Markdown files in the docs directory are valid."""
    assert os.path.exists(md_file), f"File not found: {md_file}"

    file_size = os.path.getsize(md_file)
    assert file_size > 0, f"Empty file: {md_file}"

    try:
        with open(md_file, encoding="utf-8") as f:
            content = f.read().strip()
            assert content, f"No content: {md_file}"
            non_empty_lines = [line for line in content.splitlines() if line.strip()]
            assert non_empty_lines, f"Only whitespace: {md_file}"

    except UnicodeDecodeError:
        pytest.fail(f"Encoding issue: {md_file}")
    except PermissionError:
        pytest.fail(f"Permission denied: {md_file}")
