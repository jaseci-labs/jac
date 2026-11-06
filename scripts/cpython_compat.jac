"""Run the pinned CPython release's full regression suite and compare two runtimes.

`run` installs the upstream test package of the CPython release pinned in
jac/bootstrap/python/sources.json into an interpreter's standard library,
where `make install` would have put it, and runs every regrtest module in its
own `python -m test`. One run per module makes that run's result the module's
result, and a crash or hang stays inside it. Failed modules are re-run once,
so a module that passes on the second attempt is recorded as flaky.

`compare` reads the results of a stock CPython run and a JacPython run of the
same pin. A module or test counts against JacPython only when stock CPython
passes it and JacPython fails or does not run it, so failures the runner's
environment causes on both runtimes do not.

    jac run scripts/cpython_compat.jac run --python <prefix>/bin/python3.14 \
        --label jacpython --out results/jacpython
    jac run scripts/cpython_compat.jac compare results/cpython results/jacpython
"""

import argparse;
import hashlib;
import json;
import os;
import re;
import shutil;
import signal;
import subprocess;
import sys;
import tarfile;
import tempfile;
import time;
import urllib.request;
import xml.etree.ElementTree as ET;
import from concurrent.futures { ThreadPoolExecutor, as_completed }
import from pathlib { Path }

glob REPO: Path = Path(__file__).resolve().parents[1],
     RAN: set[str] = {"passed", "flaky", "env_changed"},
     BROKEN: set[str] = {"failed", "crashed", "timeout", "died"},
     # Expected failures are not passing cases; only stock-passed cases gate JacPython.
     CASE_OK: set[str] = {"passed"},
     CASE_BAD: set[str] = {"failed", "error", "xfail", "xpass"},
     REPORT_LIMIT: int = 150,
     # What JacPython leaves out by decision, by module, class or test:
     # reported, never counted.
     INTENDED: dict[str, str] = {
         "test_external_inspection": "remote debugging is not built",
         "test_remote_pdb": "remote debugging is not built",
         "test.test_audit.AuditTest.test_sys_remote_exec": "remote debugging is not built",
         "test.test_sys.TestRemoteExec": "remote debugging is not built",
         "test_perf_profiler": "perf trampolines are not built"
     },
     # Test-only C extensions that unlock the largest upstream test groups.
     # Their source list is read from the pinned release's Setup.stdlib.in.
     TEST_EXTENSIONS: set[str] = {
         "_ctypes_test",
         "_testbuffer",
         "_testcapi",
         "_testclinic",
         "_testclinic_limited",
         "_testimportmultiple",
         "_testinternalcapi",
         "_testlimitedcapi",
         "_testmultiphase",
         "_testsinglephase",
         "_xxtestfuzz",
         "xxlimited",
         "xxlimited_35",
         "xxsubtype"
     },
     DETAIL_LIMIT: int = 240;

def pinned_cpython -> dict[str, str] {
    sources = json.loads((REPO / "jac/bootstrap/python/sources.json").read_text());
    return sources["cpython"];
}

def clean_env(work: Path) -> dict[str, str] {
    # The orchestrator runs under the jac launcher, whose PYTHON* settings
    # point at its own payload; the interpreter under test must not see them.
    env = {
        k: v
        for (k, v) in os.environ.items()
        if not k.startswith("PYTHON")
    };
    env["TMPDIR"] = str(work);
    return env;
}

def probe(python: str, code: str) -> str {
    done = subprocess.run(
        [python, "-I", "-c", code],
        capture_output=True,
        text=True,
        check=True,
        env=clean_env(Path(tempfile.gettempdir()))
    );
    return done.stdout.strip();
}

def source_archive(cache: Path) -> Path {
    pin = pinned_cpython();
    archive = cache / f"Python-{pin['version']}-{pin['sha256']}.tgz";
    data = archive.read_bytes() if archive.is_file() else b"";
    if hashlib.sha256(data).hexdigest() != pin["sha256"] {
        cache.mkdir(parents=True, exist_ok=True);
        with urllib.request.urlopen(pin["url"], timeout=300) as response {
            data = response.read();
        }
        if hashlib.sha256(data).hexdigest() != pin["sha256"] {
            raise RuntimeError("CPython source archive checksum mismatch");
        }
        archive.write_bytes(data);
    }
    return archive;
}

