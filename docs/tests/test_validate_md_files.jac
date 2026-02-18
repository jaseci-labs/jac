"""Unit tests for validating Markdown documentation files."""

import os;
import from pathlib { Path }

"""Retrieve all Markdown files in the docs directory."""
def get_md_files -> list[str] {
    docs_dir = Path(os.path.dirname(__file__)).parent / "docs";
    return [str(f) for f in sorted(docs_dir.rglob("*.md"))];
}

test "all markdown files are valid" {
    md_files = get_md_files();
    assert len(md_files) > 0 , "No markdown files found in docs directory";

    for md_file in md_files {
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
}
