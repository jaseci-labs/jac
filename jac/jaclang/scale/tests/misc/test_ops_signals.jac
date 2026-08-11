"""Guards #8000 (1.5): the admin ops page must render every signal the
backend probes. The UI iterated a stale mongo/redis order, so those keys
rendered nothing and the postgres card - the one that matters most under the
Postgres-native architecture - never rendered at all.

The UI page is client-side jsx and cannot be imported here, so the guard
parses its SIGNAL_ORDER/SIGNAL_LABELS source against the backend's probe
list, which this test also pins.
"""

import re;
import from pathlib { Path }
import jaclang.scale.admin as admin_pkg;

glob BACKEND_SIGNALS = ["traces", "logs", "metrics", "postgres", "admin_api"];


def _ops_page_source -> str {
    admin_dir = Path(str(admin_pkg.__file__)).parent;
    return (admin_dir / "ui" / "pages" / "admin" / "ops" / "OpsPage.jac").read_text(
        encoding="utf-8"
    );
}


def _backend_probe_names -> list[str] {
    admin_dir = Path(str(admin_pkg.__file__)).parent;
    src = (admin_dir / "impl" / "ops.impl.jac").read_text(encoding="utf-8");
    m = re.search(r'probe_names\s*=\s*\[([^\]]*)\]', src);
    assert m , "probe_names list not found in ops.impl.jac";
    names = re.findall(r'"([a-z_]+)"', m.group(1));
    return names + ["admin_api"];
}


test "ops page renders every backend signal" {
    src = _ops_page_source();
    m = re.search(r'SIGNAL_ORDER\s*=\s*\[([^\]]*)\]', src);
    assert m , "SIGNAL_ORDER not found in OpsPage.jac";
    ui_order = re.findall(r'"([a-z_]+)"', m.group(1));
    backend = _backend_probe_names();
    missing = [
        s
        for s in backend
        if s not in ui_order
    ];
    stale = [
        s
        for s in ui_order
        if s not in backend
    ];
    assert not missing , f"backend signals invisible in the ops page: {missing}";
    assert not stale , f"ops page iterates signals the backend never emits: {stale}";
}


test "ops page labels cover the signal order" {
    src = _ops_page_source();
    m = re.search(r'SIGNAL_LABELS\s*=\s*\{([^}]*)\}', src);
    assert m , "SIGNAL_LABELS not found in OpsPage.jac";
    labeled = re.findall(r'"([a-z_]+)":', m.group(1));
    for name in BACKEND_SIGNALS {
        assert name in labeled , f"signal {name!r} has no display label";
    }
}


test "backend probe list matches the pinned contract" {
    assert _backend_probe_names() == BACKEND_SIGNALS;
}
