import os;

obj CoverageRecord {
    has outcome: str = 'native',
        code: str = '',
        detail: str = '',
        seams: list[str] = [],
        late: int = 0;

    def as_dict -> dict[str, any] {
        return {
            'outcome': self.outcome,
            'code': self.code,
            'detail': self.detail,
            'seams': list(self.seams),
            'late': self.late
        };
    }
}

glob _na_coverage: dict[str, CoverageRecord] = {},
     _na_coverage_state: dict[str, bool] = {"enabled": False},
     _STICKY_OUTCOMES: frozenset[str] = frozenset(['demoted']);

def _replayed_text(rec: dict[str, any], key: str, fallback: str) -> str {
    held = rec.get(key);
    if isinstance(held, str) and held {
        return held;
    }
    return fallback;
}

def na_coverage_begin {
    _na_coverage.clear();
    _na_coverage_state["enabled"] = True;
}

def na_coverage_record(path: str, outcome: str, code: str = '', detail: str = '') {
    if not _na_coverage_state["enabled"] or not path {
        return;
    }
    key = os.path.realpath(path);
    prev = _na_coverage.get(key);
    if prev is not None
        and prev.outcome in _STICKY_OUTCOMES
        and outcome not in _STICKY_OUTCOMES {
        return;
    }
    seams: list[str] = prev.seams if prev is not None else [];
    _na_coverage[key] = CoverageRecord(
        outcome=outcome,
        code=code,
        detail=detail,
        seams=seams,
        late=prev.late if prev is not None else 0
    );
}

def na_coverage_seam(path: str, reason: str, late: bool = False) {
    if not _na_coverage_state["enabled"] or not path {
        return;
    }
    key = os.path.realpath(path);
    rec = _na_coverage.get(key);
    if rec is None {
        rec = CoverageRecord(outcome='native', code='', detail='', seams=[]);
        _na_coverage[key] = rec;
    }
    if reason not in rec.seams {
        rec.seams.append(reason);
        if late {
            rec.late += 1;
        }
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
    return rec.as_dict();
}

def na_coverage_replay(path: str, rec: dict[str, any]) {
    if not _na_coverage_state["enabled"] or not path or not rec {
        return;
    }
    key = os.path.realpath(path);
    if key in _na_coverage {
        return;
    }
    seams: list[str] = [];
    held = rec.get('seams');
    if isinstance(held, `list) {
        for item in held {
            if isinstance(item, str) {
                seams.append(item);
            }
        }
    }
    replayed_late = rec.get('late');
    late: int = replayed_late if isinstance(replayed_late, int) else 0;
    _na_coverage[key] = CoverageRecord(
        outcome=_replayed_text(rec, 'outcome', 'native'),
        code=_replayed_text(rec, 'code', ''),
        detail=_replayed_text(rec, 'detail', ''),
        seams=seams,
        late=late
    );
}

def na_coverage_snapshot -> dict[str, dict[str, any]] {
    snap: dict[str, dict[str, any]] = {};
    for (key, rec) in _na_coverage.items() {
        snap[key] = rec.as_dict();
    }
    return snap;
}

def na_coverage_end -> dict[str, dict[str, any]] {
    snap = na_coverage_snapshot();
    _na_coverage_state["enabled"] = False;
    return snap;
}
