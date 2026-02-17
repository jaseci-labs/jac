"""Unit tests for validating Markdown documentation files."""

import os;
import from pathlib { Path }
import from jaclang.runtimelib.test { parametrize }

def get_md_files -> list[str] {
    """Retrieve all Markdown files in the docs directory."""
    docs_dir = os.path.join(os.path.dirname(__file__), "..", "docs");
    md_files: list[str] = [];
    for (root, _, files) in os.walk(docs_dir) {
        for file in files {
            if file.endswith(".md") {
                md_files.append(os.path.join(root, file));
            }
        }
    }
    return md_files;
}

def md_file_is_valid(md_file: str) -> None {
    """Ensure a Markdown file in the docs directory is valid."""
    assert os.path.exists(md_file) , f"File not found: {md_file}";

    file_size = os.path.getsize(md_file);
    assert file_size > 0 , f"Empty file: {md_file}";

    try {
        with open(md_file, encoding="utf-8") as f {
            content = f.read().strip();
            assert content , f"No content: {md_file}";
            non_empty_lines = [
                line
                for line in content.splitlines()
                if line.strip()
            ];
            assert non_empty_lines , f"Only whitespace: {md_file}";
        }
    } except UnicodeDecodeError {
        assert False , f"Encoding issue: {md_file}";
    } except PermissionError {
        assert False , f"Permission denied: {md_file}";
    }
}

with entry {
    parametrize(
        "md_file_is_valid",
        get_md_files(),
        md_file_is_valid,
        id_fn=lambda f : Path(f).name
    );
}
