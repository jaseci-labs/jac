"""Tests for jac-desktop's kind-aware `jac create` template.

jac-desktop contributes the `desktop` project kind to the kind-aware `jac
create`. It scaffolds with `[project] kind = "desktop"` stamped and a
`main.jac` entry-point."""

import os;
import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.cli.commands { project }
import from jaclang.project.config { JacConfig }
import from jaclang.project.template_registry { initialize_template_registry }

glob _tmp_dirs: list[str] = [],
     _orig_cwd: str = os.getcwd();

def _cleanup {
    os.chdir(_orig_cwd);
    for d in _tmp_dirs {
        shutil.rmtree(d, ignore_errors=True);
    }
    _tmp_dirs.clear();
}

test "create --kind desktop" {
    initialize_template_registry();
    d = tempfile.mkdtemp(prefix="jacdesktopkind_");
    _tmp_dirs.append(d);
    os.chdir(d);
    rc = project.create(name="app", kind="desktop", force=True);
    os.chdir(_orig_cwd);
    assert rc == 0 , f"create --kind desktop returned {rc}";
    proj = Path(d) / "app";
    toml = (proj / "jac.toml").read_text();
    assert 'kind = "desktop"' in toml;
    assert (proj / "main.jac").exists();
    cfg = JacConfig.discover(start_path=proj);
    assert cfg.project.kind == "desktop";
    _cleanup();
}