def test_extension_sources(source_root: Path) -> list[tuple[str, list[Path]]] {
    setup = (source_root / "Modules/Setup.stdlib.in").read_text();
    in_test_section = False;
    found: list[tuple[str, list[Path]]] = [];
    for line in setup.splitlines() {
        if line.strip() == "# Test modules" {
            in_test_section = True;
            continue;
        }
        if not in_test_section {
            continue;
        }
        matched = re.match(r"@MODULE_[A-Z0-9_]+_TRUE@(\S+)\s+(.+)$", line.strip());
        if not matched {
            continue;
        }
        name = matched.group(1);
        if name not in TEST_EXTENSIONS {
            continue;
        }
        sources = [source_root / "Modules" / path for path in matched.group(2).split()];
        if any(not path.is_file() for path in sources) {
            missing = [
                str(path)
                for path in sources
                if not path.is_file()
            ];
            raise RuntimeError(
                f"pinned CPython test extension {name} has missing sources: {missing}"
            );
        }
        found.append((name, sources));
    }
    present = {name for (name, _) in found};
    if present != TEST_EXTENSIONS {
        raise RuntimeError(
            "pinned CPython Setup.stdlib.in test modules differ: "
            f"missing={sorted(TEST_EXTENSIONS - present)}, "
            f"extra={sorted(present - TEST_EXTENSIONS)}"
        );
    }
    return found;
}

def build_test_extensions(python: str, source_root: Path) {
    extensions = test_extension_sources(source_root);
    zig = shutil.which("zig");
    if not zig {
        raise RuntimeError(
            "Zig must be on PATH to build JacPython compatibility test extensions"
        );
    }
    include_dir = Path(
        probe(python, "import sysconfig; print(sysconfig.get_path('include'))")
    );
    stdlib = Path(
        probe(python, "import sysconfig; print(sysconfig.get_path('stdlib'))")
    );
    suffix = probe(
        python, "import sysconfig; print(sysconfig.get_config_var('EXT_SUFFIX'))"
    );
    if not suffix {
        raise RuntimeError("JacPython has no configured extension suffix");
    }
    module_dir = source_root / "Modules";
    destination = stdlib / "lib-dynload";
    destination.mkdir(parents=True, exist_ok=True);
    unavailable: list[str] = [];
    for (name, sources) in extensions {
        output = destination / f"{name}{suffix}";
        command = [
            zig,
            "cc",
            "-bundle" if sys.platform == "darwin" else "-shared",
            "-fPIC",
            "-pthread",
            f"-I{include_dir}",
            f"-I{include_dir / 'internal'}",
            f"-I{include_dir / 'internal/mimalloc'}",
            f"-I{module_dir}",
            f"-I{module_dir / 'clinic'}",
            "-o",
            str(output)
        ];
        if sys.platform == "darwin" {
            command.extend(["-undefined", "dynamic_lookup"]);
        }
        command.extend(str(source) for source in sources);
        built = subprocess.run(
            command,
            cwd=source_root,
            capture_output=True,
            text=True,
            env=clean_env(source_root)
        );
        if built.returncode != 0 {
            output.unlink(missing_ok=True);
            unavailable.append(name);
            print(
                f"Unavailable pinned CPython test extension {name}; build failed:\n"
                f"{built.stdout}{built.stderr}",
                flush=True
            );
            continue;
        }
        loaded = subprocess.run(
            [python, "-I", "-c", f"import {name}"],
            capture_output=True,
            text=True,
            env=clean_env(source_root)
        );
        if loaded.returncode != 0 {
            output.unlink(missing_ok=True);
            unavailable.append(name);
            print(
                f"Unavailable pinned CPython test extension {name}; import failed:\n"
                f"{loaded.stdout}{loaded.stderr}",
                flush=True
            );
            continue;
        }
        print(f"Built and loaded pinned CPython test extension {name}", flush=True);
    }
    if unavailable {
        print(
            f"JacPython compatibility test extensions unavailable: {sorted(
                unavailable
            )}",
            flush=True
        );
    }
}

def replace_pinned_tree(source: Path, target: Path) {
    if not source.is_dir() {
        raise RuntimeError(f"pinned CPython test tree is missing: {source}");
    }
    if target.is_symlink() or target.is_file() {
        target.unlink();
    } elif target.exists() {
        shutil.rmtree(target);
    }
    shutil.copytree(source, target);
}

