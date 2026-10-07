"use strict";

/**
 * Canonical completion marker for regression suites.
 * run_reg.jac must treat output as incomplete if this substring is missing.
 */
var REGRESSION_TESTCASE_FINISHED = "REGRESSION_TESTCASE_FINISHED";

/**
 * @param {string} suiteName — stable id, typically "regression/…/test_foo.js"
 */
function createTestCase(suiteName) {
  var failures = 0;

  function bump() {
    failures++;
  }

  function fail(msg) {
    bump();
    if (msg != null && msg !== "") {
      console.error("FAIL: " + msg);
    }
  }

  function finalize(origExit) {
    var n = failures;
    console.log(
      REGRESSION_TESTCASE_FINISHED +
        " name=" +
        JSON.stringify(String(suiteName)) +
        " failures=" +
        n
    );
    var code = n > 255 ? 255 : n;
    if (typeof origExit === "function") {
      origExit(code);
    } else {
      process.exit(code);
    }
  }

  return {
    REGRESSION_TESTCASE_FINISHED: REGRESSION_TESTCASE_FINISHED,
    bump: bump,
    fail: fail,
    finalize: finalize,
    assert: function (cond, msg) {
      if (!cond) {
        fail(msg || "assertion failed");
      }
    },
    assertEq: function (actual, expected, msg) {
      if (actual !== expected) {
        fail(
          (msg || "") +
            " | expected: " +
            JSON.stringify(expected) +
            " | actual: " +
            JSON.stringify(actual)
        );
      }
    },
    assertDeep: function (actual, expected, msg) {
      var as = JSON.stringify(actual);
      var es = JSON.stringify(expected);
      if (as !== es) {
        fail((msg || "") + " | expected: " + es + " | actual: " + as);
      }
    },
    assertThrows: function (fn, ErrType, msg) {
      try {
        fn();
        fail((msg || "") + " (no error thrown)");
      } catch (e) {
        if (!(e instanceof ErrType)) {
          fail((msg || "") + " (wrong error: " + e + ")");
        }
      }
    },
    assertThrowsTypeError: function (fn, msg) {
      var threw = false;
      try {
        fn();
      } catch (err) {
        threw = err instanceof TypeError;
      }
      if (!threw) {
        fail(msg || "expected TypeError");
      }
    },
    ok: function (cond, msg) {
      if (!cond) {
        fail(msg || "ok failed");
      }
    },
    check: function (fn, msg) {
      try {
        fn();
      } catch (e) {
        fail((msg || "") + " threw: " + e.message);
      }
    },
    checkThrows: function (fn, msg) {
      var threw = false;
      try {
        fn();
      } catch (e) {
        threw = true;
      }
      if (!threw) {
        fail((msg || "") + " (expected throw)");
      }
    },
    getFailureCount: function () {
      return failures;
    },
  };
}

/** True when run_reg.jac selected js_engine, not system node. */
function isJacEngineRunner() {
  var runner = process.env.JAC_JS_RUNNER || "";
  return runner.indexOf("js_engine") !== -1;
}

module.exports = {
  REGRESSION_TESTCASE_FINISHED: REGRESSION_TESTCASE_FINISHED,
  createTestCase: createTestCase,
  isJacEngineRunner: isJacEngineRunner,
};
