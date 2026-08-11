"""Bare `jac create` semantics under an ancestor project: nested projects
are first-class (nearest-wins config resolution), so an ancestor jac.toml
must not block initializing a fresh subdirectory -- only re-initializing an
existing project root warrants the --force gate."""

import os;
import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.cli.commands { project }
import from jaclang.project.template_registry { initialize_template_registry }

glob _orig_cwd: str = os.getcwd();

def _fresh_tree -> Path {
    os.environ["JAC_CLIENT_SKIP_NPM_INSTALL"] = "1";
    initialize_template_registry();
    d = Path(tempfile.mkdtemp(prefix="jacnested_"));
    with open(d / "jac.toml", "w") as f {
        f.write('[project]\nname = "parent"\nentry-point = "main.jac"\n');
    }
    return d;
}

test "bare create initializes a nested project under an ancestor project" {
    parent = _fresh_tree();
    child = parent / "nested";
    child.mkdir();
    os.chdir(child);
    try {
        rc = project.create();
        assert rc == 0 , f"nested bare create returned {rc}";
        assert (child / "jac.toml").exists() , "nested jac.toml not created";
    } finally {
        os.chdir(_orig_cwd);
        shutil.rmtree(parent, ignore_errors=True);
    }
}

test "bare create still refuses at an existing project root" {
    parent = _fresh_tree();
    os.chdir(parent);
    try {
        rc = project.create();
        assert rc != 0 , "re-initializing an existing root must require --force";
    } finally {
        os.chdir(_orig_cwd);
        shutil.rmtree(parent, ignore_errors=True);
    }
}
