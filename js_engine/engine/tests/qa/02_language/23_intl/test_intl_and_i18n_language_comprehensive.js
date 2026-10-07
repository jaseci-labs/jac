// INTL_AND_I18N_COMPREHENSIVE_TEST_PLAN.md — INTL-* (ECMA-402 surface)

var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/23_intl/test_intl_and_i18n_language_comprehensive.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertThrows(fn, ErrType, msg) { __reg.assertThrows(fn, ErrType, msg); }

if (typeof Intl === "undefined" || typeof Intl.Collator !== "function") {
    console.log("SKIP: Intl not available");
    __jacDone();
}

// --- §1 Intl globals (INTL-G-*) ---

(function intlG001() {
    var c = Intl.getCanonicalLocales("EN-us");
    assert(Array.isArray(c) && c.length >= 1, "INTL-G-001: getCanonicalLocales returns array");
    assertEq(String(c[0]).toLowerCase(), "en-us", "INTL-G-001: canonicalizes casing");
    assertThrows(
        function () {
            Intl.getCanonicalLocales("this_is_not_a_valid_bcp47_tag_xx");
        },
        RangeError,
        "INTL-G-001: invalid locale tag throws RangeError"
    );
})();

(function intlG002() {
    if (typeof Intl.supportedValuesOf !== "function") {
        return;
    }
    var cal = Intl.supportedValuesOf("calendar");
    assert(Array.isArray(cal) && cal.length > 0, "INTL-G-002: supportedValuesOf calendar is non-empty array");
    assert(typeof cal[0] === "string", "INTL-G-002: calendar entries are strings");
})();

(function intlG003() {
    if (typeof Intl.Locale === "undefined") {
        return;
    }
    var loc = new Intl.Locale("en-US");
    assertEq(typeof loc.language, "string", "INTL-G-003: Locale.language");
    assert(loc.language.length > 0, "INTL-G-003: language non-empty");
    if (typeof loc.maximize === "function") {
        var mx = loc.maximize().toString();
        assert(mx.length >= loc.toString().length, "INTL-G-003: maximize expands or keeps locale");
    }
})();

// --- §2 Collator (INTL-C-*) ---

(function intlC001() {
    var cDefault = new Intl.Collator("en", { numeric: false });
    var cNum = new Intl.Collator("en", { numeric: true });
    var cmpDef = cDefault.compare("10", "2");
    var cmpNum = cNum.compare("10", "2");
    assert(cmpDef < 0, "INTL-C-001: non-numeric collation orders 10 before 2 lexicographically");
    assert(cmpNum > 0, "INTL-C-001: numeric collation orders 10 after 2");
})();

(function intlC002() {
    var c = new Intl.Collator("de", { sensitivity: "base", usage: "sort" });
    var ro = c.resolvedOptions();
    assertEq(ro.usage, "sort", "INTL-C-002: resolved usage");
    assertEq(ro.sensitivity, "base", "INTL-C-002: resolved sensitivity");
    assertEq(ro.numeric, false, "INTL-C-002: resolved numeric default");
})();

// --- §3 DateTimeFormat (INTL-D-*) ---

(function intlD001() {
    var d = new Date(Date.UTC(2024, 5, 15, 12, 0, 0));
    var dtf = new Intl.DateTimeFormat("en-CA", {
        timeZone: "UTC",
        year: "numeric",
        month: "2-digit",
        day: "2-digit"
    });
    var s = dtf.format(d);
    assert(typeof s === "string" && s.length > 0, "INTL-D-001: format returns non-empty string");
    var parts = dtf.formatToParts(d);
    assert(Array.isArray(parts) && parts.length > 0, "INTL-D-001: formatToParts returns array");
    var types = {};
    for (var i = 0; i < parts.length; i++) {
        types[parts[i].type] = true;
    }
    assert(types.year || types.month || types.day, "INTL-D-001: formatToParts includes date fields");
    if (typeof dtf.formatRange === "function") {
        var d2 = new Date(Date.UTC(2024, 5, 16, 0, 0, 0));
        var r = dtf.formatRange(d, d2);
        assert(typeof r === "string" && r.length > 0, "INTL-D-001: formatRange returns string");
    }
})();

