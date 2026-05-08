"""CLI tests for the `jac bundle` command."""

import os;
import tempfile;
import shutil;
import from pathlib { Path }
import from subprocess { run }


"""Write a minimal jac.toml and package skeleton into tmp_path."""
def _make_project(tmp_path: str, pkg_name: str = "mypkg", version: str = "1.0.0") {
    toml = (
        '[project]\n' 'name = "' + pkg_name + '"\n' 'version = "' + version + '"\n'
        'requires-python = ">=3.11"\n\n'
        '[project.include]\n'
        'packages = ["' + pkg_name + '"]\n'
    );
    (Path(tmp_path) / "jac.toml").write_text(toml);
    pkg_dir = Path(tmp_path) / pkg_name;
    pkg_dir.mkdir(exist_ok=True);
    (pkg_dir / "__init__.jac").write_text(f"# {pkg_name}\n");
}

test "bundle succeeds and writes wheel to dist/" {
    tmp_path = tempfile.mkdtemp();
    original_cwd = os.getcwd();
    os.chdir(tmp_path);
    try {
        _make_project(tmp_path);

        result = run(["jac", "bundle"], capture_output=True, text=True);

        assert result.returncode == 0;
        whl_files = list((Path(tmp_path) / "dist").glob("*.whl"));
        assert len(whl_files) == 1;
        assert whl_files[0].name == "mypkg-1.0.0-py3-none-any.whl";
    } finally {
        os.chdir(original_cwd);
        shutil.rmtree(tmp_path, ignore_errors=True);
    }
}

test "bundle writes wheel to a custom output directory" {
    tmp_path = tempfile.mkdtemp();
    original_cwd = os.getcwd();
    os.chdir(tmp_path);
    try {
        _make_project(tmp_path);
        custom_out = str(Path(tmp_path) / "wheels");

        result = run(
            ["jac", "bundle", "--output", custom_out], capture_output=True, text=True,
        );

        assert result.returncode == 0;
        whl_files = list(Path(custom_out).glob("*.whl"));
        assert len(whl_files) == 1;
    } finally {
        os.chdir(original_cwd);
        shutil.rmtree(tmp_path, ignore_errors=True);
    }
}
