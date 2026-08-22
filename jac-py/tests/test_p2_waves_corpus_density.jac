"""Consolidated corpus Tier-B ratchets for P2 waves 2-11."""

import json;
import os;
import from tests.support { JAC_ROOT }

glob REPO_ROOT: str = os.path.dirname(JAC_ROOT),
     TESTS: str = os.path.join(REPO_ROOT, "jac-py", "tests");


def _wave_number(path: str) -> int {
    name = os.path.basename(path);
    return int(name.split("wave")[1].split(".")[0]);
}


def _manifest_paths() -> list {
    paths: list = [];
    for name in os.listdir(TESTS) {
        if name.startswith("conformance_manifest_wave") and name.endswith(".json") {
            paths.append(os.path.join(TESTS, name));
        }
    }
    for i in range(len(paths)) {
        min_i = i;
        for j in range(i + 1, len(paths)) {
            if _wave_number(paths[j]) < _wave_number(paths[min_i]) {
                min_i = j;
            }
        }
        if min_i != i {
            tmp = paths[i];
            paths[i] = paths[min_i];
            paths[min_i] = tmp;
        }
    }
    return paths;
}


def _load_json(path: str) -> dict {
    with open(path) as f {
        return json.load(f);
    }
}


def _expected_stems(wave: int) -> list {
    if wave == 2 {
        return ["_opcode", "_stat", "math_gcd", "pystrnicmp"];
    }
    if wave == 3 {
        return ["math_count_bits", "math_lcm_long", "pyctype_digit", "strhex_byte"];
    }
    if wave == 4 {
        return ["math_factorial_small", "pyctype_alpha", "pyctype_space", "pystricmp"];
    }
    if wave == 5 {
        return ["math_isqrt_small", "pyctype_alnum", "pyctype_lower", "pyctype_xdigit"];
    }
    if wave == 6 {
        return ["math_pow2_check", "pyctype_print", "pyctype_punct", "pyctype_upper"];
    }
    if wave == 7 {
        return ["math_ilog2_small", "pyctype_blank", "pyctype_cntrl", "pyctype_graph"];
    }
    if wave == 8 {
        return ["math_abs_diff", "math_clz32_small", "math_ctz_small", "math_min_u"];
    }
    if wave == 9 {
        return ["math_max_u", "pystr_count_char", "pystr_find_char", "pystr_len_c"];
    }
    if wave == 10 {
        return ["math_gcd_iter", "math_lcm_u", "pystr_endswith_c", "pystr_startswith_c"];
    }
    if wave == 11 {
        return ["math_popcount_u", "math_pow_mod", "pystr_cmp_c", "pystr_contains_c"];
    }
    return [];
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


def _check_wave(wave: int) -> str {
    try {
        corpus_dir = os.path.join(REPO_ROOT, "jac-py", "tools", f"p2_corpus_wave{wave}");
        manifest = _load_json(os.path.join(corpus_dir, "manifest.json"));
        baseline = _load_json(
            os.path.join(corpus_dir, "baseline", "project.c2jac.report.json")
        );
        current_path = os.path.join(
            REPO_ROOT, manifest["lift_output"], "project.c2jac.report.json"
        );
        current = _load_json(current_path);
        assert len(manifest["files"] as list) == 4;
        assert len(current["files"] as list) == 4, current;
        assert (current["tier_b_total"] as int) <= (baseline["tier_b_total"] as int), (
            f"Tier-B regressed: {current['tier_b_total']} > baseline {baseline['tier_b_total']}"
        );
        if wave <= 3 {
            total_loc = 0;
            for row in (current["files"] as list) {
                total_loc += _jac_loc(os.path.join(REPO_ROOT, row["output"]));
            }
            density = (current["tier_b_total"] as int) / total_loc if total_loc else 0.0;
            assert density < 0.15, f"density {density:.6f} >= 0.15";
        }
        return "";
    } except Exception as e {
        return f"wave {wave}: corpus ratchet failed: {e}";
    }
}


test "P2 waves 2-11 corpus density ratchets" {
    failures: list = [];
    paths = _manifest_paths();
    assert len(paths) > 0, "no conformance wave manifests found";
    for path in paths {
        wave = _wave_number(path);
        error = _check_wave(wave);
        if error {
            print(f"wave {wave}: FAIL");
            failures.append(error);
        } else {
            if wave <= 3 {
                print(f"wave {wave}: PASS (baseline + density checks)");
            } else {
                print(f"wave {wave}: PASS (baseline check)");
            }
        }
    }
    assert not failures, "\n".join(failures);
}
