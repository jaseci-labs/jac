impl CoverageRecord.as_dict -> dict[str, any] {
    return {'outcome': self.outcome, 'code': self.code, 'detail': self.detail};
}

impl _replayed_text(rec: dict[str, any], key: str, fallback: str) -> str {
    held = rec.get(key);
    if isinstance(held, str) and held {
        return held;
    }
    return fallback;
}

impl na_coverage_begin {
    _na_coverage.clear();
    _na_coverage_state["enabled"] = True;
}

impl na_coverage_record(path: str, outcome: str, code: str = '', detail: str = '') {
    if not _na_coverage_state["enabled"] or not path {
        return;
    }
    _na_coverage[os.path.realpath(path)] = CoverageRecord(
        outcome=outcome, code=code, detail=detail
    );
}

impl na_coverage_capture(path: str) -> dict[str, any] {
    if not path {
        return {};
    }
    rec = _na_coverage.get(os.path.realpath(path));
    if rec is None {
        return {};
    }
    return rec.as_dict();
}

impl na_coverage_replay(path: str, rec: dict[str, any]) {
    if not _na_coverage_state["enabled"] or not path or not rec {
        return;
    }
    key = os.path.realpath(path);
    if key in _na_coverage {
        return;
    }
    _na_coverage[key] = CoverageRecord(
        outcome=_replayed_text(rec, 'outcome', 'native'),
        code=_replayed_text(rec, 'code', ''),
        detail=_replayed_text(rec, 'detail', '')
    );
}

impl na_coverage_snapshot -> dict[str, dict[str, any]] {
    snap: dict[str, dict[str, any]] = {};
    for (key, rec) in _na_coverage.items() {
        snap[key] = rec.as_dict();
    }
    return snap;
}

impl na_coverage_end -> dict[str, dict[str, any]] {
    snap = na_coverage_snapshot();
    _na_coverage_state["enabled"] = False;
    return snap;
}