def install_tests(python: str, cache: Path, test_extensions: bool = False) -> str {
    pin = pinned_cpython();
    version = probe(python, "import platform; print(platform.python_version())");
    if version != pin["version"] {
        raise RuntimeError(
            f"{python} is Python {version}; the pinned tests are {pin['version']}"
        );
    }
    stdlib = Path(
        probe(python, "import sysconfig; print(sysconfig.get_path('stdlib'))")
    );
    targets = {
        "Lib/test/": stdlib / "test",
        # CPython's runtime build omits documentation data. The regression
        # suite's pydoc tests need the pinned documentation tables as well as
        # Lib/test; these files are installed only into the ephemeral
        # compatibility-test interpreter tree.
        "Lib/pydoc_data/": stdlib / "pydoc_data"
    };
    suffix = probe(
        python, "import sysconfig; print(sysconfig.get_config_var('EXT_SUFFIX'))"
    );
    extension_dir = stdlib / "lib-dynload";
    missing_extensions = test_extensions
        and any(
            not (extension_dir / f"{name}{suffix}").is_file()
            for name in TEST_EXTENSIONS
        );
    archive = source_archive(cache);
    archive_prefix = f"Python-{pin['version']}/";
    with tempfile.TemporaryDirectory() as scratch {
        with tarfile.open(archive, mode="r:gz") as bundle {
            archive_members = bundle.getmembers();
            for prefix in targets {
                members = [
                    m
                    for m in archive_members
                    if m.name.startswith(archive_prefix + prefix)
                ];
                if not members {
                    raise RuntimeError(
                        f"pinned CPython source archive has no {prefix} tree"
                    );
                }
                bundle.extractall(scratch, members=members, filter="data");
            }
            if missing_extensions {
                modules_prefix = archive_prefix + "Modules/";
                module_members = [
                    m
                    for m in archive_members
                    if m.name.startswith(modules_prefix)
                ];
                bundle.extractall(scratch, members=module_members, filter="data");
            }
        }
        for (prefix, target) in targets.items() {
            source = Path(scratch) / archive_prefix / prefix.rstrip("/");
            replace_pinned_tree(source, target);
        }
        if missing_extensions {
            build_test_extensions(python, Path(scratch) / archive_prefix);
        }
    }
    print(f"Installed pinned CPython {version} test support into {stdlib}", flush=True);
    return version;
}

def isolated_compatibility_runtime(python: Path, cache: Path, label: str) -> Path {
    prefix = Path(probe(str(python), "import sys; print(sys.prefix)")).resolve();
    executable = Path(
        probe(str(python), "import sys; print(sys.executable)")
    ).resolve();
    relative = executable.relative_to(prefix);
    destination = cache.resolve().parent / f"{label}-compat-runtime";
    shutil.rmtree(destination, ignore_errors=True);
    try {
        shutil.copytree(prefix, destination, copy_function=os.link);
    } except OSError {
        shutil.rmtree(destination, ignore_errors=True);
        shutil.copytree(prefix, destination);
    }
    relocated = destination / relative;
    probe(str(relocated), "import sys; print(sys.prefix)");
    return relocated;
}

def list_modules(python: str, work: Path) -> list[str] {
    done = subprocess.run(
        [python, "-m", "test", "--list-tests"],
        capture_output=True,
        text=True,
        check=True,
        cwd=work,
        env=clean_env(work)
    );
    return [
        line.strip()
        for line in done.stdout.splitlines()
        if line.strip()
    ];
}

def clip(text: str) -> str {
    first = text.strip().splitlines()[0] if text.strip() else "";
    return first[:DETAIL_LIMIT];
}