(function intlD002() {
    var d = new Date(Date.UTC(2024, 0, 15, 18, 30, 0));
    var fmtUtc = new Intl.DateTimeFormat("en-US", {
        timeZone: "UTC",
        hour: "numeric",
        hour12: false
    });
    var fmtNy = new Intl.DateTimeFormat("en-US", {
        timeZone: "America/New_York",
        hour: "numeric",
        hour12: false
    });
    var hUtc = parseInt(fmtUtc.formatToParts(d).filter(function (p) {
        return p.type === "hour";
    })[0].value, 10);
    var hNy = parseInt(fmtNy.formatToParts(d).filter(function (p) {
        return p.type === "hour";
    })[0].value, 10);
    assert(
        hUtc !== hNy || fmtUtc.format(d) !== fmtNy.format(d),
        "INTL-D-002: UTC vs America/New_York affects hour or formatted output"
    );
})();

(function intlD003() {
    var dtf = new Intl.DateTimeFormat("en-GB", {
        hourCycle: "h23",
        calendar: "gregory"
    });
    var ro = dtf.resolvedOptions();
    assertEq(ro.calendar, "gregory", "INTL-D-003: resolved calendar");
    if (ro.hourCycle) {
        assert(ro.hourCycle === "h23" || ro.hourCycle === "h24", "INTL-D-003: hourCycle reflected");
    }
})();

// --- §4 NumberFormat (INTL-N-*) ---

(function intlN001() {
    var dec = new Intl.NumberFormat("en-US", { style: "decimal" });
    assertEq(dec.format(1234.5), "1,234.5", "INTL-N-001: decimal style grouping");
    var pct = new Intl.NumberFormat("en-US", { style: "percent" });
    assert(pct.format(0.5).indexOf("%") !== -1, "INTL-N-001: percent style includes percent sign");
    var cur = new Intl.NumberFormat("en-US", {
        style: "currency",
        currency: "USD",
        currencyDisplay: "symbol"
    });
    assert(cur.format(12.34).indexOf("$") !== -1, "INTL-N-001: currency symbol present");
})();

(function intlN002() {
    var nf = new Intl.NumberFormat("en-US", {
        style: "currency",
        currency: "EUR",
        currencyDisplay: "code"
    });
    var parts = nf.formatToParts(99.1);
    var hasCurrency = false;
    var hasInteger = false;
    for (var i = 0; i < parts.length; i++) {
        if (parts[i].type === "currency") {
            hasCurrency = true;
        }
        if (parts[i].type === "integer") {
            hasInteger = true;
        }
    }
    assert(hasCurrency, "INTL-N-002: formatToParts includes currency segment");
    assert(hasInteger, "INTL-N-002: formatToParts includes integer segment");
})();

(function intlN003() {
    var supported = Intl.NumberFormat.supportedLocalesOf(["en-XX", "en-US", "de-DE"]);
    assert(Array.isArray(supported), "INTL-N-003: supportedLocalesOf returns array");
    assert(supported.indexOf("en-US") !== -1 || supported.length >= 1, "INTL-N-003: en-US or fallback");
})();

(function intlN004() {
    if (
        typeof Intl.NumberFormat !== "function" ||
        !Intl.NumberFormat.prototype.formatToParts
    ) {
        return;
    }
    try {
        var nf = new Intl.NumberFormat("en", { notation: "compact" });
        var s = nf.format(1500);
        assert(typeof s === "string" && s.length > 0, "INTL-N-004: compact notation formats");
    } catch (e) {
        // optional
    }
})();

// --- §5 ListFormat (INTL-L-*) ---

