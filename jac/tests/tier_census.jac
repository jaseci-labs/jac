"""Which Jac programs run on the native tier, and how the rest fall short.

Every program in the corpus is run on the Python tier and on the native
tier, and the native run is put in one class:

    same      it ran and printed what the Python tier printed
    refused   the compiler declined to lower it, and said why
    fails     it ran and stopped with an error the Python tier does not raise
    differs   it ran to the end and printed something else
    hangs     it did not finish in time
    crashes   the program, or the compiler lowering it, died on a signal

The classes are ordered from best to worst. A refusal is loud and safe; a
different answer is neither, so it ranks below a failure.

The result is kept in `tier_census.json` next to this file. `--check`
compares a fresh census with it and fails when a program moved to a worse
class, so the native share can only go up; `--update` rewrites it. A program
the Python tier cannot run cleanly, or does not print the same thing twice,
has no reference to compare with and is left out of the classes.

    jac run tests/tier_census.jac              print the census
    jac run tests/tier_census.jac --update     rewrite the baseline
    jac run tests/tier_census.jac --check      fail on a regression
"""
import json;
import os;
import re;
import subprocess;
import sys;
import from concurrent.futures { ThreadPoolExecutor }
import from pathlib { Path }

glob CLASSES: list[str] = [
         "same",
         "refused",
         "fails",
         "differs",
         "hangs",
         "crashes"
     ],
     SKIPPED: str = "skipped",
     UNREPEATABLE: str = "the Python tier is not repeatable",
     BASELINE: str = "tier_census.json",
     RUN_SECONDS: int = 60,
     JAC_ROOT: str = str(Path(__file__).resolve().parent.parent),
     CORPUS: list[str] = ["tests/language/fixtures", "examples"],
     EXCLUDED_DIRS: tuple[str, ...] = ("jaclang_org", "node_modules", ".jac", "bin"),
     ANNEX_SUFFIXES: tuple[str, ...] = (
         ".impl.jac",
         ".test.jac",
         ".cl.jac",
         ".sv.jac",
         ".na.jac"
     ),
     REFUSAL: str = r"error\[(E\d+)\]: ([^\n]*)",
     UNORDERED: dict[str, str] = {
         "tests/language/fixtures/concurrency.jac": "its output depends on thread timing"
     },
     QUOTED: str = r"'[^']*'",
     MODULE_TAG: str = r"\$[A-Za-z0-9_]+_[0-9a-f]{8}",
     UNCAUGHT: str = r"Uncaught exception: ([^\n]*)",
     LOCATION: str = r" at \S+:\d+$",
     CASCADE_KINDS: tuple[str, ...] = (
         "function",
         "method",
         "constructor",
         "ability",
         "function signature",
         "call through a value"
     );

obj Outcome {
    has kind: str,
        reason: str = "";

    def record -> dict[str, str] {
        if self.reason {
            return {"class": self.kind, "reason": self.reason};
        }
        return {"class": self.kind};
    }
}

obj Run {
    has code: int,
        out: str,
        err: str,
        timed_out: bool = False;
}

def rank(kind: str) -> int {
    return CLASSES.index(kind) if kind in CLASSES else -1;
}

"""The programs of the corpus: a module with an entry block that is not an
annex of another module."""
def corpus_programs(roots: (list[str] | None) = None) -> list[str] {
    found: list[str] = [];
    for start in (roots or CORPUS) {
        top = os.path.join(JAC_ROOT, start);
        for (folder, subdirs, files) in os.walk(top) {
            subdirs[:] = sorted(
                [
                    d
                    for d in subdirs
                    if d not in EXCLUDED_DIRS
                ]
            );
            for name in sorted(files) {
                if not name.endswith(".jac") or name.endswith(ANNEX_SUFFIXES) {
                    continue;
                }
                path = os.path.join(folder, name);
                try {
                    text = Path(path).read_text(encoding="utf-8");
                } except (OSError, UnicodeError) {
                    continue;
                }
                if "with entry" in text {
                    found.append(os.path.relpath(path, JAC_ROOT));
                }
            }
        }
    }
    return sorted(found);
}

def jac_argv(*args: str) -> list[str] {
    return [
        sys.executable,
        "-c",
        "import runpy\nrunpy.run_module('jaclang', run_name='__main__', alter_sys=True)",
        *args
    ];
}