# A one-module regrtest run ends with "Total test files: run=1/1 failed=1
# rerun=1" and "Result: FAILURE then SUCCESS"; its progress lines say how the
# first attempt ended ("worker non-zero exit code (Exit code -11 (SIGSEGV))",
# "timed out (20 min)", "failed (2 failures)").
def module_state(
    log: str, returncode: int | None, module_timeout: int
) -> tuple[str, str] {
    if returncode is None {
        return ("timeout", f"no result after {module_timeout}s");
    }
    results = re.findall(r"^Result: (.+)$", log, re.MULTILINE);
    totals = re.findall(r"^Total test files: (.+)$", log, re.MULTILINE);
    if not results or not totals {
        return ("died", f"regrtest exited {returncode} without a result");
    }
    counts: dict[str, str] = {};
    for field in totals[-1].split() {
        (key, _, value) = field.partition("=");
        counts[key] = value;
    }
    first = "";
    for line in log.splitlines() {
        found = re.search(r"\[\s*\d+/\d+(?:/\d+)?\] \S+ (.+)$", line);
        if found and found.group(1) != "passed" {
            first = found.group(1).strip();
            break;
        }
    }
    if "failed" in counts {
        if first.startswith("worker non-zero exit code") {
            return ("crashed", first);
        }
        if first.startswith("timed out") {
            return ("timeout", first);
        }
        return ("failed", first or results[-1]);
    }
    if "rerun" in counts {
        return ("flaky", first);
    }
    if "resource_denied" in counts {
        return ("denied", first);
    }
    if "skipped" in counts {
        reason = re.search(r"^\S+ skipped -- (.+)$", log, re.MULTILINE);
        return ("skipped", clip(reason.group(1)) if reason else "");
    }
    if "run_no_tests" in counts {
        return ("no_tests", "");
    }
    if "env_changed" in counts {
        return ("env_changed", first);
    }
    return ("passed", "");
}

# Re-run attempts append their testcases after the first attempt's, so the
# last record of a test is its final outcome.
def parse_junit(text: str) -> dict[str, tuple[str, str]] {
    cases: dict[str, tuple[str, str]] = {};
    for element in ET.fromstring(text).iter("testcase") {
        outcome = "passed";
        detail = "";
        for child in element {
            if child.tag == "error" or child.tag == "failure" {
                outcome = "error" if child.tag == "error" else "failed";
                detail = clip(child.get("message", "") or child.get("type", ""));
            } elif child.tag == "skipped" {
                outcome = "skipped";
                detail = clip(child.text or "");
            } elif child.tag == "output" {
                outcome = "xfail";
            } elif child.tag == "outcome" and child.text == "UNEXPECTED_SUCCESS" {
                outcome = "xpass";
            }
        }
        cases[element.get("name", "")] = (outcome, detail);
    }
    return cases;
}

def regrtest_command(python: str, name: str, xml_path: Path, args: any) -> list[str] {
    command = [
        python,
        "-m",
        "test",
        "-j1",
        "--rerun",
        f"--timeout={args.test_timeout}"
    ];
    if args.resources {
        command.extend(["-u", args.resources]);
    }
    if args.memlimit {
        command.extend(["-M", args.memlimit]);
    }
    command.extend([f"--junit-xml={xml_path}", name]);
    return command;
}

def run_module(python: str, name: str, out: Path, args: any) -> dict[str, any] {
    work = out / "work" / name;
    work.mkdir(parents=True, exist_ok=True);
    xml_path = out / "junit" / f"{name}.xml";
    command = regrtest_command(python, name, xml_path, args);
    started = time.monotonic();
    returncode: int | None = None;
    with open(out / "logs" / f"{name}.log", "wb") as log {
        process = subprocess.Popen(
            command,
            stdin=subprocess.DEVNULL,
            stdout=log,
            stderr=subprocess.STDOUT,
            cwd=work,
            env=clean_env(work),
            start_new_session=True
        );
        try {
            returncode = process.wait(timeout=args.module_timeout);
        } except subprocess.TimeoutExpired {
            # regrtest's workers share the session; take them down with it.
            os.killpg(process.pid, int(signal.SIGKILL));
            process.wait();
        }
    }
    seconds = time.monotonic() - started;
    shutil.rmtree(work, ignore_errors=True);
    text = (out / "logs" / f"{name}.log").read_text(errors="replace");
    (state, detail) = module_state(text, returncode, args.module_timeout);
    cases: dict[str, tuple[str, str]] = {};
    if xml_path.is_file() {
        try {
            cases = parse_junit(xml_path.read_text(errors="replace"));
        } except ET.ParseError as error {
            detail = f"{detail}; unreadable junit: {error}".strip("; ");
        }
    }
    return {
        "name": name,
        "state": state,
        "detail": detail,
        "seconds": round(seconds, 1),
        "cases": cases
    };
}

