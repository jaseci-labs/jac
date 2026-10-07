"""CI guard: all NATIVE_KIND_* values in native_kinds.jac must be unique."""
import re;
import sys;
import from pathlib { Path }

glob ROOT = Path(__file__).resolve().parents[2],
     KINDS_FILE = ROOT / "engine/src/builtins/native_kinds.jac",
     PAT = re.compile(r"\b(NATIVE_KIND_\w+)\s*:\s*int\s*=\s*(\d+)\s*[,;]");

# One combined `glob:pub NATIVE_KIND_A: int = 1, NATIVE_KIND_B: int = 2, ...;`
# declaration, or one `glob:pub` per kind.
def main -> int {
    text = KINDS_FILE.read_text();
    seen: dict[int, str] = {};
    dups: list[tuple[str, int, str]] = [];
    for (name, val_s) in PAT.findall(text) {
        val = int(val_s);
        if val in seen {
            dups.append((name, val, seen[val]));
        } else {
            seen[val] = name;
        }
    }
    if dups {
        print("Duplicate NATIVE_KIND_* values:", file=sys.stderr);
        for (name, val, first) in dups {
            print(f"  {name} = {val} (already used by {first})", file=sys.stderr);
        }
        return 1;
    }
    print(f"OK: {len(seen)} unique NATIVE_KIND_* values");
    return 0;
}

with entry:__main__ {
    raise SystemExit(main());
}
