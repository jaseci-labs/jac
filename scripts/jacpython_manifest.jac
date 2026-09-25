"""Recompute the line counts recorded in jac/bootstrap/python/cpython-sources.txt.

Every `# removed:` and `# pruned:` marker carries the pinned CPython source
lines of its path (a directory counts every file below it), and the header
repeats their totals. build_python.zig parses the markers but ignores these
numbers, so this script owns them:

    jac run scripts/jacpython_manifest.jac            # fail on drift
    jac run scripts/jacpython_manifest.jac --write    # rewrite the counts

The archive is the checksum-pinned CPython tarball from sources.json. It is
read from the build cache under jac/.python-build, or from --archive.
"""
import argparse;
import hashlib;
import json;
import re;
import sys;
import tarfile;
import from pathlib { Path }

glob MARKER = re.compile(
    r"^# (?P<path>\S+)(?P<gap>\s+)# (?P<kind>removed|pruned): [\d,]+ source lines$"
);

def locate_archive(repo: Path, explicit: str | None) -> Path {
    pin = json.loads((repo / "jac/bootstrap/python/sources.json").read_text())["cpython"];
    candidate = Path(explicit) if explicit else (
        repo / "jac/.python-build/jacpython/sources" / f"{pin['sha256']}.tar.gz"
    );
    if not candidate.is_file() {
        sys.exit(f"Pinned CPython archive not found: {candidate} (pass --archive)");
    }
    digest = hashlib.sha256(candidate.read_bytes()).hexdigest();
    if digest != pin["sha256"] {
        sys.exit(f"{candidate} does not match the pinned SHA256 {pin['sha256']}");
    }
    return candidate;
}

def archive_lines(archive: Path) -> dict[str, int] {
    counts: dict[str, int] = {};
    with tarfile.open(archive) as bundle {
        for member in bundle.getmembers() {
            if not member.isfile() {
                continue;
            }
            relative = member.name.split("/", 1)[1];
            stream = bundle.extractfile(member);
            if stream is None {
                continue;
            }
            data = stream.read();
            counts[relative] = data.count(b"\n") + int(bool(data) and not data.endswith(b"\n"));
        }
    }
    return counts;
}

def marked_files(path: str, counts: dict[str, int]) -> list[str] {
    if path.endswith("/") {
        return sorted(name for name in counts if name.startswith(path));
    }
    if path not in counts {
        sys.exit(f"Marked path is not in the pinned archive: {path}");
    }
    return [path];
}

def grouped(value: int) -> str {
    return f"{value:,}";
}

with entry {
    parser = argparse.ArgumentParser(
        description="Recompute cpython-sources.txt line counts."
    );
    parser.add_argument("--write", action="store_true");
    parser.add_argument("--archive");
    args = parser.parse_args();
    repo = Path(__file__).resolve().parents[1];
    manifest = repo / "jac/bootstrap/python/cpython-sources.txt";
    counts = archive_lines(locate_archive(repo, args.archive));
    totals = {
        "removed": {"c": [0, 0], "h": [0, 0], "all": [0, 0]},
        "pruned": {"all": [0, 0]}
    };
    lines = manifest.read_text().splitlines();
    updated: list[str] = [];
    for line in lines {
        found = MARKER.match(line);
        if not found {
            updated.append(line);
            continue;
        }
        kind = found["kind"];
        files = marked_files(found["path"], counts);
        size = sum(counts[name] for name in files);
        for name in files {
            totals[kind]["all"][0] += 1;
            totals[kind]["all"][1] += counts[name];
            if kind == "removed" {
                suffix = "c" if name.endswith(".c") else "h";
                totals[kind][suffix][0] += 1;
                totals[kind][suffix][1] += counts[name];
            }
        }
        updated.append(
            f"# {found['path']}{found['gap']}# {kind}: {grouped(size)} source lines"
        );
    }
    removed = totals["removed"];
    pruned = totals["pruned"]["all"];
    excluded = (
        f"#   Excluded: {removed['c'][0]} C files / {grouped(removed['c'][1])} lines; "
        + f"{removed['h'][0]} headers / {grouped(removed['h'][1])} lines."
    );
    summaries = [
        f"#   Total: {removed['all'][0]} files / {grouped(removed['all'][1])} source lines.",
        f"#   Total: {pruned[0]} files / {grouped(pruned[1])} source lines."
    ];
    seen = 0;
    for index in range(len(updated)) {
        if updated[index].startswith("#   Excluded:") {
            updated[index] = excluded;
        } elif updated[index].startswith("#   Total:") and seen < len(summaries) {
            updated[index] = summaries[seen];
            seen += 1;
        }
    }
    text = "\n".join(updated) + "\n";
    if text == manifest.read_text() {
        print("cpython-sources.txt line counts match the pinned archive");
    } elif args.write {
        manifest.write_text(text);
        print("cpython-sources.txt line counts rewritten");
    } else {
        sys.exit("cpython-sources.txt line counts drifted; rerun with --write");
    }
}
