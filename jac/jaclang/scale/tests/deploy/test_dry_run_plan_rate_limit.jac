"""`jac scale deploy --dry-run` must show the rate limit the project asked
for. The plan renderer read `requests_per_minute`, a key the config loader
never emits, so every configured limit rendered as no line at all and the
dry run could not confirm a limit before the deploy that applies it. Real
CLI subprocess against a real project: the dry-run path contacts no cluster
and no network (test_dry_run_purity.jac holds that contract)."""

import os;
import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }
import from jaclang.scale.runtime.context.util { jac_executable }


def _project(rate_limit: str) -> Path {
    project_dir = Path(tempfile.mkdtemp(prefix="jac-plan-ratelimit-"));
    (project_dir / "jac.toml").write_text(
        '[project]\n'
        'name = "planratelimit"\n'
        'default-app = "main"\n'
        '\n'
        '[apps.main]\n'
        'kind = "web-app"\n'
        'entry-point = "main.jac"\n'
        '\n'
        '[apps.orders]\n'
        'kind = "service"\n'
        'entry-point = "orders.jac"\n'
        '\n'
        '[scale.kubernetes]\n'
        'app_name = "planratelimit"\n'
        'namespace = "planratelimit"\n'
        # Without a storage class the RWX bundle PVC raises before the plan
        # is rendered.
        'bundle_storage_class = "standard"\n'
        '\n'
            + rate_limit,
        encoding="utf-8"
    );
    (project_dir / "main.jac").write_text("with entry {}\n", encoding="utf-8");
    (project_dir / "orders.jac").write_text("with entry {}\n", encoding="utf-8");
    return project_dir;
}


def _dry_run_plan(rate_limit: str) -> tuple[int, str] {
    project_dir = _project(rate_limit);
    env = os.environ.copy();
    for key in ["JAC_SV_SIBLING", "JAC_SV_NAME", "JAC_SV_FLEET"] {
        env.pop(key, None);
    }
    try {
        result = subprocess.run(
            [jac_executable(), "scale", "deploy", "main.jac", "--dry-run"],
            capture_output=True,
            text=True,
            cwd=str(project_dir),
            env=env,
            timeout=300
        );
    } finally {
        shutil.rmtree(project_dir, ignore_errors=True);
    }
    return (result.returncode, result.stdout + result.stderr);
}


test "a dry run shows the per-IP and per-user limits the project configured" {
    (rc, out) = _dry_run_plan(
        '[scale.gateway.rate_limit]\n'
        'enabled = true\n'
        'per_ip_rpm = 120\n'
        'per_user_rpm = 30\n'
    );
    assert rc == 0 , f"dry run exited {rc}:\n{out}";
    assert "120/min per IP" in out , f"configured per-IP limit missing:\n{out}";
    assert "30/min per user" in out , f"configured per-user limit missing:\n{out}";
}


test "a dry run of a disabled rate limit shows no rate-limit line" {
    (rc, out) = _dry_run_plan(
        '[scale.gateway.rate_limit]\n'
        'enabled = false\n'
        'per_ip_rpm = 120\n'
        'per_user_rpm = 30\n'
    );
    assert rc == 0 , f"dry run exited {rc}:\n{out}";
    assert "rate_limit:" not in out , f"a disabled limit rendered a line:\n{out}";
    assert "120/min" not in out;
}
