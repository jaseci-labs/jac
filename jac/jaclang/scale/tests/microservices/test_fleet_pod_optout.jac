"""A deployed fleet stamps JAC_SV_SIBLING/JAC_SV_ROUTES into its pods; the
gateway pod must boot from that env even when the app's jac.toml carries the
(deprecated) [scale.microservices] enabled = false. The opt-out governs
whether THIS process realizes a fleet - a local `jac start`/`jac scale` still
honors it, and apps that declare routes but opt out keep serving
single-process - never whether a member of an already-realized fleet may
serve. These tests drive the real CLI the way a pod command does and pin that
contract, plus the one-time deprecation warning on the key."""

import os;
import shutil;
import subprocess;
import tempfile;
import time;
import requests;
import from pathlib { Path }
import from jaclang.scale.runtime.context.util { jac_executable }
import from jaclang.scale.tests.server_support { get_free_port }

glob _FLEET_KEYS: list[str] = ["JAC_SV_SIBLING", "JAC_SV_NAME", "JAC_SV_ROUTES"];


def _optout_project(port: int) -> Path {
    project_dir = Path(tempfile.mkdtemp(prefix="jac-fleet-optout-"));
    (project_dir / "jac.toml").write_text(
        '[project]\n'
        'name = "landing"\n'
        'entry-point = "main.jac"\n'
        '\n'
        '[scale.microservices]\n'
        'enabled = false\n'
        f'gateway_port = {port}\n',
        encoding="utf-8"
    );
    (project_dir / "main.jac").write_text("with entry {}\n", encoding="utf-8");
    # Deployed bundles ship a staged admin console; without one the gateway
    # detours into a from-source client build before it serves.
    admin_dir = project_dir / ".jac" / "admin";
    admin_dir.mkdir(parents=True);
    (admin_dir / "index.html").write_text("<html></html>\n", encoding="utf-8");
    return project_dir;
}


def _fleet_env -> dict[str, str] {
    env = os.environ.copy();
    env.update(
        {
            "JAC_SV_SIBLING": "1",
            "JAC_SV_NAME": "__gateway__",
            "JAC_SV_ROUTES": '{"main": ""}'
        }
    );
    return env;
}


def _local_env -> dict[str, str] {
    env = os.environ.copy();
    for key in _FLEET_KEYS {
        env.pop(key, None);
    }
    return env;
}


def _stop(proc: subprocess.Popen) {
    if proc.poll() is None {
        proc.terminate();
        try {
            proc.wait(timeout=10);
        } except subprocess.TimeoutExpired {
            proc.kill();
            proc.wait(timeout=10);
        }
    }
}


test "a fleet gateway pod boots despite the app's enabled = false opt-out" {
    port = get_free_port();
    project_dir = _optout_project(port);
    proc = subprocess.Popen(
        [jac_executable(), "scale", "gateway"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        cwd=str(project_dir),
        env=_fleet_env()
    );
    try {
        live = False;
        for _ in range(30) {
            if proc.poll() is not None {
                break;
            }
            try {
                r = requests.get(f"http://127.0.0.1:{port}/healthz/live", timeout=1);
                if r.status_code == 200 {
                    live = True;
                    break;
                }
            } except Exception {
                time.sleep(1);
            }
        }
        if not live {
            (stdout, stderr) = proc.communicate(timeout=5);
            assert False , (
                f"gateway pod refused to boot on the opt-out "
                f"(rc={proc.returncode})\nSTDOUT:\n{stdout}\nSTDERR:\n{stderr}"
            );
        }
    } finally {
        _stop(proc);
        shutil.rmtree(project_dir, ignore_errors=True);
    }
}


test "a local `jac scale gateway` still honors the opt-out, with a deprecation warning" {
    port = get_free_port();
    project_dir = _optout_project(port);
    try {
        result = subprocess.run(
            [jac_executable(), "scale", "gateway"],
            capture_output=True,
            text=True,
            cwd=str(project_dir),
            env=_local_env(),
            timeout=60
        );
    } finally {
        shutil.rmtree(project_dir, ignore_errors=True);
    }

    combined = result.stdout + result.stderr;
    assert result.returncode == 1;
    assert "Microservice mode is disabled" in combined;
    assert "deprecated" in combined , (
        f"no deprecation warning for the legacy key:\n{combined}"
    );
}


test "the fleet env does not unlock local orchestration actions" {
    port = get_free_port();
    project_dir = _optout_project(port);
    try {
        result = subprocess.run(
            [jac_executable(), "scale", "status"],
            capture_output=True,
            text=True,
            cwd=str(project_dir),
            env=_fleet_env(),
            timeout=60
        );
    } finally {
        shutil.rmtree(project_dir, ignore_errors=True);
    }

    assert result.returncode == 1;
    assert "Microservice mode is disabled" in (result.stdout + result.stderr);
}
