#!/usr/bin/env python3
"""Deep analysis of test262 built-ins failures — refined root-cause clustering + ROI."""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
JS_ENGINE_ROOT = SCRIPT_DIR.parents[2]
TEST262_ROOT = SCRIPT_DIR / "vendor"
TEST_DIR = TEST262_ROOT / "test"
LOG_ROOT = JS_ENGINE_ROOT / "regression_logs" / "test262"


@dataclass
class Issue:
    issue_id: str
    title: str
    category: str
    effort: int
    fix_hint: str
    tests: list[str] = field(default_factory=list)
    samples: list[str] = field(default_factory=list)
    constructors: Counter = field(default_factory=Counter)
    patterns: Counter = field(default_factory=Counter)

    @property
    def count(self) -> int:
        return len(self.tests)

    @property
    def roi(self) -> float:
        return self.count / self.effort if self.effort else float(self.count)


ISSUE_CATALOG: dict[str, tuple[str, str, int, str]] = {
    "FEAT-TEMPORAL": ("Temporal API not implemented", "Missing subsystem", 5,
                      "Implement Temporal namespace (PlainDate, ZonedDateTime, Duration, etc.) or skip until staged"),
    "FEAT-TYPEDARRAY-CTORS": ("TypedArray constructors missing (Uint8Array, etc.)", "Missing subsystem", 5,
                              "Install TypedArray constructors on global object; wire ArrayBuffer views"),
    "FEAT-UINT8CLAMPED": ("Uint8ClampedArray incomplete semantics", "Missing subsystem", 2,
                          "Uint8ClampedArray constructor present; fix remaining prototype/descriptor/clamping tails"),
    "FEAT-ITERATOR-HELPERS": ("Iterator helpers incomplete (flatMap, filter, etc.)", "Missing subsystem", 3,
                              "Iterator.from/reduce/map/toArray/forEach present; expand helpers + IteratorClose semantics"),
    "FEAT-SAB": ("SharedArrayBuffer not defined", "Missing subsystem", 5,
                 "Shared memory + agent model"),
    "FEAT-ATOMICS": ("Atomics not defined", "Missing subsystem", 5,
                     "Requires SharedArrayBuffer; implement Atomics RMW/wait/notify"),
    "FEAT-DISPOSABLES": ("DisposableStack / AsyncDisposableStack not defined", "Missing subsystem", 4,
                         "Implement explicit resource management builtins (ES2024)"),
    "FEAT-SHADOWREALM": ("ShadowRealm not defined", "Missing subsystem", 5,
                         "ShadowRealm proposal infrastructure"),
    "FEAT-WEAKREF-FR": ("WeakRef / FinalizationRegistry not defined", "Missing subsystem", 4,
                        "GC-integrated weak reference APIs"),
    "FEAT-BIGINT-CTORS": ("BigInt64Array / BigUint64Array not defined", "Missing subsystem", 4,
                          "BigInt typed arrays require BigInt + TypedArray substrate"),
    "FEAT-AGGREGATE-ERROR": ("AggregateError / SuppressedError not defined", "Missing subsystem", 3,
                             "Add AggregateError constructor; SuppressedError for disposables"),
    "ASYNC-DONE": ("Async harness: $DONE / asyncTest flag not wired", "Infrastructure", 4,
                   "Implement test262 $DONE callback and microtask draining in harness"),
    "ASYNC-FLAG": ("asyncTest() called without async flag in frontmatter path", "Infrastructure", 3,
                   "Either wire async flag support or fix tests incorrectly using asyncTest sync"),
    "PROP-DESC-ENUM": ("Native property descriptor: enumerable must be false", "Property descriptors", 2,
                       "Audit Object.defineProperty / native_create — set enumerable:false on data props"),
    "PROP-DESC-GENERIC": ("Property descriptor mismatch (prop-desc.js)", "Property descriptors", 2,
                          "Systematic getOwnPropertyDescriptor audit for all native builtins"),
    "PROP-DESC-CFG": ("Property descriptor: configurable/writable wrong", "Property descriptors", 2,
                      "Match spec tables for [[Configurable]] / [[Writable]] on native properties"),
    "FUNC-LENGTH": ("Native function missing .length own property", "Native introspection", 2,
                    "Install {length:N} own property in js_native_create for all builtin methods"),
    "NOT-CONSTRUCTOR": ("Builtin method incorrectly constructible or blocked", "Builtin wiring", 2,
                        "Fix _vm_is_constructor whitelist / [[Construct]] internal method"),
    "NOT-A-FUNCTION": ("Missing or non-callable builtin method", "Missing method", 3,
                       "Install prototype method on correct object; ensure CALLABLE"),
    "UNDEF-PROP": ("Cannot read property of undefined", "Missing method", 3,
                   "Complete prototype chain installation for builtin"),
    "ASSERT-SAMEVALUE": ("Wrong computed value (assert.sameValue)", "Semantic bug", 3,
                         "Fix algorithm for specific builtin — see sample messages"),
    "THROW-NONE": ("Expected exception not thrown", "Spec compliance", 2,
                   "Add missing validation / TypeError / RangeError throw paths"),
    "THROW-WRONG-TYPE": ("Expected TypeError/RangeError but got ReferenceError", "Spec compliance", 2,
                         "Builtin exists but throws ReferenceError instead of TypeError — install stub that throws"),
    "CROSS-REALM": ("Cross-realm prototype identity (proto-from-ctor-realm)", "Realms", 4,
                    "Per-realm %Constructor% in realm_bootstrap (mirror Array fix)"),
    "REGEXP-ENGINE": ("RegExp semantics / property escapes / unicode", "RegExp", 4,
                      "PCRE2 unicode property escapes; fix /u /v flag handling"),
    "REGEXP-TIMEOUT": ("RegExp property-escape tests timeout (10s)", "RegExp", 3,
                       "Optimize unicode property lookup or increase perf for generated tests"),
    "HANG-TIMEOUT": ("Test timeout — infinite loop or IteratorClose missing", "Infrastructure", 3,
                     "Fix iterator close on abrupt completion; audit Map/Set/Iterator paths"),
    "PROMISE": ("Promise assimilation / job queue", "Promise/async", 4,
                "Microtask queue ordering; Thenable resolution"),
    "PROXY": ("Proxy trap / invariant violation", "Proxy", 4,
              "Complete Proxy internal method forwarding"),
    "DATE-SEM": ("Date parsing / formatting semantics", "Date", 3,
                 "ISO string parsing, UTC/local, extended year edge cases"),
    "JSON-API": ("JSON.stringify / JSON.rawJSON / reviver gaps", "JSON", 2,
                 "Implement JSON.rawJSON, isRawJSON, well-formed checks"),
    "URI-ENCODE": ("encodeURI / decodeURI percent-encoding edge cases", "URI", 2,
                   "Fix UTF-16 surrogate pair handling in URI builtins"),
    "MATH-NAN": ("Math.min/max NaN propagation wrong", "Math", 2,
                 "Spec: Math.min/max skip NaN vs return NaN per ES2024"),
    "OBJECT-META": ("Object.* metadata / integrity level", "Object", 3,
                    "Object.groupBy, hasOwn, getOwnPropertyDescriptors, seal/freeze edge cases"),
    "STRING-SEM": ("String conversion / well-formed / iterator", "String", 3,
                   "toWellFormed, isWellFormed, code point iteration"),
    "ARRAY-SEM": ("Array methods semantic gaps", "Array", 3,
                  "copyWithin, sort stability, length validation — see samples"),
    "SYMBOL-SEM": ("Symbol registry / well-known symbols", "Symbol", 3,
                   "Symbol.for, keyFor, @@toStringTag on builtins"),
    "INSTANCEOF": ("instanceof / @@hasInstance", "Object model", 3,
                   "Function.prototype[@@hasInstance] on bound functions"),
    "REF-OTHER": ("Other ReferenceError (unclassified binding)", "Bindings", 3,
                  "Inspect sample — likely missing global or TDZ"),
    "TYPE-ERROR": ("TypeError (general)", "Type system", 3,
                   "Coercion / internal slot / brand check"),
    "RANGE-ERROR": ("RangeError", "Validation", 2,
                    "Parameter range validation"),
    "PARSE-EVAL": ("Runtime SyntaxError via eval/Function", "Eval", 3,
                   "Direct eval scope; Function constructor body parsing"),
}


