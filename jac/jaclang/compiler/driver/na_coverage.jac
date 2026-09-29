import os;
import sys;

glob _na_coverage: dict[str, dict[str, any]] = {},
     _na_coverage_state: dict[str, bool] = {"enabled": False};

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
    if reason not in rec['seams'] {
        rec['seams'].append(reason);
    }
}

def na_coverage_capture(path: str) -> dict[str, any] {
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

def na_coverage_replay(path: str, rec: dict[str, any]) {
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

def na_coverage_end -> dict[str, dict[str, any]] {
    snap = dict(_na_coverage);
    _na_coverage_state["enabled"] = False;
    return snap;
}
