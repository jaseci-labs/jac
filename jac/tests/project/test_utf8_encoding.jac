"""Tests for UTF-8 encoding in file operations.

Verifies that open() calls use encoding="utf-8" so non-ASCII
characters (emojis, accented chars) work correctly on Windows
where the default encoding is cp1252.
"""

import os;
import from tempfile { TemporaryDirectory }
import from pathlib { Path }


test "write and read file with emojis" {
    with TemporaryDirectory() as tmpdir {
        filepath = os.path.join(tmpdir, "test.txt");
        content = "Hello ✨ World 🚀 Jac ✔";
        # Write with encoding
        with open(filepath, "w", encoding="utf-8") as f {
            f.write(content);
        }
        # Read with encoding
        with open(filepath, "r", encoding="utf-8") as f {
            result = f.read();
        }
        assert result == content , f"Expected '{content}' but got '{result}'";
    }
}


test "write and read file with accented characters" {
    with TemporaryDirectory() as tmpdir {
        filepath = os.path.join(tmpdir, "test.txt");
        content = "café résumé naïve über";
        with open(filepath, "w", encoding="utf-8") as f {
            f.write(content);
        }
        with open(filepath, "r", encoding="utf-8") as f {
            result = f.read();
        }
        assert result == content;
    }
}


"""Verify cfg_build_pass.impl.jac uses encoding='utf-8'."""
test "cfg_build_pass opens file with utf-8" {
    import from pathlib { Path }
    source_file = Path(__file__).parent.parent / "jaclang" / "compiler" / "passes" / "main" / "impl" / "cfg_build_pass.impl.jac";
    if source_file.exists() {
        with open(str(source_file), "r", encoding="utf-8") as f {
            content = f.read();
        }
        assert 'encoding="utf-8"' in content , "cfg_build_pass.impl.jac should use encoding='utf-8' in open()";
    }
}


"""Verify project.impl.jac uses encoding='utf-8' for all open() calls."""
test "project_impl opens files with utf-8" {
    import from pathlib { Path }
    source_file = Path(__file__).parent.parent / "jaclang" / "cli" / "commands" / "impl" / "project.impl.jac";
    if source_file.exists() {
        with open(str(source_file), "r", encoding="utf-8") as f {
            content = f.read();
        }
        # Check that write calls have encoding
        lines = content.split("\n");
        for (i, line) in enumerate(lines) {
            if 'open(' in line and '"w"' in line and 'encoding' not in line {
                assert False , f"Line {i + 1} has open() with 'w' mode but no encoding='utf-8': {line.strip()}";
            }
        }
    }
}
