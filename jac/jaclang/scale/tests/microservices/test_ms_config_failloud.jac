"""A microservice config error must stop `jac start`, not silently start the
app as a monolith. The route-name guard raises ValueError for a route that
collides with a gateway builtin; before the fix, scale_start swallowed every
exception from route resolution and fell through to single-process serving
with no output at all."""

import os;
import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }
import from jaclang.scale.runtime.context.util { jac_executable }


def _bad_route_project -> Path {
    project_dir = Path(tempfile.mkdtemp(prefix="jac-ms-failloud-"));
    (project_dir / "jac.toml").write_text(
        '[project]\n'
        'name = "failloud"\n'
        'entry-point = "main.jac"\n'
        '\n'
        '[scale.microservices.routes]\n'
        'admin = ""\n',
        encoding="utf-8"
    );
    (project_dir / "main.jac").write_text("with entry {}\n", encoding="utf-8");
    (project_dir / "admin.jac").write_text("with entry {}\n", encoding="utf-8");
    return project_dir;
}


def _local_env -> dict[str, str] {
    env = os.environ.copy();
    for key in ["JAC_SV_SIBLING", "JAC_SV_NAME", "JAC_SV_ROUTES"] {
        env.pop(key, None);
    }
    return env;
}


test "a reserved route name stops startup loudly instead of serving a monolith" {
    project_dir = _bad_route_project();
    try {
        result = subprocess.run(
            [jac_executable(), "start", "main.jac"],
            capture_output=True,
            text=True,
            cwd=str(project_dir),
            env=_local_env(),
            timeout=90
        );
    } finally {
        shutil.rmtree(project_dir, ignore_errors=True);
    }

    combined = result.stdout + result.stderr;
    assert result.returncode == 1 , (
        f"expected exit 1 on an invalid route config, got rc={result.returncode}\n"
        f"STDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
    );
    assert "Microservice configuration invalid" in combined;
    assert "collides" in combined;
}
