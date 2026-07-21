import re;
import sys;
import from pathlib { Path }

glob TESTS_DIR: str = "jac/jaclang/scale/tests",
     BASELINE_FILE: str = "jac/jaclang/scale/scripts/test_hygiene_baseline.txt",
     RULES: list = [
         ("assert-true", re.compile(r"\bassert\s+True\b")),
         (
             "hand-rolled-fake",
             re.compile(
                 r"\b(obj|class)\s+_Fake(Redis|Mongo|Firestore|Gcs|GCS|S3|Storage|Db|Client)"
             )
         ),
         ("swallowed-except", re.compile(r"\}\s*except[^{]*\{\s*0;?\s*\}"))
     ],
     STATUS_IN: any = re.compile(r"status_code\s+in\s+[\[(]([^\])]*)[\])]");


def emit(msg: str) {
    sys.stdout.write(msg + "\n");
}


def scan(path: Path) -> list {
    hits = [];
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines();
    idx = 0;
    for line in lines {
        idx += 1;
        for pair in RULES {
            rule = pair[0];
            rx: any = pair[1];
            if rx.search(line) {
                hits.append((idx, rule, line.strip()));
            }
        }
        m: any = STATUS_IN.search(line);
        if m {
            codes = [
                c.strip()
                for c in m.group(1).split(",")
                if c.strip()
            ];
            has_2xx = any([c.startswith("2") for c in codes]);
            has_err = any([(c[:1] in ("4", "5")) for c in codes]);
            if has_2xx and has_err {
                hits.append((idx, "broad-status", line.strip()));
            }
        }
        if re.search(r"print\([^)]*\[skip", line) {
            nxt = lines[idx] if idx < len(lines) else "";
            if re.match(r"\s*return\s*;?\s*$", nxt) {
                hits.append((idx, "silent-skip", line.strip()));
            }
        }
    }
    return hits;
}


def load_baseline -> set {
    p = Path(BASELINE_FILE);
    if not p.exists() {
        return set();
    }
    keys = set();
    for line in p.read_text().splitlines() {
        clean = line.split("#", 1)[0].strip();
        if clean {
            keys.add(clean);
        }
    }
    return keys;
}


def run -> int {
    tests_root = Path(TESTS_DIR);
    baseline = load_baseline();
    files = [
        p
        for p in tests_root.rglob("test_*.jac")
        if "fixtures" not in p.parts
    ];
    new_hits = 0;
    grandfathered = 0;
    for p in sorted(files) {
        rel = p.relative_to(tests_root.parent);
        for (ln, rule, text) in scan(p) {
            if f"{rel}:{rule}" in baseline {
                grandfathered += 1;
                continue;
            }
            new_hits += 1;
            emit(f"{rel}:{ln}: [{rule}] {text}");
        }
    }
    if new_hits {
        emit(
            f"\n{new_hits} NEW test-hygiene violation(s). Rules + baseline in jac/jaclang/scale/scripts/."
        );
        return 1;
    }
    emit(
        f"OK: {len(files)} scale test files clean ({grandfathered} grandfathered in baseline)."
    );
    return 0;
}


with entry:__main__ {
    sys.exit(run());
}
