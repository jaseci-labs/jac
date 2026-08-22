"""P2 corpus Tier-B density ratchet on committed lift output."""

import json;
import os;
import from tests.support { JAC_ROOT }

glob REPO_ROOT: str = os.path.dirname(JAC_ROOT),
     MANIFEST_PATH: str = os.path.join(
         REPO_ROOT, "jac-py", "tools", "p2_corpus", "manifest.json"
     ),
     BASELINE_PATH: str = os.path.join(
         REPO_ROOT,
         "jac-py",
         "tools",
         "p2_corpus",
         "baseline",
         "project.c2jac.report.json"
     ),
     MAX_DENSITY: float = 0.15;


def _load_json(path: str) -> dict {
    with open(path) as f {
        return json.load(f);
    }
}

def _jac_loc(path: str) -> int {
    count = 0;
    with open(path) as f {
        for line in f {
            stripped = line.strip();
            if (not stripped) or stripped.startswith("#") {
                continue;
            }
            count += 1;
        }
    }
    return count;
}


test "P2 corpus: committed lift tier_b_total does not exceed baseline" {
    manifest = _load_json(MANIFEST_PATH);
    aggregate_path = os.path.join(
        REPO_ROOT, manifest["lift_output"], "project.c2jac.report.json"
    );
    baseline = _load_json(BASELINE_PATH);
    current = _load_json(aggregate_path);
    assert len(current["files"] as list) >= 10 , current;
    assert (current["tier_b_total"] as int) <= (baseline["tier_b_total"] as int) , (
        f"Tier-B regressed: {current['tier_b_total']} > baseline {baseline[
            'tier_b_total'
        ]}"
    );
}

test "P2 corpus: committed lift Tier-B density stays below 15%" {
    manifest = _load_json(MANIFEST_PATH);
    aggregate_path = os.path.join(
        REPO_ROOT, manifest["lift_output"], "project.c2jac.report.json"
    );
    current = _load_json(aggregate_path);
    tier_b_total = current["tier_b_total"] as int;
    total_loc = 0;
    for row in (current["files"] as list) {
        total_loc += _jac_loc(os.path.join(REPO_ROOT, row["output"]));
    }
    density = (tier_b_total / total_loc) if total_loc else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
}
