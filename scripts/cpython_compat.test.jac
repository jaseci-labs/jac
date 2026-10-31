"""Exercise the regrtest result parsing and the stock-vs-JacPython comparison."""

glob PASSED_LOG: str = """0:00:00 load avg: 2.0 [1/1] test_bool passed

== Tests result: SUCCESS ==

1 test OK.

Total tests: run=31
Total test files: run=1/1
Result: SUCCESS
""",
     SKIPPED_LOG: str = """0:00:00 load avg: 2.0 [1/1] test_winreg skipped
test_winreg skipped -- No module named 'winreg'

1 test skipped:
    test_winreg

Total test files: run=1/1 skipped=1
Result: SUCCESS
""",
     DENIED_LOG: str = """0:00:00 load avg: 2.0 [1/1] test_urllib2net skipped (resource denied)
test_urllib2net skipped -- Use of the 'network' resource not enabled

Total test files: run=0/1 resource_denied=1
Result: NO TESTS RAN
""",
     CRASHED_LOG: str = """0:00:00 load avg: 2.0 [1/1/1] test_x worker non-zero exit code (Exit code -11 (SIGSEGV))
Re-running test_x in verbose mode
0:00:01 load avg: 2.0 [1/1/1] test_x worker non-zero exit code (Exit code -11 (SIGSEGV))

Total test files: run=2/1 failed=1 rerun=1
Result: FAILURE then FAILURE
""",
     FLAKY_LOG: str = """0:00:00 load avg: 2.0 [1/1/1] test_x failed (1 failure)
Re-running test_x in verbose mode
0:00:01 load avg: 2.0 [1/1] test_x passed

Total test files: run=2/1 rerun=1
Result: FAILURE then SUCCESS
""",
     TIMED_OUT_LOG: str = """0:20:00 load avg: 2.0 [1/1/1] test_x timed out (20 min)

Total test files: run=2/1 failed=1 rerun=1
Result: FAILURE then FAILURE
""";

test "regrtest's summary decides a module's state" {
    assert module_state(PASSED_LOG, 0, 60) == ("passed", "");
    assert module_state(SKIPPED_LOG, 0, 60) == ("skipped", "No module named 'winreg'");
    assert module_state(DENIED_LOG, 0, 60)[0] == "denied";
    assert module_state(CRASHED_LOG, 2, 60)
        == ("crashed", "worker non-zero exit code (Exit code -11 (SIGSEGV))");
    assert module_state(FLAKY_LOG, 0, 60) == ("flaky", "failed (1 failure)");
    assert module_state(TIMED_OUT_LOG, 2, 60) == ("timeout", "timed out (20 min)");
}

test "a run without a result is a dead or killed module" {
    assert module_state("Fatal Python error: Aborted\n", -6, 60)[0] == "died";
    assert module_state(PASSED_LOG, None, 60) == ("timeout", "no result after 60s");
}

test "the last junit record of a test is its outcome" {
    junit = """<testsuites><testsuite>
<testcase name="test.test_x.T.test_flaky"><failure type="AssertionError" message="AssertionError: first&#10;">tb</failure></testcase>
<testcase name="test.test_x.T.test_bad"><error type="OSError" message="OSError: boom">tb</error></testcase>
<testcase name="test.test_x.T.test_skip"><skipped>needs a GPU</skipped></testcase>
<testcase name="test.test_x.T.test_xfail"><output type="AssertionError" message="m">tb</output></testcase>
<testcase name="test.test_x.T.test_xpass"><outcome>UNEXPECTED_SUCCESS</outcome></testcase>
</testsuite><testsuite>
<testcase name="test.test_x.T.test_flaky" />
</testsuite></testsuites>""";
    assert parse_junit(junit)
        == {
            "test.test_x.T.test_flaky": ("passed", ""),
            "test.test_x.T.test_bad": ("error", "OSError: boom"),
            "test.test_x.T.test_skip": ("skipped", "needs a GPU"),
            "test.test_x.T.test_xfail": ("xfail", ""),
            "test.test_x.T.test_xpass": ("xpass", "")
        };
}

def results(jacpython: bool, modules: dict[str, any]) -> dict[str, any] {
    return {
        "label": "jacpython" if jacpython else "cpython",
        "version": "3.14.6",
        "jacpython": jacpython,
        "resources": "",
        "modules": modules
    };
}

test "only what stock CPython passes counts against JacPython" {
    stock = results(
        False,
        {
            "test_a": {
                "state": "passed",
                "detail": "",
                "cases": {"a.ok": ["passed", ""], "a.gone": ["passed", ""]}
            },
            "test_b": {
                "state": "failed",
                "detail": "env",
                "cases": {"b.x": ["failed", ""]}
            },
            "test_c": {"state": "passed", "detail": "", "cases": {}},
            "test_d": {"state": "failed", "detail": "env", "cases": {}},
            "test_e": {
                "state": "passed",
                "detail": "",
                "cases": {"e.x": ["passed", ""]}
            }
        }
    );
    jac = results(
        True,
        {
            "test_a": {
                "state": "failed",
                "detail": "failed (1 failure)",
                "cases": {
                    "a.ok": ["failed", "AssertionError"],
                    "a.gone": ["skipped", "no"]
                }
            },
            "test_b": {
                "state": "failed",
                "detail": "env",
                "cases": {"b.x": ["failed", ""]}
            },
            "test_c": {
                "state": "skipped",
                "detail": "No module named '_x'",
                "cases": {}
            },
            "test_d": {"state": "passed", "detail": "", "cases": {}},
            "test_e": {
                "state": "flaky",
                "detail": "",
                "cases": {"e.x": ["skipped", "why"]}
            }
        }
    );
    found = compare_results(stock, jac);
    assert [row[0] for row in found["module_regressions"]] == ["test_a"];
    assert [row[0] for row in found["modules_not_run"]] == ["test_c"];
    assert [row[0] for row in found["case_regressions"]] == ["a.ok"];
    # test_a failed outright, so its skipped test is not reported twice.
    assert [row[0] for row in found["cases_not_run"]] == ["e.x"];
    assert [row[0] for row in found["broken_on_both"]] == ["test_b"];
    assert [row[0] for row in found["fixed_on_jacpython"]] == ["test_d"];
    assert [row[0] for row in found["flaky_on_jacpython"]] == ["test_e"];
    assert "4 incompatibilities" in render(stock, jac, found);
}

test "a difference JacPython makes by decision is reported, not counted" {
    stock = results(
        False, {"test_remote_pdb": {"state": "passed", "detail": "", "cases": {}}}
    );
    jac = results(
        True,
        {
            "test_remote_pdb": {
                "state": "skipped",
                "detail": "remote debugging is disabled",
                "cases": {}
            }
        }
    );
    found = compare_results(stock, jac);
    assert not found["modules_not_run"];
    assert found["intended"]
        == [["test_remote_pdb", "skipped", "remote debugging is not built", "passed"]];
    assert "**compatible" in render(stock, jac, found);
}
