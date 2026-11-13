"""The native `tempfile.mkdtemp` creates fresh private directories.

Exercise the native implementation through the existing in-process JIT
harness, then inspect the created directories from the host test process.
"""

import ctypes;
import os;
import stat;
import tempfile;
import from pathlib { Path }
import from tests.support { compile_native, native_str_func }

test "native tempfile.mkdtemp creates private directories and reports errors" {
    (engine, _ir) = compile_native("tempfile_mkdtemp_probe.jac");
    make_default = native_str_func(engine, "make_default", ctypes.c_char_p);
    make_affixed = native_str_func(engine, "make_affixed", ctypes.c_char_p);
    make_in_dir = native_str_func(
        engine, "make_in_dir", ctypes.c_char_p, ctypes.c_char_p
    );
    missing_dir_error = native_str_func(
        engine, "missing_dir_error", ctypes.c_char_p, ctypes.c_char_p
    );
    old_tmpdir = os.environ.get("TMPDIR");
    try {
        with tempfile.TemporaryDirectory() as tmpdir {
            tmp = Path(tmpdir);
            os.environ["TMPDIR"] = tmpdir;
            paths = [Path(make_default().decode()) for _ in range(2)];
            assert paths[0] != paths[1] , "mkdtemp must not reuse a directory";
            for path in paths {
                assert path.is_dir() and path.is_absolute() , path;
                assert path.parent == tmp , path;
                assert stat.S_IMODE(path.stat().st_mode) == 0o700 , (
                    f"mkdtemp must create mode-0700 directories: {path}"
                );
            }
            affixed = Path(make_affixed().decode());
            assert affixed.parent == tmp and affixed.is_dir();
            assert affixed.name.startswith("jacp-") and affixed.name.endswith("-sfx") , affixed.name;
            base = tmp / "base";
            base.mkdir();
            explicit = Path(make_in_dir(str(base)).decode());
            assert explicit.parent == base and explicit.is_dir();
            relative = tmp / "relative";
            relative.mkdir();
            old_cwd = os.getcwd();
            try {
                os.chdir(tmpdir);
                relative_result = Path(make_in_dir("relative").decode());
            } finally {
                os.chdir(old_cwd);
            }
            assert relative_result.is_absolute();
            assert relative_result.parent == relative.resolve();
            error = missing_dir_error(str(tmp / "missing")).decode();
            assert "No such file or directory" in error , error;
            assert "unreachable" not in error , error;
        }
    } finally {
        if old_tmpdir is None {
            os.environ.pop("TMPDIR", None);
        } else {
            os.environ["TMPDIR"] = old_tmpdir;
        }
    }
}