def run_tier(program: str, tier: str) -> Run {
    path = os.path.join(JAC_ROOT, program);
    try {
        done = subprocess.run(
            jac_argv("run", "-b", tier, path),
            cwd=os.path.dirname(path),
            capture_output=True,
            text=True,
            errors="replace",
            timeout=RUN_SECONDS,
            stdin=subprocess.DEVNULL
        );
    } except subprocess.TimeoutExpired {
        return Run(code=0, out="", err="", timed_out=True);
    }
    return Run(code=done.returncode, out=done.stdout, err=done.stderr);
}

"""Why a program was refused: the code and message of the diagnostic that
names the construct.

A refusal cascades: the expression that cannot be lowered refuses its
function, which refuses every caller. The first diagnostic that is not about
a callable is the cause; a callable's own name says nothing, so it is taken
out, and programs refused for the same construct share a reason."""
def refusal_reason(err: str) -> str {
    found = re.findall(REFUSAL, err);
    if not found {
        return "";
    }
    chosen = found[0];
    for (code, message) in found {
        if not any(f" for {kind} '" in message for kind in CASCADE_KINDS) {
            chosen = (code, message);
            break;
        }
    }
    (code, message) = chosen;
    if any(f" for {kind} '" in message for kind in CASCADE_KINDS) {
        message = re.sub(QUOTED, "'_'", message);
    }
    message = re.sub(MODULE_TAG, "", message);
    return f"{code} {message.strip()}"[:140];
}

def last_line(text: str) -> str {
    lines = [
        line.strip()
        for line in text.split("\n")
        if line.strip()
    ];
    return re.sub(QUOTED, "'_'", lines[-1])[:120] if lines else "";
}

def classify(program: str) -> Outcome {
    if program in UNORDERED {
        return Outcome(kind=SKIPPED, reason=UNORDERED[program]);
    }
    reference = run_tier(program, "python");
    if reference.timed_out {
        return Outcome(kind=SKIPPED, reason="the Python tier did not finish");
    }
    if reference.code != 0 {
        return Outcome(kind=SKIPPED, reason="the Python tier fails");
    }
    again = run_tier(program, "python");
    if again.timed_out or again.code != 0 or again.out != reference.out {
        return Outcome(kind=SKIPPED, reason=UNREPEATABLE);
    }
    native = run_tier(program, "native");
    if native.timed_out {
        return Outcome(kind="hangs");
    }
    uncaught = re.search(UNCAUGHT, native.err);
    if uncaught is not None {
        return Outcome(
            kind="fails", reason=re.sub(LOCATION, "", uncaught.group(1)).strip()[:120]
        );
    }
    if native.code < 0 or "died with signal" in native.err {
        where = "the compiler" if "died with signal" in native.err else "the program";
        return Outcome(kind="crashes", reason=where);
    }
    if native.code == 0 {
        if native.out == reference.out {
            return Outcome(kind="same");
        }
        return Outcome(kind="differs");
    }
    why = refusal_reason(native.err);
    if why {
        return Outcome(kind="refused", reason=why);
    }
    return Outcome(kind="fails", reason=last_line(native.err));
}

def take_census(programs: list[str], jobs: int = 0) -> dict[str, Outcome] {
    workers = jobs or max(1, (os.cpu_count() or 2) // 2);
    with ThreadPoolExecutor(max_workers=workers) as pool {
        outcomes = list(pool.map(classify, programs));
    }
    return dict(zip(programs, outcomes));
}

def baseline_path -> str {
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), BASELINE);
}

def read_baseline -> dict[str, Outcome] {
    try {
        raw = json.loads(Path(baseline_path()).read_text(encoding="utf-8"));
    } except (OSError, ValueError) {
        return {};
    }
    return {
        program: Outcome(
            kind=str(rec.get("class", "")), reason=str(rec.get("reason", ""))
        ) for (program, rec) in raw.get("programs", {}).items()
    };
}

def tally(census: dict[str, Outcome]) -> dict[str, int] {
    counts: dict[str, int] = {kind: 0 for kind in CLASSES + [SKIPPED]};
    for outcome in census.values() {
        counts[outcome.kind] = counts.get(outcome.kind, 0) + 1;
    }
    return counts;
}

