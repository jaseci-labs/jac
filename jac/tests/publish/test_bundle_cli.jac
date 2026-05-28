"""CLI tests for the `jac bundle` command."""

import os;
import tempfile;
import shutil;
import from pathlib { Path }
import from subprocess { run }
import from jaclang.cli.commands.project { _PRECOMPILE_MINOR_RANGE }


"""Return the cpython-3XX tags for every python3.X present on PATH."""
def _available_python_tags -> list[str] {
    tags: list[str] = [];
    for minor in _PRECOMPILE_MINOR_RANGE {
        if shutil.which(f"python3.{minor}") {
            tags.append(f"cpython-3{minor}");
        }
    }
    return tags;
}


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


test "bundle --precompile generates .jir files per version and produces wheel" {
    tags = _available_python_tags();
    if not tags {
        return;
    }

    tmp_path = tempfile.mkdtemp();
    original_cwd = os.getcwd();
    try {
        os.chdir(tmp_path);
        _make_project(tmp_path);
        precompiled_dir = Path(tmp_path) / "mypkg" / "_precompiled";

        result = run(
            ["jac", "bundle", "--precompile"], capture_output=True, text=True,
        );

        assert result.returncode == 0 , (
            f"jac bundle --precompile failed (exit {result.returncode}):\n"
            f"stdout: {result.stdout}\nstderr: {result.stderr}"
        );

        assert precompiled_dir.is_dir() , f"_precompiled/ not created under {precompiled_dir.parent}";
        for tag in tags {
            tag_dir = precompiled_dir / tag;
            assert tag_dir.is_dir() , f"Missing version directory: {tag_dir}";
            assert len(list(tag_dir.rglob("*.jir"))) > 0 , f"No .jir files under {tag_dir}";
        }
        assert (precompiled_dir / "manifest.json").is_file() , (
            f"manifest.json not written to {precompiled_dir}"
        );
        whl_files = list((Path(tmp_path) / "dist").glob("*.whl"));
        assert len(whl_files) == 1 , f"Expected 1 wheel in dist/, found: {whl_files}";
    } finally {
        os.chdir(original_cwd);
        shutil.rmtree(tmp_path, ignore_errors=True);
    }
}
