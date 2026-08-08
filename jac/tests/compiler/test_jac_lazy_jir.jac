"""Tests for scoped lazy .jac JIR (part 5): eligibility, dep-only chunking, cascade."""

import os;
import struct;
import tempfile;
import pytest;
import from jaclang.jac0core.cache_paths {
    is_bootstrap_jac_path,
    is_jac_lazy_eligible,
}
import from jaclang.jac0core.jir { FLAG_CHUNKED, HEADER_FMT, HEADER_SIZE }
import from jaclang.jac0core.jir_passes { JirReader, JirWriter }
import from jaclang.jac0core.program { JacProgram }
import from tests.support { JAC_ROOT, TESTS_DIR }

glob FIXTURE = os.path.join(
    TESTS_DIR, "compiler", "fixtures", "jac_lazy_dep", "lib.jac"
);

def _jir_flags(blob: bytes) -> int {
    (_, _, _, _, _, _, _, _, flags) = struct.unpack(
        HEADER_FMT, blob[:HEADER_SIZE]
    );
    return flags;
}

def _env_restore(prev: dict) {
    for (k, v) in prev.items() {
        if v is None {
            os.environ.pop(k, None);
        } else {
            os.environ[k] = v;
        }
    }
}

def _save_env(*keys: str) -> dict {
    out: dict = {};
    for k in keys {
        out[k] = os.environ.get(k);
    }
    return out;
}

test "jac lazy eligibility excludes bootstrap and jaclang self-hosting" {
    jir_jac = os.path.join(JAC_ROOT, "jaclang", "jac0core", "jir.jac");
    unitree = os.path.join(JAC_ROOT, "jaclang", "jac0core", "unitree.jac");
    assert is_bootstrap_jac_path(jir_jac);
    assert not is_jac_lazy_eligible(jir_jac);
    assert not is_jac_lazy_eligible(unitree);
    assert is_jac_lazy_eligible(FIXTURE);
}

test "jaclang internal dep cache is not chunked even with JAC_LAZY_JAC" {
    # Self-hosting modules must stay on the full-hydrate path.
    internal = os.path.join(JAC_ROOT, "jaclang", "jac0core", "constant.jac");
    if not os.path.isfile(internal) {
        pytest.skip("constant.jac missing");
    }
    prev = _save_env("JAC_LAZY_JAC", "JAC_LAZY_JIR");
    try {
        os.environ["JAC_LAZY_JAC"] = "1";
        os.environ["JAC_LAZY_JIR"] = "1";
        prog = JacProgram();
        mod = prog.load_dependency_module(internal);
        writer = JirWriter();
        blob = writer.write_module(mod, sections={}, jac_lazy_dep=True);
        assert (_jir_flags(blob) & FLAG_CHUNKED) == 0 , (
            "jaclang internal module must not use chunked .jac layout"
        );
    } finally {
        _env_restore(prev);
    }
}

test "user dep cache chunks under JAC_LAZY_JAC with lazy parity" {
    if not os.path.isfile(FIXTURE) {
        pytest.skip("fixture missing");
    }
    prev = _save_env("JAC_LAZY_JAC", "JAC_LAZY_JIR");
    try {
        os.environ["JAC_LAZY_JAC"] = "1";
        os.environ["JAC_LAZY_JIR"] = "1";
        prog = JacProgram();
        mod = prog.load_dependency_module(FIXTURE);
        writer = JirWriter();
        blob = writer.write_module(mod, sections={}, jac_lazy_dep=True);
        total = len(writer._nodes);
        assert (_jir_flags(blob) & FLAG_CHUNKED) != 0 , (
            "eligible user dep must write chunked layout"
        );

        os.environ["JAC_LAZY_JIR"] = "0";
        full_reader = JirReader(_source_path=FIXTURE);
        full_mod = full_reader.read_module(blob);
        assert full_mod is not None;
        ref_syms = sorted(full_mod.names_in_scope.keys());

        os.environ["JAC_LAZY_JIR"] = "1";
        lazy_reader = JirReader(_source_path=FIXTURE);
        lazy_mod = lazy_reader.read_module(blob);
        assert lazy_mod is not None;
        eager = lazy_reader.hydrated_node_count;
        assert eager < total // 4 , (
            "lazy eager tier should be well under full module ("
                + str(eager) + " / " + str(total) + ")"
        );
        assert sorted(lazy_mod.names_in_scope.keys()) == ref_syms;

        # Touch one class body: hydrates its chunk only.
        target = None;
        for (nm, sym) in full_mod.names_in_scope.items() {
            if type(sym.decl.name_of).__name__ == "Archetype" {
                target = nm;
                break;
            }
        }
        assert target is not None;
        before = lazy_reader.hydrated_node_count;
        lazy_arch = lazy_mod.names_in_scope[target].decl.name_of;
        _ = lazy_arch.names_in_scope.keys();
        assert lazy_reader.hydrated_node_count > before;
        assert lazy_reader.hydrated_node_count < total;
    } finally {
        _env_restore(prev);
    }
}

test "ineligible source path full-hydrates a chunked .jac cache" {
    if not os.path.isfile(FIXTURE) {
        pytest.skip("fixture missing");
    }
    prev = _save_env("JAC_LAZY_JAC", "JAC_LAZY_JIR");
    try {
        os.environ["JAC_LAZY_JAC"] = "1";
        os.environ["JAC_LAZY_JIR"] = "1";
        prog = JacProgram();
        mod = prog.load_dependency_module(FIXTURE);
        writer = JirWriter();
        blob = writer.write_module(mod, sections={}, jac_lazy_dep=True);
        total = len(writer._nodes);
        assert (_jir_flags(blob) & FLAG_CHUNKED) != 0;

        # Same chunked bytes, but reader treats jaclang paths as ineligible.
        internal_path = os.path.join(
            JAC_ROOT, "jaclang", "jac0core", "constant.jac"
        );
        reader = JirReader(_source_path=internal_path);
        full = reader.read_module(blob);
        assert full is not None;
        assert reader.hydrated_node_count == total , (
            "ineligible path must full-hydrate even when JAC_LAZY_JAC is on"
        );
    } finally {
        _env_restore(prev);
    }
}

test "temp user module outside jaclang is eligible" {
    prev = _save_env("JAC_LAZY_JAC");
    try {
        os.environ["JAC_LAZY_JAC"] = "1";
        with tempfile.TemporaryDirectory() as tmp {
            path = os.path.join(tmp, "sample.jac");
            with open(path, "w", encoding="utf-8") as f {
                f.write(
                    "class Widget {\n"
                        + "    has n: int = 0;\n"
                        + "    can inc -> int { return self.n + 1; }\n"
                        + "}\n"
                );
            }
            assert is_jac_lazy_eligible(path);
            prog = JacProgram();
            mod = prog.load_dependency_module(path);
            blob = JirWriter().write_module(mod, sections={}, jac_lazy_dep=True);
            assert (_jir_flags(blob) & FLAG_CHUNKED) != 0;
        }
    } finally {
        _env_restore(prev);
    }
}