def write_baseline(census: dict[str, Outcome]) {
    body = {
        "summary": tally(census),
        "programs": {program: census[program].record() for program in sorted(census)}
    };
    Path(baseline_path()).write_text(
        json.dumps(body, indent=2, sort_keys=False) + "\n", encoding="utf-8"
    );
}

"""Programs that moved to a worse class, and programs that moved to a better
one or are new: the first break the ratchet, the second make the baseline
stale.

A program recorded as not repeatable is left out of both. It prints
something that varies, a random number or a time, and two runs agree now and
then by chance; the class it gets on such a run says nothing about it."""
def compare(
    census: dict[str, Outcome], baseline: dict[str, Outcome]
) -> tuple[list[str], list[str]] {
    worse: list[str] = [];
    stale: list[str] = [];
    for (program, now) in sorted(census.items()) {
        before = baseline.get(program);
        if before is None {
            stale.append(f"{program}: new, {now.kind}");
            continue;
        }
        if before.kind == now.kind
            or (before.kind == SKIPPED and before.reason == UNREPEATABLE) {
            continue;
        }
        line = f"{program}: {before.kind} -> {now.kind}";
        if now.reason {
            line += f" ({now.reason})";
        }
        if now.kind == SKIPPED or before.kind == SKIPPED {
            stale.append(line);
        } elif rank(now.kind) > rank(before.kind) {
            worse.append(line);
        } else {
            stale.append(line);
        }
    }
    for program in sorted(baseline) {
        if program not in census {
            stale.append(f"{program}: no longer in the corpus");
        }
    }
    return (worse, stale);
}

def summarize(census: dict[str, Outcome]) -> str {
    counts = tally(census);
    compared = sum(counts[kind] for kind in CLASSES);
    lines: list[str] = [
        f"{len(census)} programs, {compared} with a Python-tier reference",
        "  " + ", ".join(f"{counts[kind]} {kind}" for kind in CLASSES + [SKIPPED])
    ];
    if compared {
        lines.append(f"  native share: {100.0 * counts['same'] / compared:.1f}%");
    }
    reasons: dict[str, list[str]] = {};
    for (program, outcome) in census.items() {
        if outcome.kind in ("refused", "fails", SKIPPED) {
            key = f"{outcome.kind}: {outcome.reason or 'no reason given'}";
            reasons.setdefault(key, []).append(program);
        }
    }
    if reasons {
        lines.append("");
        lines.append("why programs are not native, most common first:");
        ranked = sorted([(-len(named), key) for (key, named) in reasons.items()]);
        for (negated, key) in ranked {
            lines.append(f"  {-negated:3d}  {key}");
        }
    }
    for kind in ("differs", "hangs", "crashes") {
        named = sorted(
            p
            for (p, o) in census.items()
            if o.kind == kind
        );
        if named {
            lines.append("");
            lines.append(f"{kind}:");
            for program in named {
                note = f"  ({census[program].reason})"
                    if census[program].reason
                    else "";
                lines.append(f"  {program}{note}");
            }
        }
    }
    return "\n".join(lines);
}

with entry:__main__ {
    flags = [
        arg
        for arg in sys.argv[1:]
        if arg.startswith("--")
    ];
    roots = [
        arg
        for arg in sys.argv[1:]
        if not arg.startswith("--")
    ];
    programs = corpus_programs(roots or None);
    census = take_census(programs);
    print(summarize(census));
    if "--update" in flags {
        write_baseline(census);
        print(f"\nwrote {baseline_path()}");
    } elif "--check" in flags {
        held = {
            program: outcome
            for (program, outcome) in read_baseline().items()
            if not roots or any(program.startswith(start) for start in roots)
        };
        (worse, stale) = compare(census, held);
        for line in worse {
            print(f"WORSE  {line}");
        }
        for line in stale {
            print(f"STALE  {line}");
        }
        if worse or stale {
            print(
                "\nthe census no longer matches tests/tier_census.json; fix the "
                "regressions, or run `jac run tests/tier_census.jac --update` and "
                "commit the result if every change is an improvement"
            );
            sys.exit(1);
        }
    }
}
