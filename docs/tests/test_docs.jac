"""Unit tests for documentation build infrastructure."""

import os;
import shutil;
import tempfile;

import from pathlib { Path }
import from subprocess { run as subprocess_run }

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

test "pypi jaclang contains precompiled jir" {
    tmp = tempfile.mkdtemp(prefix="test_jir_");
    try {
        subprocess_run(
            ["pip", "install", "jaclang", "--target", tmp, "--no-deps", "-q"],
            check=True,
            text=False
        );
        jac_dir = os.path.join(tmp, "jaclang");
        assert os.path.isdir(jac_dir) , "jaclang package not found in PyPI install";

        jir = [
            f for (_, _, fs) in os.walk(jac_dir)
            for f in fs
            if f.endswith(".jir")
        ];
        assert len(jir) > 0 , "PyPI jaclang has no .jir files — precompilation missing from release";
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}
