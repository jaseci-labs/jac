// STRING_COMPREHENSIVE_TEST_PLAN §16, §18 — toString, valueOf, HTML wrappers (deprecated)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/03_string/test_string_tostring_valueof_html.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// STR-V-001
assertEq("hi".toString(), "hi", "STR-V-001: primitive toString");
assertEq("hi".valueOf(), "hi", "STR-V-001: primitive valueOf");
assertEq(new String("hi").toString(), "hi", "STR-V-001: wrapper toString");
assertEq(new String("hi").valueOf(), "hi", "STR-V-001: wrapper valueOf");

// STR-V-002
assertEq(Object.prototype.toString.call(new String("a")), "[object String]", "STR-V-002: Object.prototype.toString");

// STR-H-001 / STR-H-002 / STR-H-003 — HTML wrappers (optional if removed from engine)
function htmlSmoke(name, fn, check) {
    if (typeof fn !== "function") return;
    var out = fn.call("x");
    assert(typeof out === "string", "STR-H-001: " + name + " returns string");
    assert(check(out), "STR-H-001: " + name + " output shape");
}

htmlSmoke("anchor", String.prototype.anchor, function (s) { return s.indexOf("<a ") === 0 && s.indexOf("name=") !== -1; });
htmlSmoke("big", String.prototype.big, function (s) { return s.indexOf("<big>") === 0; });
htmlSmoke("blink", String.prototype.blink, function (s) { return s.indexOf("<blink>") === 0; });
htmlSmoke("bold", String.prototype.bold, function (s) { return s.indexOf("<b>") === 0; });
htmlSmoke("fixed", String.prototype.fixed, function (s) { return s.indexOf("<tt>") === 0; });
htmlSmoke("italics", String.prototype.italics, function (s) { return s.indexOf("<i>") === 0; });
htmlSmoke("small", String.prototype.small, function (s) { return s.indexOf("<small>") === 0; });
htmlSmoke("strike", String.prototype.strike, function (s) { return s.indexOf("<strike>") === 0; });
htmlSmoke("sub", String.prototype.sub, function (s) { return s.indexOf("<sub>") === 0; });
htmlSmoke("sup", String.prototype.sup, function (s) { return s.indexOf("<sup>") === 0; });

if (typeof String.prototype.fontcolor === "function") {
    var fc = "z".fontcolor('"');
    assert(fc.indexOf("&quot;") !== -1 || fc.indexOf("&#34;") !== -1 || fc.indexOf("%22") !== -1 || fc.indexOf("\\\"") !== -1,
        "STR-H-002: fontcolor escapes quote in attribute");
}
if (typeof String.prototype.fontsize === "function") {
    var fs = "z".fontsize('"');
    assert(fs.indexOf("size=") !== -1, "STR-H-002: fontsize attribute present");
}
if (typeof String.prototype.link === "function") {
    var lk = "z".link('"');
    assert(lk.indexOf("href=") !== -1, "STR-H-002: link href present");
}

// STR-H-003 — MDN: can produce invalid HTML
if (typeof String.prototype.bold === "function") {
    var bq = "</b>".bold();
    assert(bq.indexOf("<b>") === 0, "STR-H-003: bold wraps despite content");
}

__jacDone();
