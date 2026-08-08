"""Tests for AndroidTarget._resolve_type_check — the [client.android] gate.

Type checking defaults ON for the Compose target now that the checker
understands the idiomatic Kotlin-isms (.dp/.sp/.len extensions, Modifier
chains, Arrangement/Alignment/Color const namespaces). A project can still
opt out with `type_check = false`. These pin the tri-state: absent key -> on,
explicit true -> on, explicit false -> off.
"""
import os;
import tempfile;
import from pathlib { Path }
import from jaclang.runtimelib.client.targets.android_target { AndroidTarget }

def _project_with_toml(body: str) -> Path {
    d = Path(tempfile.mkdtemp(prefix="jac_test_android_tc_"));
    (d / "jac.toml").write_text(body);
    return d;
}

test "type checking defaults ON when jac.toml has no [client.android] section" {
    d = _project_with_toml("[project]\nname = \"demo\"\n");
    assert AndroidTarget()._resolve_type_check(d) == True;
}

test "type checking defaults ON when [client.android] omits type_check" {
    d = _project_with_toml("[client.android]\npackage = \"dev.jac.demo\"\n");
    assert AndroidTarget()._resolve_type_check(d) == True;
}

test "type_check = false opts a project out" {
    d = _project_with_toml("[client.android]\ntype_check = false\n");
    assert AndroidTarget()._resolve_type_check(d) == False;
}

test "type_check = true keeps checking on" {
    d = _project_with_toml("[client.android]\ntype_check = true\n");
    assert AndroidTarget()._resolve_type_check(d) == True;
}

test "a missing jac.toml still defaults ON" {
    d = Path(tempfile.mkdtemp(prefix="jac_test_android_tc_none_"));
    assert AndroidTarget()._resolve_type_check(d) == True;
}

# ── Single source of truth: target ⇒ framework (P0 #2) ───────────────────────

test "_ensure_compose_framework persists framework = compose when absent" {
    d = _project_with_toml("[project]\nname = \"demo\"\n");
    t = AndroidTarget();
    assert t._resolve_client_framework(d) is None , "framework starts unset";
    t._ensure_compose_framework(d);
    assert t._resolve_client_framework(d) == "compose" , "selecting Android must persist [client] framework = compose";
    assert 'framework = "compose"' in (d / "jac.toml").read_text();
}

test "_ensure_compose_framework inserts under an existing [client] table" {
    d = _project_with_toml("[project]\nname = \"demo\"\n\n[client]\n");
    t = AndroidTarget();
    t._ensure_compose_framework(d);
    assert t._resolve_client_framework(d) == "compose";
}

test "_ensure_compose_framework rejects an explicit non-Compose framework" {
    d = _project_with_toml("[client]\nframework = \"react\"\n");
    raised = False;
    try {
        AndroidTarget()._ensure_compose_framework(d);
    } except RuntimeError {
        raised = True;
    }
    assert raised , "a react framework must be rejected for the Android target";
    # the conflicting config is left untouched, not silently overwritten
    assert 'framework = "react"' in (d / "jac.toml").read_text();
}

test "_ensure_compose_framework is a no-op when already compose" {
    d = _project_with_toml("[client]\nframework = \"compose\"\n");
    t = AndroidTarget();
    t._ensure_compose_framework(d);
    assert t._resolve_client_framework(d) == "compose";
}
