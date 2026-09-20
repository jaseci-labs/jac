"""Error polling is safe before startup, without a thread, and after shutdown."""
import os;
import shutil;
import subprocess;
import sys;
import sysconfig;
import tempfile;
import from pathlib { Path }

test "Python error polling follows attached thread lifetime" {
    if sys.platform not in ("linux", "darwin") or shutil.which("cc") is None {
        testskip("requires a POSIX C compiler");
    }
    library = Path(sys.base_prefix)
        / "lib"
        / str(sysconfig.get_config_var("INSTSONAME"));
    assert library.is_file() , f"bundled Python library missing: {library}";
    source = Path(__file__).parent / "fixtures" / "python_error_lifecycle.c";
    with tempfile.TemporaryDirectory() as directory {
        output = Path(directory) / "probe";
        subprocess.run(
            [
                "cc",
                str(source),
                str(library),
                f"-Wl,-rpath,{library.parent}",
                "-o",
                str(output)
            ],
            check=True,
            capture_output=True,
            text=True
        );
        env = dict(os.environ);
        env["PYTHONHOME"] = sys.base_prefix;
        result = subprocess.run(
            [str(output)], env=env, capture_output=True, text=True, timeout=30
        );
        assert result.returncode == 0 , f"lifecycle probe exited {result.returncode}: {result.stderr}";
    }
}
