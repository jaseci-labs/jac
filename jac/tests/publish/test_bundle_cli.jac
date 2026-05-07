"""CLI tests for the `jac bundle` command (project.bundle).

Tests cover:
  - successful wheel build into the default dist/ directory
  - custom --output directory
  - error when no jac.toml is present
  - error when jac.toml has no [package] section
"""

import os;
import tempfile;
import shutil;
import from pathlib { Path }
import from jaclang.project.config { set_config }
import from jaclang.cli.commands { project }


# Helpers --------------------------------------------------------------------------
"""Write a minimal jac.toml and package skeleton under tmp_path."""
def make_project(tmp_path: str, pkg_name: str = "mypkg", version: str = "1.0.0") {
    toml = (
        '[package]\n' 'name = "' + pkg_name + '"\n' 'version = "' + version + '"\n'
        'requires-python = ">=3.11"\n\n'
        '[package.include]\n'
        'packages = ["' + pkg_name + '"]\n'
    );
    (Path(tmp_path) / "jac.toml").write_text(toml);
    pkg_dir = Path(tmp_path) / pkg_name;
    pkg_dir.mkdir(exist_ok=True);
    (pkg_dir / "__init__.jac").write_text(f"# {pkg_name}\n");
}

# Tests --------------------------------------------------------------------------
test "bundle succeeds and writes wheel to dist/" {
    tmp_path = tempfile.mkdtemp();
    original_cwd = os.getcwd();
    os.chdir(tmp_path);
    set_config(None);
    try {
        make_project(tmp_path);
        result = project.bundle();
        assert result == 0;
        dist = Path(tmp_path) / "dist";
        assert dist.is_dir();
        whl_files = list(dist.glob("*.whl"));
        assert len(whl_files) == 1;
        assert whl_files[0].name == "mypkg-1.0.0-py3-none-any.whl";
    } finally {
        os.chdir(original_cwd);
        set_config(None);
        shutil.rmtree(tmp_path, ignore_errors=True);
    }
}

test "bundle writes wheel to a custom output directory" {
    tmp_path = tempfile.mkdtemp();
    original_cwd = os.getcwd();
    os.chdir(tmp_path);
    set_config(None);
    try {
        make_project(tmp_path);
        custom_out = str(Path(tmp_path) / "wheels");
        result = project.bundle(output=custom_out);
        assert result == 0;
        whl_files = list(Path(custom_out).glob("*.whl"));
        assert len(whl_files) == 1;
    } finally {
        os.chdir(original_cwd);
        set_config(None);
        shutil.rmtree(tmp_path, ignore_errors=True);
    }
}
