# na-runtime coverage ratchet: the na synthesizer must not bridge fewer public
# surface items than the recorded floor (na-coverage-floor.toml).
#
# Recomputes coverage from render_na_source for each bridge .so present in the build
# tree and asserts bridged >= floor (a one-way ratchet).  Needs NO LLVM shim -- it
# inspects the SYNTHESIZED source's item counts, not a compiled binary.
import tomllib;
import from pathlib { Path }
import from jaclang.compiler.rust_bridge._blob { parse }
import from jaclang.compiler.rust_bridge._elf { read_jac_bridge_section }
import from jaclang.compiler.rust_bridge._synth { render_na_source }


glob _FLOOR_TOML = Path(__file__).resolve().parent / "na-coverage-floor.toml";


def _so_dir -> object {
    here = Path(__file__).resolve();
    for base in [here.parents[2], here.parents[3]] {  # loader/, bridges/
        for build in ["release", "debug"] {
            d = base / "target" / build;
            if d.is_dir() {
                return d;
            }
        }
    }
    return None;
}


def _load_floor -> dict {
    with _FLOOR_TOML.open("rb") as fh {
        return tomllib.load(fh);
    }
}


test "na coverage does not regress" {
    floor = _load_floor();
    d = _so_dir();
    if d is None {
        return;
    }
    for so_name in sorted(floor) {
        entry = floor[so_name];
        # floor keys are the '.'-> '_' form; map back to the real filename.
        so = d / so_name.replace("_so", ".so");
        if not so.is_file() {
            continue;
        }
        res = render_na_source(parse(read_jac_bridge_section(str(so))), so.name);
        total = res.bridged + len(res.skips);
        skipitems = [s.item for s in res.skips];
        assert res.bridged >= entry["bridged"] , f"{so.name}: na bridged {res.bridged} < floor {entry[
            'bridged'
        ]}; skips={skipitems}";
        assert total >= entry["total"] , f"{so.name}: total surface {total} < recorded {entry[
            'total'
        ]} (fixture shrank?)";
    }
}


test "floor file is not empty" {
    assert _load_floor() , "na-coverage-floor.toml has no entries";
}
