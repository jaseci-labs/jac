"""Partial Lib/test-style checks for P2 modules with stdlib algorithm mirrors.

Host leg: validates bisect/heapq/platform behavior on host CPython.
Jac differential leg: runs checked-in ``Modules/*.jac`` via ``jac run`` when
``can_run_jac_differential`` passes (see ``libtest_runner.jac``).
JacPython leg: runs embedded Python snippets via ``layer_p2_libtest`` shims.
"""

import from tests.jacpy.libtest_runner {
    run_libtest_host,
    run_libtest_jac_differential,
    run_libtest_jacpython,
    can_run_jac_differential,
    can_run_jacpython_libtest
}
import from tests.jacpy.libtest_snippets { LIBTEST_SNIPPETS, LibtestSnippet }


def assert_host_matches_cpython(host_case: LibtestSnippet) {
    (ok, detail) = run_libtest_host(host_case);
    assert ok , f"{host_case.module_stem}/{host_case.name}: {detail}";
}


def assert_jac_differential(host_case: LibtestSnippet) -> None {
    (status, detail) = run_libtest_jac_differential(host_case);
    if status == "skip" {
        return;
    }
    assert status == "pass" , (
        f"{host_case.module_stem}/{host_case.name} jac differential: {detail}"
    );
}


test "P2 libtest partial: bisect precomputed cases match host CPython" {
    for host_case in LIBTEST_SNIPPETS {
        if host_case.name != "bisect_precomputed" {
            continue;
        }
        assert_host_matches_cpython(host_case);
    }
}


test "P2 libtest partial: bisect insort matches host CPython" {
    for host_case in LIBTEST_SNIPPETS {
        if host_case.name != "bisect_insort" {
            continue;
        }
        assert_host_matches_cpython(host_case);
    }
}


test "P2 libtest partial: heapq heappush/heappop matches host CPython" {
    for host_case in LIBTEST_SNIPPETS {
        if host_case.name != "heapq_push_pop" {
            continue;
        }
        assert_host_matches_cpython(host_case);
    }
}


test "P2 libtest partial: heapq heapify matches host CPython" {
    for host_case in LIBTEST_SNIPPETS {
        if host_case.name != "heapq_heapify" {
            continue;
        }
        assert_host_matches_cpython(host_case);
    }
}


test "P2 libtest partial: platform basics match host CPython" {
    for host_case in LIBTEST_SNIPPETS {
        if host_case.name != "platform_basic" {
            continue;
        }
        assert_host_matches_cpython(host_case);
    }
}


test "P2 libtest partial: stat filemode matches host CPython" {
    for host_case in LIBTEST_SNIPPETS {
        if host_case.name != "stat_filemode" {
            continue;
        }
        assert_host_matches_cpython(host_case);
    }
}


test "P2 libtest partial: _opcode stack effect matches host CPython" {
    for host_case in LIBTEST_SNIPPETS {
        if host_case.name != "opcode_stack_effect" {
            continue;
        }
        assert_host_matches_cpython(host_case);
    }
}


def assert_jacpython_libtest(host_case: LibtestSnippet) -> None {
    (status, detail) = run_libtest_jacpython(host_case);
    if status == "skip" {
        return;
    }
    assert status == "pass" , (
        f"{host_case.module_stem}/{host_case.name} jacpython libtest: {detail}"
    );
}


test "P2 libtest differential: staged Modules/*.jac when importable" {
    for host_case in LIBTEST_SNIPPETS {
        if not host_case.jac_entry {
            continue;
        }
        if not can_run_jac_differential(host_case.module_stem) {
            continue;
        }
        assert_jac_differential(host_case);
    }
}


test "P2 libtest jacpython: embedded snippets via layer_p2_libtest shims" {
    for host_case in LIBTEST_SNIPPETS {
        if not can_run_jacpython_libtest(host_case) {
            continue;
        }
        assert_jacpython_libtest(host_case);
    }
}