def run(args: any) -> int {
    out = Path(args.out).resolve();
    for sub in ("logs", "junit", "work") {
        (out / sub).mkdir(parents=True, exist_ok=True);
    }
    base_python = Path(args.python).resolve();
    cache = Path(args.cache).resolve();
    python = str(base_python);
    version = probe(python, "import platform; print(platform.python_version())");
    jacpython = (
        probe(
            python,
            "import ctypes; print(hasattr(ctypes.pythonapi, '_PyJac_CompilerRequired'))"
        )
        == "True"
    );
    # Comparing the wrong interpreter would report a clean result for nothing.
    if jacpython != (args.label == "jacpython") {
        raise RuntimeError(
            f"{python} is {'' if jacpython else 'not '}JacPython, but the label is {args.label}"
        );
    }
    # Keep the pinned test corpus and test C extensions out of either cached
    # interpreter prefix. Hardlinks make the disposable copies cheap.
    python = str(isolated_compatibility_runtime(base_python, cache, args.label));
    version = install_tests(python, cache, jacpython);
    module_names = args.modules or list_modules(python, out / "work");
    jobs = args.jobs or os.cpu_count() or 1;
    print(
        f"{args.label}: CPython {version} suite, {len(module_names)} modules, {jobs} at a time",
        flush=True
    );
    records: dict[str, dict[str, any]] = {};
    started = time.monotonic();
    with ThreadPoolExecutor(max_workers=jobs) as pool {
        pending = [
            pool.submit(run_module, python, name, out, args) for name in module_names
        ];
        for future in as_completed(pending) {
            record = future.result();
            records[record["name"]] = record;
            progress = f"[{len(records)}/{len(module_names)}] {record['name']}";
            note = f" -- {record['detail']}" if record["detail"] else "";
            print(
                f"{progress} {record['state']} ({record['seconds']:.0f}s){note}",
                flush=True
            );
        }
    }
    shutil.rmtree(out / "work", ignore_errors=True);
    states: dict[str, int] = {};
    for record in records.values() {
        states[record["state"]] = states.get(record["state"], 0) + 1;
    }
    (out / "results.json").write_text(
        json.dumps(
            {
                "label": args.label,
                "version": version,
                "jacpython": jacpython,
                "resources": args.resources,
                "memlimit": args.memlimit,
                "full_suite": not bool(args.modules),
                "module_names": sorted(module_names),
                "seconds": round(time.monotonic() - started),
                "modules": {
                    name: {
                        k: v
                        for (k, v) in records[name].items()
                        if k != "name"
                    } for name in sorted(records)
                }
            },
            indent=1
        )
    );
    print(
        f"{args.label}: {', '.join(f'{n} {s}' for (s, n) in sorted(states.items()))}",
        flush=True
    );
    return 0;
}

def intended(name: str) -> str {
    parts = name.split(".");
    for size in range(len(parts), 0, -1) {
        reason = INTENDED.get(".".join(parts[:size]));
        if reason {
            return reason;
        }
    }
    return "";
}

def compare_results(
    stock: dict[str, any], jac: dict[str, any]
) -> dict[str, list[list[str]]] {
    found: dict[str, list[list[str]]] = {
        "module_regressions": [],
        "modules_not_run": [],
        "case_regressions": [],
        "cases_not_run": [],
        "broken_on_both": [],
        "flaky_on_jacpython": [],
        "fixed_on_jacpython": [],
        "intended": [],
        "not_comparable": []
    };
    def gap(key: str, row: list[str]) {
        reason = intended(row[0]);
        if reason {
            found["intended"].append([row[0], row[1], reason, row[3]]);
        } else {
            found[key].append(row);
        }
    }
    stock_modules = stock["modules"];
    jac_modules = jac["modules"];
    for name in sorted(set(stock_modules) | set(jac_modules)) {
        base = stock_modules.get(name, {"state": "missing", "detail": "", "cases": {}});
        ours = jac_modules.get(name, {"state": "missing", "detail": "", "cases": {}});
        (was, now) = (base["state"], ours["state"]);
        # A gating or intended module row stands for the tests JacPython did
        # not run in it; a failure on both runtimes does not.
        covered = False;
        if was in RAN and now not in RAN {
            key = "module_regressions" if now in BROKEN else "modules_not_run";
            gap(key, [name, now, ours["detail"], was]);
            covered = True;
        } elif now in BROKEN and was in BROKEN {
            found["broken_on_both"].append([name, now, ours["detail"], was]);
        } elif now in BROKEN {
            found["not_comparable"].append([name, now, ours["detail"], was]);
        } elif was in BROKEN {
            found["fixed_on_jacpython"].append([name, now, ours["detail"], was]);
        }
        if now == "flaky" and was != "flaky" {
            found["flaky_on_jacpython"].append([name, now, ours["detail"], was]);
        }
        base_cases = base.get("cases", {});
        jac_cases = ours.get("cases", {});
        for (case_id, (outcome, _)) in sorted(base_cases.items()) {
            if outcome not in CASE_OK {
                continue;
            }
            (result, detail) = jac_cases.get(case_id, ("missing", ""));
            if result in CASE_BAD {
                gap("case_regressions", [case_id, result, detail, outcome]);
            } elif (result == "skipped" or result == "missing") and not covered {
                gap("cases_not_run", [case_id, result, detail, outcome]);
            }
        }
    }
    return found;
}

