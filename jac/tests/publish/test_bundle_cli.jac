"""CLI tests for the `jac bundle` command."""

import os;
import sys;
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

test "bundle succeeds and writes wheel and sdist to dist/" {
    tmp_path = tempfile.mkdtemp();
    original_cwd = os.getcwd();
    os.chdir(tmp_path);
    try {
        _make_project(tmp_path);

        result = run(
            ["jac", "build", "--as", "wheel", "--no_typecheck"],
            capture_output=True,
            text=True
        );

        assert result.returncode == 0 , (
            f"jac bundle failed:\nstdout: {result.stdout}\nstderr: {result.stderr}"
        );
        dist = Path(tmp_path) / "dist";
        whl_files = list(dist.glob("*.whl"));
        sdist_files = list(dist.glob("*.tar.gz"));
        assert len(whl_files) == 1 , f"Expected 1 wheel, found: {whl_files}";
        assert len(sdist_files) == 1 , f"Expected 1 sdist, found: {sdist_files}";
        assert whl_files[0].name == "mypkg-1.0.0-py3-none-any.whl";
        assert sdist_files[0].name == "mypkg-1.0.0.tar.gz";
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
            ["jac", "build", "--as", "wheel", "--no_typecheck", "--output", custom_out],
            capture_output=True,
            text=True,
        );

        assert result.returncode == 0;
        whl_files = list(Path(custom_out).glob("*.whl"));
        assert len(whl_files) == 1;
    } finally {
        os.chdir(original_cwd);
        shutil.rmtree(tmp_path, ignore_errors=True);
    }
}


test "bundle sdist installs with pip" {
    tmp_path = tempfile.mkdtemp();
    original_cwd = os.getcwd();
    os.chdir(tmp_path);
    try {
        _make_project(tmp_path);

        bundle_result = run(
            ["jac", "build", "--as", "wheel", "--no_typecheck"],
            capture_output=True,
            text=True
        );
        assert bundle_result.returncode == 0 , (
            f"jac bundle failed:\nstdout: {bundle_result.stdout}\nstderr: {bundle_result.stderr}"
        );

        sdist_files = list((Path(tmp_path) / "dist").glob("*.tar.gz"));
        assert len(sdist_files) == 1;
        sdist_path = sdist_files[0];

        install_dir = Path(tmp_path) / "installed";
        install_dir.mkdir();
        pip_result = run(
            [
                sys.executable,
                "-m",
                "pip",
                "install",
                "--no-build-isolation",
                "--target",
                str(install_dir),
                "--quiet",
                str(sdist_path),

            ],
            capture_output=True,
            text=True,
        );
        assert pip_result.returncode == 0 , (
            f"pip install from sdist failed:\nstdout: {pip_result.stdout}\nstderr: {pip_result.stderr}"
        );
        assert (install_dir / "mypkg").is_dir() , "installed package directory not found";
    } finally {
        os.chdir(original_cwd);
        shutil.rmtree(tmp_path, ignore_errors=True);
    }
}
