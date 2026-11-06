"""A module cache entry is keyed on the bytes the compile read.

The key was computed from disk when the entry was written, so an annex edited
while its module compiled stored the old bytecode under the new content's key,
and every later process was served the stale code. A compile now holds the
digest of each source it reads, and the cache key uses what it holds.
"""

import hashlib;
import os;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.driver.jir {
    compiled_content_reads,
    compiled_content_scope,
    compute_content_sha256
}
import from jaclang.project.textio { read_file_with_encoding }

def _sha(data: bytes) -> str {
    return hashlib.sha256(data).hexdigest();
}

test "an annex edited mid-compile keys on the bytes the compile read" {
    with tempfile.TemporaryDirectory() as tmp {
        annex = Path(tmp) / "mod.impl.jac";
        before = b"impl f -> int { return 1; }\n";
        after = b"impl f -> int { return 2; }\n";
        annex.write_bytes(before);
        with compiled_content_scope() {
            assert read_file_with_encoding(str(annex), compiled_content_reads())
                == before.decode();
            annex.write_bytes(after);
            assert compute_content_sha256(str(annex)) == _sha(before);
        }
        assert compute_content_sha256(str(annex)) == _sha(after);
    }
}

test "the host a compile reads through holds what it read" {
    import from jaclang.compiler.frontend.host { active_host }
    with tempfile.TemporaryDirectory() as tmp {
        annex = Path(tmp) / "mod.impl.jac";
        before = b"impl f -> int { return 1; }\n";
        annex.write_bytes(before);
        with compiled_content_scope() {
            active_host().read_source(str(annex));
            annex.write_bytes(b"impl f -> int { return 2; }\n");
            assert compute_content_sha256(str(annex)) == _sha(before);
        }
    }
}

test "two reads that disagree key on nothing" {
    with tempfile.TemporaryDirectory() as tmp {
        src = Path(tmp) / "mod.jac";
        src.write_bytes(b"glob x = 1;\n");
        with compiled_content_scope() {
            read_file_with_encoding(str(src), compiled_content_reads());
            src.write_bytes(b"glob x = 2;\n");
            read_file_with_encoding(str(src), compiled_content_reads());
            assert compute_content_sha256(str(src)) == "";
        }
    }
}

test "a nested scope shares the enclosing compile's reads" {
    with tempfile.TemporaryDirectory() as tmp {
        src = Path(tmp) / "mod.jac";
        src.write_bytes(b"glob x = 1;\n");
        with compiled_content_scope() {
            outer = compiled_content_reads();
            with compiled_content_scope() {
                assert compiled_content_reads() is outer;
                read_file_with_encoding(str(src), compiled_content_reads());
            }
            assert os.path.realpath(str(src)) in outer;
        }
        assert compiled_content_reads() is None;
    }
}

test "reading text keeps universal newlines and a utf-8 bom" {
    with tempfile.TemporaryDirectory() as tmp {
        src = Path(tmp) / "mod.jac";
        src.write_bytes(b"\xef\xbb\xbfglob x = 1;\r\nglob y = 2;\r\n");
        assert read_file_with_encoding(str(src)) == "glob x = 1;\nglob y = 2;\n";
    }
}
