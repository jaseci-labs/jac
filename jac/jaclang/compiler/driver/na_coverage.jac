import os;
import sys;
import jaclang.compiler.frontend.unitree as uni;

glob _na_coverage: dict[str, dict] = {},
     _na_coverage_state: dict[str, bool] = {"enabled": False},
     _na_cap_noted: dict[str, bool] = {};

def na_coverage_begin {
    import from jaclang.compiler.placement.placement_solver { native_scan_memo_clear }
    _na_coverage.clear();
    native_scan_memo_clear();
    _na_coverage_state["enabled"] = True;
}

def na_coverage_record(path: str, outcome: str, code: str = '', detail: str = '') {
    if not _na_coverage_state["enabled"] or not path {
        return;
    }
    key = os.path.realpath(path);
    prev = _na_coverage.get(key);
    sticky = ('demoted', 'ice');
    if prev is not None and prev['outcome'] in sticky and outcome not in sticky {
        return;
    }
    _na_coverage[key] = {
        'outcome': outcome,
        'code': code,
        'detail': detail,
        'seams': (prev['seams'] if prev is not None else [])
    };
}

def na_coverage_seam(path: str, reason: str) {
    if not _na_coverage_state["enabled"] or not path {
        return;
    }
    key = os.path.realpath(path);
    rec = _na_coverage.get(key);
    if rec is None {
        rec = {'outcome': 'native', 'code': '', 'detail': '', 'seams': []};
        _na_coverage[key] = rec;
    }
    rec['seams'].append(reason);
}

def na_coverage_capture(path: str) -> dict {
    if not path {
        return {};
    }
    rec = _na_coverage.get(os.path.realpath(path));
    if rec is None {
        return {};
    }
    return {
        'outcome': rec['outcome'],
        'code': rec['code'],
        'detail': rec['detail'],
        'seams': list(rec['seams'] or [])
    };
}

def na_coverage_replay(path: str, rec: dict) {
    if not _na_coverage_state["enabled"] or not path or not rec {
        return;
    }
    key = os.path.realpath(path);
    if key in _na_coverage {
        return;
    }
    _na_coverage[key] = {
        'outcome': rec.get('outcome') or 'native',
        'code': rec.get('code') or '',
        'detail': rec.get('detail') or '',
        'seams': list(rec.get('seams') or [])
    };
}

def na_coverage_end -> dict {
    snap = dict(_na_coverage);
    _na_coverage_state["enabled"] = False;
    return snap;
}

def na_demotion_note(
    file_path: str, first_err: str, is_ice: bool
) -> tuple[(str, str)] {
    if is_ice {
        msg = (
            f"warning: {file_path} hit an internal compiler error during "
            + "native lowering and fell back to the server codespace "
            + f"({first_err}); this is a compiler bug -- please report it. "
            + "Set JAC_NATIVE_ICE_RAISE=1 to surface the full traceback."
        );
        return (msg, "yellow");
    }
    msg = (
        f"note: {file_path} preferred native but did not lower; "
        + f"compiled in the server codespace ({first_err})"
    );
    return (msg, "dim");
}

def _drop_demoted_native_bindings(mod: uni.Module, resolved: str) {
    import from jaclang.compiler.frontend.codeinfo { InteropContext, InteropManifest }
    key = os.path.realpath(resolved);
    manifest = mod.gen.interop_manifest;
    if not isinstance(manifest, InteropManifest) or not manifest.bindings {
        return;
    }
    stale = [
        name
        for (name, b) in manifest.bindings.items()
        if (
            b.source_context == InteropContext.NATIVE
            and b.source_module
            and os.path.realpath(b.source_module) == key
        )
    ];
    for name in stale {
        manifest.bindings.pop(name, None);
    }
}

def _note_native_closure_cap(root_path: str, cap: int) {
    rp = os.path.realpath(root_path);
    if rp in _na_cap_noted {
        return;
    }
    _na_cap_noted[rp] = True;
    try {
        import from jaclang.cli.console { console }
        console.print(
            f"note: {root_path} preferred native but its import closure "
            f"exceeded the inference cap ({cap} modules); compiled in the "
            f"server codespace. Raise [build] native_closure_cap in jac.toml "
            f"to scan larger closures.",
            style="dim",
            file=sys.stderr
        );
    } except Exception {}
}