glob SECTIONS: list[tuple[str, str, bool]] = [
         ("module_regressions", "Modules that fail only on JacPython", True),
         ("modules_not_run", "Modules stock CPython runs and JacPython does not", True),
         ("case_regressions", "Tests that fail only on JacPython", True),
         ("cases_not_run", "Tests stock CPython runs and JacPython skips", True),
         (
             "flaky_on_jacpython",
             "Modules that needed a re-run only on JacPython",
             False
         ),
         ("broken_on_both", "Modules that fail on both runtimes", False),
         ("fixed_on_jacpython", "Modules that fail only on stock CPython", False),
         ("intended", "Differences JacPython makes by decision", False),
         (
             "not_comparable",
             "Modules JacPython fails and stock CPython does not run",
             False
         )
     ];

def tally(results: dict[str, any]) -> tuple[dict[str, int], dict[str, int]] {
    states: dict[str, int] = {};
    outcomes: dict[str, int] = {};
    for record in results["modules"].values() {
        states[record["state"]] = states.get(record["state"], 0) + 1;
        for (outcome, _) in record.get("cases", {}).values() {
            outcomes[outcome] = outcomes.get(outcome, 0) + 1;
        }
    }
    return (states, outcomes);
}

def render(
    stock: dict[str, any], jac: dict[str, any], found: dict[str, list[list[str]]]
) -> str {
    gaps = sum(
        len(found[key])
        for (key, _, gating) in SECTIONS
        if gating
    );
    verdict = "compatible: every module and test stock CPython passes also passes on JacPython"
        if gaps == 0
        else f"{gaps} incompatibilities";
    lines = [
        f"## CPython {jac['version']} regression suite: JacPython vs stock CPython",
        "",
        f"**{verdict}** (resources: `{jac['resources'] or 'none'}`, "
            + f"memory cap: `{jac.get('memlimit') or 'disabled'}`)",
        "",
        "| | modules | passed | flaky | failed | crashed | timeout | skipped | denied | tests passed | tests failed | tests skipped |",
        "|---|---|---|---|---|---|---|---|---|---|---|---|"
    ];
    for results in (stock, jac) {
        (states, outcomes) = tally(results);
        lines.append(
            f"| {results['label']} | {len(results['modules'])} | {states.get(
                'passed', 0
            )} | {states.get('flaky', 0)} | {states.get('failed', 0)} | {states.get(
                'crashed', 0
            )} | {states.get('timeout', 0) + states.get('died', 0)} | {states.get(
                'skipped', 0
            )
                + states.get('no_tests', 0)} | {states.get('denied', 0)} | {outcomes.get(
                'passed', 0
            )
                + outcomes.get('xfail', 0)} | {outcomes.get('failed', 0)
                + outcomes.get('error', 0)
                + outcomes.get('xpass', 0)} | {outcomes.get('skipped', 0)} |"
        );
    }
    for (key, title, gating) in SECTIONS {
        rows = found[key];
        if not rows {
            continue;
        }
        lines.extend(["", f"### {title} ({len(rows)})", ""]);
        if not gating {
            lines.extend(["<details><summary>show</summary>", ""]);
        }
        for (name, now, detail, was) in rows[:REPORT_LIMIT] {
            note = f": {detail}" if detail else "";
            lines.append(f"- `{name}` {now} (stock: {was}){note}");
        }
        if len(rows) > REPORT_LIMIT {
            lines.append(
                f"- ... {len(rows)
                    - REPORT_LIMIT} more in report.json (workflow artifact)"
            );
        }
        if not gating {
            lines.extend(["", "</details>"]);
        }
    }
    return "\n".join(lines) + "\n";
}

