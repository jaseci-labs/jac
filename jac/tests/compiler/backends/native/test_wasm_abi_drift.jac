"""Drift tripwires for the hand-synced wasm ABI name sets.

The MIR backend's runtime ABI table (`MIR_RUNTIME_ABI`, `MIR_OSP_ABI`) names
the floor functions it calls and their types, and the floor (runtime/**.jac)
defines them; the extern MIR declares must be the floor's own signature, or a
call whose types differ in width traps on wasm32. The last test holds the two
to one spelling.

The wasm import contract lives in four places kept in sync by hand:
`_ABI64_ADAPTED` (wasm_build.jac) must mirror the `__jac64_*` adapters defined
in wasm_rt/jac_abi64.c, and `WASM_HOST_ABI` (wasm_host_abi.jac) must mirror
the host functions actually implemented by make_jac_host in
client/wasm_host.jac. A missed edit surfaces at link time at best and
as a silent `unreachable` trap in the browser at worst; these tests fail it
in CI instead.
"""

import re;

import jaclang;
import from pathlib { Path }
import from jaclang.compiler.backends.native.wasm_build { _ABI64_ADAPTED }
import from jaclang.compiler.backends.native.wasm_host_abi { WASM_HOST_ABI }
import from jaclang.compiler.backends.native.mir.runtime_abi {
    MIR_OSP_ABI,
    MIR_RUNTIME_ABI
}
import from tests.support { unit_source }

glob _PKG_DIR: Path = Path(str(jaclang.__file__)).parent;

test "_ABI64_ADAPTED matches the adapters defined in jac_abi64.c" {
    c_src = (
        _PKG_DIR / "compiler" / "backends" / "native" / "wasm_rt" / "jac_abi64.c"
    ).read_text(
        encoding="utf-8"
    );
    defined = {str(m) for m in re.findall(r"__jac64_(\w+)\s*\(", c_src)};
    adapted = {str(x) for x in _ABI64_ADAPTED};
    assert defined == adapted , (
        f"only in .c: {sorted(defined - adapted)}; "
        f"only in _ABI64_ADAPTED: {sorted(adapted - defined)}"
    );
}

test "WASM_HOST_ABI matches the host functions in wasm_host.jac" {
    host_src = unit_source(_PKG_DIR / "client" / "wasm_host.jac");
    implemented = {str(m) for m in re.findall(r'"(\w+)": lambda', host_src)};
    declared = {str(x) for x in WASM_HOST_ABI};
    assert implemented == declared , (
        f"only in host impl: {sorted(implemented - declared)}; "
        f"only in WASM_HOST_ABI: {sorted(declared - implemented)}"
    );
}

"""What each runtime ABI spec may be declared as in the floor. A `ref` is a
heap reference to MIR and a Jac `int` address to the floor, which is what the
extern declares (mir_runtime_abi)."""
glob _FLOOR_SPELLINGS: dict[str, set[str]] = {
         "int": {"int"},
         "ref": {"int"},
         "bool": {"bool"},
         "float": {"float"},
         "none": {"None"},
         "i32": {"i32"},
         "str.ref": {"ptr[u8]"},
         "any": {"any"},
         "str": {"str"},
         "list.int": {"list[int]"},
         "opt.list.any": {"(list[any] | None)"},
         "fn.slot": {"Callable[([any, any], any)]"},
         "fn.pred": {"Callable[([int], bool)]"}
     };

def _floor_signatures -> dict[str, tuple[str, list[str]]] {
    found: dict[str, tuple[str, list[str]]] = {};
    decl = re.compile(
        r"def:pub\s+(\w+)\s*(?:\((.*?)\))?\s*(?:->\s*([^;{]+?))?\s*;", re.S
    );
    for path in sorted((_PKG_DIR / "runtime").rglob("*.jac")) {
        if "impl" in path.parts or "python" in path.parts {
            continue;
        }
        for m in decl.finditer(path.read_text(encoding="utf-8")) {
            params: list[str] = [];
            depth = 0;
            cur = "";
            for ch in str(m.group(2) or "") {
                if ch in "([" {
                    depth += 1;
                } elif ch in ")]" {
                    depth -= 1;
                }
                if ch == "," and depth == 0 {
                    params.append(cur);
                    cur = "";
                } else {
                    cur += ch;
                }
            }
            if cur.strip() {
                params.append(cur);
            }
            types = [
                " ".join(p.split(":", 1)[1].split("=")[0].split()) if ":" in p else ""
                for p in params
            ];
            ret = " ".join(str(m.group(3) or "None").split());
            found[str(m.group(1))] = (ret, types);
        }
    }
    return found;
}

def _spelled(spec: str, floor: str) -> bool {
    if spec == "ptr" {
        return floor.startswith("ptr[");
    }
    return floor in _FLOOR_SPELLINGS.get(spec, set());
}

test "the MIR runtime ABI table declares each floor function as the floor defines it" {
    floor = _floor_signatures();
    drift: list[str] = [];
    for table in (MIR_RUNTIME_ABI, MIR_OSP_ABI) {
        for (name, specs) in table.items() {
            if name not in floor {
                drift.append(f"{name}: no floor definition");
                continue;
            }
            (ret, params) = floor[name];
            if len(params) != len(specs) - 1 {
                drift.append(
                    f"{name}: {len(specs) - 1} parameters in the table, {len(
                        params
                    )} in the floor"
                );
                continue;
            }
            for (spec, spelled) in zip(specs, [ret] + params) {
                if not _spelled(str(spec), spelled) {
                    drift.append(
                        f"{name}: table {specs} vs floor {ret} ({', '.join(params)})"
                    );
                    break;
                }
            }
        }
    }
    assert not drift , "\n".join(drift);
}
