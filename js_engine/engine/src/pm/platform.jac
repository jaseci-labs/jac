"""`os` / `cpu` package.json fields, matched the way bun does (src/install/npm.zig
`Negatable`): a value is a string or a list of names, optionally negated with
"!". Rules of `Negatable.combine`:
  - nothing listed → everything allowed;
  - only negations  → everything except those;
  - only positives  → exactly those;
  - both            → positives minus negations;
  - "any" is a wildcard; unrecognised positive names make the package
    installable nowhere (bun: had_unrecognized_values → none).
"""

import from engine.src.pm.json { JVal, jv_str_list, JV_MISSING, JV_NULL }

glob:priv _OS_NAMES: list[str] = [
         "aix",
         "darwin",
         "freebsd",
         "linux",
         "openbsd",
         "sunos",
         "win32",
         "android"
     ],
     _CPU_NAMES: list[str] = [
         "arm",
         "arm64",
         "ia32",
         "mips",
         "mipsel",
         "ppc",
         "ppc64",
         "s390",
         "s390x",
         "x32",
         "x64"
     ];

"""Name bun uses for the platform this binary runs on."""
def:pub pm_current_os -> str {
    return "linux";
}

def:pub pm_current_cpu -> str {
    return "x64";
}

"""Evaluate a Negatable list against `current`. `known` is the vocabulary."""
def _negatable_matches(values: list[str], known: list[str], current: str) -> bool {
    added: list[str] = [];
    removed: list[str] = [];
    wildcard: bool = False;
    unrecognized: bool = False;
    for raw in values {
        v: str = raw;
        if v == "" {
            continue;
        }
        if v == "any" {
            wildcard = True;
            continue;
        }
        if v == "none" {
            unrecognized = True;
            continue;
        }
        neg: bool = v.startswith("!");
        if neg {
            v = v[1:];
        }
        if not (v in known) {
            if not neg {
                unrecognized = True;
            }
            continue;
        }
        if neg {
            removed.append(v);
        } else {
            added.append(v);
        }
    }
    if wildcard {
        # all_value minus removed
        return not (current in removed);
    }
    if len(added) == 0 and len(removed) == 0 {
        if unrecognized {
            return False;
        }
        return True;
    }
    if len(added) == 0 {
        return not (current in removed);
    }
    if len(removed) == 0 {
        return current in added;
    }
    return (current in added) and not (current in removed);
}

"""True when a package with this `os` field (JSON string/array, or missing)
installs on `os_name`."""
def:pub pm_os_matches(field: JVal, os_name: str) -> bool {
    if field.kind == JV_MISSING or field.kind == JV_NULL {
        return True;
    }
    return _negatable_matches(jv_str_list(field), _OS_NAMES, os_name);
}

def:pub pm_cpu_matches(field: JVal, cpu_name: str) -> bool {
    if field.kind == JV_MISSING or field.kind == JV_NULL {
        return True;
    }
    return _negatable_matches(jv_str_list(field), _CPU_NAMES, cpu_name);
}

"""bun's lockfile / `PackageVersion.os` keeps the combined bitset, not the raw
list; a field that ends up empty ("[]") or all-inclusive is omitted from the
lockfile. This mirrors `meta.os != .all` for the writer."""
def:pub pm_platform_field_is_all(field: JVal, known_os: bool) -> bool {
    if field.kind == JV_MISSING or field.kind == JV_NULL {
        return True;
    }
    vals: list[str] = jv_str_list(field);
    known: list[str] = _OS_NAMES;
    if not known_os {
        known = _CPU_NAMES;
    }
    for name in known {
        if not _negatable_matches(vals, known, name) {
            return False;
        }
    }
    return True;
}

"""The field as bun's `Negatable.toJson` prints it into bun.lock: recomputed
from the bitset in NameMap order, using whichever of the included / negated
forms is shorter — `"linux"`, `"!win32"`, or `[ "linux", "darwin", ]` (bun
leaves the trailing ", " before the bracket). "none" when nothing matches."""
def:pub pm_platform_to_json(field: JVal, known_os: bool) -> str {
    vals: list[str] = jv_str_list(field);
    known: list[str] = _OS_NAMES;
    if not known_os {
        known = _CPU_NAMES;
    }
    included: list[str] = [];
    excluded: list[str] = [];
    for name in known {
        if _negatable_matches(vals, known, name) {
            included.append(name);
        } else {
            excluded.append(name);
        }
    }
    if len(included) == 0 {
        return "\"none\"";
    }
    print_included: bool = len(excluded) > len(included);
    one: bool = (print_included and len(included) == 1)
        or ((not print_included) and len(excluded) == 1);
    out: list[str] = [];
    if not one {
        out.append("[ ");
    }
    for name in known {
        incl: bool = name in included;
        if incl and print_included {
            out.append("\"" + name + "\"");
            if one {
                return "".join(out);
            }
            out.append(", ");
        } elif (not incl) and (not print_included) {
            out.append("\"!" + name + "\"");
            if one {
                return "".join(out);
            }
            out.append(", ");
        }
    }
    out.append("]");
    return "".join(out);
}