def parse_frontmatter(source: str) -> dict:
    if not source.startswith("/*---"):
        return {}
    end = source.find("---*/")
    if end < 0:
        return {}
    meta: dict = {}
    for line in source[4:end].splitlines():
        line = line.strip()
        if ":" not in line:
            continue
        k, v = line.split(":", 1)
        k, v = k.strip(), v.strip()
        if k in ("flags", "features", "includes"):
            meta[k] = [x.strip() for x in v.split(",") if x.strip()]
        else:
            meta[k] = v
    return meta


def classify(rel: str, result: str, detail: str, meta: dict) -> str:
    err = detail or ""
    el = err.lower()
    ctor = rel.split("/")[2] if len(rel.split("/")) > 2 else ""

    if result == "HANG":
        if "regexp" in rel.lower() or "property-escapes" in rel.lower():
            return "REGEXP-TIMEOUT"
        return "HANG-TIMEOUT"
    if result == "OOM":
        return "HANG-TIMEOUT"

    # ReferenceError: extract undefined name
    m = re.search(r"ReferenceError: (\w+) is not defined", err, re.I)
    if m:
        name = m.group(1)
        ref_map = {
            "Temporal": "FEAT-TEMPORAL",
            "Uint8ClampedArray": "FEAT-UINT8CLAMPED",
            "Uint8Array": "FEAT-TYPEDARRAY-CTORS",
            "Int8Array": "FEAT-TYPEDARRAY-CTORS",
            "Uint16Array": "FEAT-TYPEDARRAY-CTORS",
            "Int16Array": "FEAT-TYPEDARRAY-CTORS",
            "Uint32Array": "FEAT-TYPEDARRAY-CTORS",
            "Int32Array": "FEAT-TYPEDARRAY-CTORS",
            "Float32Array": "FEAT-TYPEDARRAY-CTORS",
            "Float64Array": "FEAT-TYPEDARRAY-CTORS",
            "BigInt64Array": "FEAT-BIGINT-CTORS",
            "BigUint64Array": "FEAT-BIGINT-CTORS",
            "ArrayBuffer": "FEAT-TYPEDARRAY-CTORS",
            "SharedArrayBuffer": "FEAT-SAB",
            "Atomics": "FEAT-ATOMICS",
            "Iterator": "FEAT-ITERATOR-HELPERS",
            "DisposableStack": "FEAT-DISPOSABLES",
            "AsyncDisposableStack": "FEAT-DISPOSABLES",
            "ShadowRealm": "FEAT-SHADOWREALM",
            "WeakRef": "FEAT-WEAKREF-FR",
            "FinalizationRegistry": "FEAT-WEAKREF-FR",
            "AggregateError": "FEAT-AGGREGATE-ERROR",
            "SuppressedError": "FEAT-AGGREGATE-ERROR",
            "BigInt": "FEAT-BIGINT-CTORS",
        }
        if name in ref_map:
            return ref_map[name]
        if name == "$DONE":
            return "ASYNC-DONE"

    if "$done" in el or "async flag" in el:
        return "ASYNC-DONE" if "$done" in el else "ASYNC-FLAG"

    if "length should be an own property" in err:
        return "FUNC-LENGTH"
    if "descriptor should not be enumerable" in err:
        return "PROP-DESC-ENUM"
    if "prop-desc" in rel.lower():
        return "PROP-DESC-GENERIC"
    if "configurable" in el and "descriptor" in el:
        return "PROP-DESC-CFG"
    if "proto-from-ctor-realm" in rel.lower():
        return "CROSS-REALM"
    if "not-a-constructor" in rel.lower():
        return "NOT-CONSTRUCTOR"
    if "is not a constructor" in el:
        return "NOT-CONSTRUCTOR"
    if "is not a function" in el:
        return "NOT-A-FUNCTION"
    if "cannot read propert" in el:
        return "UNDEF-PROP"
    if "expected samevalue" in el:
        if ctor == "Math" and ("nan" in el or "infinity" in el):
            return "MATH-NAN"
        return "ASSERT-SAMEVALUE"
    if "expected a typeerror but got a referenceerror" in el:
        return "THROW-WRONG-TYPE"
    if "did not throw" in el or "expected a" in el and "throw" in el:
        return "THROW-NONE"
    if ctor in ("encodeURI", "decodeURI", "encodeURIComponent", "decodeURIComponent"):
        return "URI-ENCODE"
    if ctor == "JSON":
        return "JSON-API"
    if ctor == "Date" or "temporal" in rel.lower():
        return "DATE-SEM"
    if ctor == "RegExp" or "regexp" in rel.lower():
        return "REGEXP-ENGINE"
    if ctor == "Promise":
        return "PROMISE"
    if "proxy" in el or ctor == "Proxy":
        return "PROXY"
    if ctor == "Object":
        return "OBJECT-META"
    if ctor == "String":
        return "STRING-SEM"
    if ctor == "Array":
        return "ARRAY-SEM"
    if ctor == "Symbol":
        return "SYMBOL-SEM"
    if "instanceof" in el:
        return "INSTANCEOF"
    if "referenceerror" in el:
        return "REF-OTHER"
    if "rangeerror" in el:
        return "RANGE-ERROR"
    if "typeerror" in el:
        return "TYPE-ERROR"
    if "syntaxerror" in el:
        return "PARSE-EVAL"

    features = meta.get("features", [])
    feat_map = {
        "TypedArray": "FEAT-TYPEDARRAY-CTORS",
        "ArrayBuffer": "FEAT-TYPEDARRAY-CTORS",
        "BigInt": "FEAT-BIGINT-CTORS",
        "SharedArrayBuffer": "FEAT-SAB",
        "Atomics": "FEAT-ATOMICS",
        "ShadowRealm": "FEAT-SHADOWREALM",
        "WeakRef": "FEAT-WEAKREF-FR",
        "FinalizationRegistry": "FEAT-WEAKREF-FR",
    }
    for f in features:
        if f in feat_map:
            return feat_map[f]
    if "async" in meta.get("flags", []):
        return "ASYNC-DONE"

    return "REF-OTHER"


