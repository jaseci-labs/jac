import os;

obj CoverageRecord {
    has outcome: str = 'native',
        code: str = '',
        detail: str = '',
        seams: list[str] = [],
        late: int = 0;

    def as_dict -> dict[str, any];
}

glob _na_coverage: dict[str, CoverageRecord] = {},
     _na_coverage_state: dict[str, bool] = {"enabled": False},
     _STICKY_OUTCOMES: frozenset[str] = frozenset(['demoted']);

def _replayed_text(rec: dict[str, any], key: str, fallback: str) -> str;

def na_coverage_begin;

def na_coverage_record(path: str, outcome: str, code: str = '', detail: str = '');

def na_coverage_seam(path: str, reason: str, late: bool = False);

def na_coverage_capture(path: str) -> dict[str, any];

def na_coverage_replay(path: str, rec: dict[str, any]);

def na_coverage_snapshot -> dict[str, dict[str, any]];

def na_coverage_end -> dict[str, dict[str, any]];