(function intlL001() {
    if (typeof Intl.ListFormat === "undefined") {
        return;
    }
    var conj = new Intl.ListFormat("en", { type: "conjunction", style: "long" });
    var s1 = conj.format(["a", "b", "c"]);
    assert(s1.indexOf("and") !== -1, "INTL-L-001: conjunction uses and");
    var dis = new Intl.ListFormat("en", { type: "disjunction", style: "long" });
    var s2 = dis.format(["x", "y"]);
    assert(s2.indexOf("or") !== -1, "INTL-L-001: disjunction uses or");
    var unit = new Intl.ListFormat("en", { type: "unit", style: "short" });
    var s3 = unit.format(["3 km", "5 km"]);
    assert(typeof s3 === "string" && s3.length > 0, "INTL-L-001: unit list formats");
})();

// --- §6 PluralRules (INTL-P-*) ---

(function intlP001() {
    if (typeof Intl.PluralRules === "undefined") {
        return;
    }
    var en = new Intl.PluralRules("en");
    var cat1 = en.select(1);
    var cat2 = en.select(2);
    var allowed = { zero: 1, one: 1, two: 1, few: 1, many: 1, other: 1 };
    assert(allowed[cat1], "INTL-P-001: en select(1) is valid category");
    assert(allowed[cat2], "INTL-P-001: en select(2) is valid category");
    var ar = new Intl.PluralRules("ar");
    var ar0 = ar.select(0);
    assert(allowed[ar0], "INTL-P-001: ar select(0) valid category");
})();

// --- §7 RelativeTimeFormat (INTL-R-*) ---

(function intlR001() {
    if (typeof Intl.RelativeTimeFormat === "undefined") {
        return;
    }
    var rtf = new Intl.RelativeTimeFormat("en", { numeric: "auto" });
    var past = rtf.format(-1, "day");
    var fut = rtf.format(1, "hour");
    assert(typeof past === "string" && past.length > 0, "INTL-R-001: negative value formats");
    assert(typeof fut === "string" && fut.length > 0, "INTL-R-001: positive hour formats");
    assertThrows(
        function () {
            rtf.format(1, "not-a-unit");
        },
        RangeError,
        "INTL-R-001: invalid unit throws RangeError"
    );
})();

// --- §8 DisplayNames (INTL-Y-*) optional ---

(function intlY001() {
    if (typeof Intl.DisplayNames === "undefined") {
        return;
    }
    var dn = new Intl.DisplayNames(["en"], { type: "region" });
    var us = dn.of("US");
    assert(typeof us === "string" && us.length > 0, "INTL-Y-001: region display name");
    var dnL = new Intl.DisplayNames(["en"], { type: "language" });
    assert(typeof dnL.of("de") === "string", "INTL-Y-001: language display name");
    var scr = new Intl.DisplayNames(["en"], { type: "script" });
    var latn = scr.of("Latn");
    if (latn !== undefined) {
        assert(typeof latn === "string", "INTL-Y-001: script label when present");
    }
})();

// --- §9 Segmenter (INTL-S-*) optional ---

(function intlS001() {
    if (typeof Intl.Segmenter === "undefined") {
        return;
    }
    var seg = new Intl.Segmenter("en", { granularity: "grapheme" });
    var text = "a\u0300";
    var it = seg.segment(text)[Symbol.iterator]();
    var first = it.next();
    assert(!first.done, "INTL-S-001: segmenter yields segment");
    assert(typeof first.value.segment === "string", "INTL-S-001: segment string");
    var segEmoji = new Intl.Segmenter("en", { granularity: "grapheme" });
    var zwj = "👨\u200d👩\u200d👧";
    var parts = Array.from(segEmoji.segment(zwj), function (x) {
        return x.segment;
    });
    assert(parts.length >= 1, "INTL-S-001: ZWJ string produces segments");
})();

// --- Optional DurationFormat ---

(function intlDurationOptional() {
    if (typeof Intl.DurationFormat === "undefined") {
        return;
    }
    var df = new Intl.DurationFormat("en");
    var out = df.format({ hours: 1, minutes: 2 });
    assert(typeof out === "string" && out.length > 0, "INTL optional: DurationFormat formats");
})();

__jacDone();