def validate_comparison_runs(stock: dict[str, any], jac: dict[str, any]) {
    if stock["version"] != jac["version"]
        or stock["jacpython"]
        or not jac["jacpython"]
        or stock.get("resources") != jac.get("resources")
        or stock.get("memlimit", "") != jac.get("memlimit", "") {
        raise RuntimeError(
            "compare needs stock CPython and JacPython results with matching "
                + "version, resources, and memory cap"
        );
    }
    if stock.get("full_suite") != True or jac.get("full_suite") != True {
        raise RuntimeError("compare needs full-suite CPython and JacPython results");
    }
    stock_names = stock.get("module_names", []);
    jac_names = jac.get("module_names", []);
    if not stock_names
        or not jac_names
        or stock_names != sorted(stock_names)
        or jac_names != sorted(jac_names)
        or stock_names != sorted(stock["modules"])
        or jac_names != sorted(jac["modules"])
        or stock_names != jac_names {
        raise RuntimeError(
            "compare needs complete results with the same full-suite module inventory"
        );
    }
}

def compare(args: any) -> int {
    stock = json.loads((Path(args.stock) / "results.json").read_text());
    jac = json.loads((Path(args.jacpython) / "results.json").read_text());
    validate_comparison_runs(stock, jac);
    found = compare_results(stock, jac);
    markdown = render(stock, jac, found);
    print(markdown);
    if args.summary {
        with open(args.summary, "a") as summary {
            summary.write(markdown);
        }
    }
    if args.report {
        Path(args.report).write_text(json.dumps(found, indent=1));
    }
    return int(
        any(
            found[key]
            for (key, _, gating) in SECTIONS
            if gating
        )
    );
}

def main -> int {
    parser = argparse.ArgumentParser(
        description="Run the pinned CPython regression suite and compare two runtimes"
    );
    commands = parser.add_subparsers(dest="command", required=True);
    runner = commands.add_parser("run", help="Run the suite on one interpreter");
    runner.add_argument("--python", required=True, help="Interpreter to test");
    runner.add_argument("--label", required=True, choices=["cpython", "jacpython"]);
    runner.add_argument("--out", required=True, help="Directory for logs and results");
    runner.add_argument(
        "--cache",
        `default=str(Path(tempfile.gettempdir()) / "jac-cpython-source"),
        help="Where the pinned CPython source archive is kept"
    );
    runner.add_argument(
        "--resources",
        `default="all,-network,-urlfetch,-gui,-audio,-largefile",
        help="regrtest -u value; empty runs without optional resources"
    );
    runner.add_argument(
        "--memlimit",
        `default="",
        help="regrtest -M memory cap; empty leaves big-memory tests disabled"
    );
    runner.add_argument(
        "--jobs", `type=int, `default=0, help="Modules at a time (0: CPUs)"
    );
    runner.add_argument(
        "--test-timeout",
        `type=int,
        `default=1200,
        help="regrtest --timeout per attempt"
    );
    runner.add_argument(
        "--module-timeout",
        `type=int,
        `default=3600,
        help="Seconds before a module's whole run, re-run included, is killed"
    );
    runner.add_argument("modules", nargs="*", help="Modules to run (default: all)");
    comparer = commands.add_parser(
        "compare", help="Compare a stock and a JacPython run"
    );
    comparer.add_argument("stock", help="Output directory of the stock CPython run");
    comparer.add_argument("jacpython", help="Output directory of the JacPython run");
    comparer.add_argument("--summary", help="Append the Markdown report to this file");
    comparer.add_argument("--report", help="Write every finding to this JSON file");
    args = parser.parse_args();
    return run(args) if args.command == "run" else compare(args);
}

with entry:__main__ {
    sys.exit(main());
}