def load_log(path: Path) -> tuple[str, str]:
    result, detail = "FAIL", ""
    try:
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            if line.startswith("result:"):
                result = line.split(":", 1)[1].strip()
            elif line.startswith("detail:"):
                detail = line.split(":", 1)[1].strip()
    except OSError:
        pass
    return result, detail


def render_md(issues: list[Issue], total: int, passed: int, counts: Counter) -> str:
    ranked = sorted(issues, key=lambda x: (-x.roi, -x.count))
    failed = counts.get("FAIL", 0)
    hang = counts.get("HANG", 0)

    L = [
        "# test262 `built-ins` — Comprehensive Failure Analysis",
        "",
        "**Suite:** `test/built-ins/**`",
        f"**Run date:** {date.today().isoformat()}",
        "**Runner:** `python3 engine/tests/test262/run_test262.py --filter 'built-ins/*' --jobs 4` (default 0.1 GB per-test mem limit)",
        "**Engine:** `bin/js_engine`",
        "",
        "## Executive summary",
        "",
        "| Metric | Count |",
        "|--------|------:|",
        f"| Total tests | {total:,} |",
        f"| **Passed** | **{passed:,}** ({100*passed/total:.1f}%) |",
        f"| Failed | {failed:,} |",
        f"| Timeout (HANG) | {hang:,} |",
        f"| Skipped | 0 |",
        f"| Unique root-cause clusters | {len(issues)} |",
        "",
        "All built-ins tests run with bulk flag/feature skips **disabled** (`built_ins_exempt_from_bulk_skips: true`).",
        "",
        "### Pass rate by constructor (top 20 by test count)",
        "",
    ]

    ctor_total: Counter = Counter()
    ctor_pass: Counter = Counter()
    baseline = set()
    bp = JS_ENGINE_ROOT / "docs/regression_logs/builtins_baseline.txt"
    if bp.exists():
        for line in bp.read_text().splitlines():
            if line.startswith("ok  "):
                baseline.add(line[4:].strip())
    for tp in sorted((TEST_DIR / "built-ins").rglob("*.js")):
        rel = "test/" + str(tp.relative_to(TEST_DIR)).replace("\\", "/")
        ctor = rel.split("/")[2]
        ctor_total[ctor] += 1
        if rel in baseline:
            ctor_pass[ctor] += 1

    L.append("| Constructor | Total | Pass | Rate |")
    L.append("|-------------|------:|-----:|-----:|")
    for ctor, n in ctor_total.most_common(25):
        p = ctor_pass[ctor]
        L.append(f"| `{ctor}` | {n:,} | {p:,} | {100*p/n:.1f}% |")

    L += [
        "",
        "## ROI methodology",
        "",
        "**ROI** = tests affected ÷ estimated effort.",
        "",
        "| Effort | Meaning |",
        "|-------:|---------|",
        "| 1 | Hours — single function / descriptor fix |",
        "| 2 | 1–2 days — cross-cutting native property audit |",
        "| 3 | ~1 week — single builtin family semantic pass |",
        "| 4 | 2–4 weeks — infrastructure (async, realms, RegExp) |",
        "| 5 | Multi-week subsystem (Temporal, TypedArray, SAB) |",
        "",
        "## ROI-ranked issue clusters",
        "",
        "| Rank | ID | Category | Tests | Effort | ROI | Root cause |",
        "|-----:|----|----------|------:|-------:|----:|------------|",
    ]
    for i, c in enumerate(ranked, 1):
        L.append(f"| {i} | `{c.issue_id}` | {c.category} | {c.count:,} | {c.effort} | {c.roi:.1f} | {c.title} |")

    L += ["", "---", "", "## Detailed root-cause analysis", ""]
    for i, c in enumerate(ranked, 1):
        L += [
            f"### {i}. `{c.issue_id}` — {c.title}",
            "",
            f"| | |",
            f"|---|---|",
            f"| **Tests affected** | {c.count:,} |",
            f"| **Category** | {c.category} |",
            f"| **Effort (1–5)** | {c.effort} |",
            f"| **ROI** | {c.roi:.1f} |",
            f"| **Fix direction** | {c.fix_hint} |",
            "",
            "**Constructors affected:** " + ", ".join(f"`{k}` ({v})" for k, v in c.constructors.most_common(12)),
            "",
        ]
        if c.patterns:
            L.append("**Common failure messages:**")
            L.append("")
            for pat, n in c.patterns.most_common(6):
                L.append(f"- ({n:,}×) `{pat[:140]}`")
            L.append("")
        if c.samples:
            L.append("**Sample tests:**")
            L.append("")
            for s in c.samples[:6]:
                L.append(f"- `{s}`")
            L.append("")

    # Tier recommendations
    L += [
        "## Recommended fix order (ROI tiers)",
        "",
        "### Tier A — Quick wins (effort ≤2, ROI ≥50)",
        "",
    ]
    for c in ranked:
        if c.effort <= 2 and c.roi >= 50:
            L.append(f"1. **`{c.issue_id}`** — {c.count:,} tests, ROI {c.roi:.1f}: {c.fix_hint}")
    L += ["", "### Tier B — Medium effort, high impact (effort 3, ≥100 tests)", ""]
    for c in ranked:
        if c.effort == 3 and c.count >= 100:
            L.append(f"1. **`{c.issue_id}`** — {c.count:,} tests, ROI {c.roi:.1f}: {c.fix_hint}")
    L += ["", "### Tier C — Subsystems (effort ≥4, plan dedicated projects)", ""]
    for c in ranked:
        if c.effort >= 4 and c.count >= 50:
            L.append(f"1. **`{c.issue_id}`** — {c.count:,} tests, ROI {c.roi:.1f}: {c.fix_hint}")
    L += [
        "",
        "## Infrastructure notes",
        "",
        "- **Analysis script:** `engine/tests/test262/analyze_builtins_failures.py`",
        "- **Raw JSON:** `docs/regression_logs/builtins_analysis.json`",
        "- **Pass baseline:** `docs/regression_logs/builtins_baseline.txt`",
        "- **Run log:** `docs/regression_logs/builtins_run.log`",
        "",
    ]
    return "\n".join(L)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--baseline", default=str(JS_ENGINE_ROOT / "docs/regression_logs/builtins_baseline.txt"))
    ap.add_argument("--output", default=str(JS_ENGINE_ROOT / "docs/test262_builtins_issues.md"))
    ap.add_argument("--json", default=str(JS_ENGINE_ROOT / "docs/regression_logs/builtins_analysis.json"))
    args = ap.parse_args()

    passed: set[str] = set()
    if Path(args.baseline).exists():
        for line in Path(args.baseline).read_text().splitlines():
            if line.startswith("ok  "):
                passed.add(line[4:].strip())

    tests = sorted((TEST_DIR / "built-ins").rglob("*.js"))
    total = len(tests)
    counts: Counter = Counter()
    by_id: dict[str, Issue] = {}

    for tp in tests:
        rel = "test/" + str(tp.relative_to(TEST_DIR)).replace("\\", "/")
        if rel in passed:
            counts["PASS"] += 1
            continue
        log = LOG_ROOT / Path(rel).with_suffix(".log")
        result, detail = load_log(log) if log.exists() else ("UNKNOWN", "")
        counts[result if result in ("FAIL", "HANG", "OOM") else "FAIL"] += 1
        meta = parse_frontmatter(tp.read_text(encoding="utf-8", errors="replace"))
        iid = classify(rel, result, detail, meta)
        if iid not in by_id:
            t, cat, eff, hint = ISSUE_CATALOG.get(iid, (iid, "Unclassified", 4, "Investigate samples"))
            by_id[iid] = Issue(iid, t, cat, eff, hint)
        c = by_id[iid]
        c.tests.append(rel)
        c.constructors[rel.split("/")[2]] += 1
        if detail:
            norm = re.sub(r"\s+", " ", detail[:160])
            c.patterns[norm] += 1
            if len(c.samples) < 6:
                c.samples.append(f"{rel} — {detail[:90]}")

    issues = sorted(by_id.values(), key=lambda x: (-x.roi, -x.count))
    md = render_md(issues, total, counts["PASS"], counts)
    Path(args.output).write_text(md, encoding="utf-8")
    Path(args.json).write_text(json.dumps({
        "total": total, "passed": counts["PASS"],
        "result_counts": dict(counts),
        "clusters": [{k: getattr(c, k) if k != "constructors" and k != "patterns" else dict(getattr(c, k))
                      for k in ("issue_id", "title", "category", "effort", "fix_hint", "count", "roi", "samples")}
                     | {"constructors": dict(c.constructors.most_common(30)), "patterns": dict(c.patterns.most_common(15)),
                        "test_count": c.count}
                     for c in issues],
    }, indent=2), encoding="utf-8")
    print(f"Wrote {args.output} — {counts['PASS']}/{total} passed, {len(issues)} clusters")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
