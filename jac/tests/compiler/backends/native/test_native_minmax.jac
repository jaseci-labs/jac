"""Native numeric extrema agree with Python, including ties and unordered floats."""
import ctypes;
import math;
import itertools;
import from tests.support { compile_native, get_func }

glob _ENGINES: list[any] = [];
def engine -> any {
    if not _ENGINES {
        (eng, _) = compile_native("minmax.jac");
        _ENGINES.append(eng);
    }
    return _ENGINES[0];
}

test "all positional arguments and list elements participate" {
    check = get_func(
        engine(),
        "extrema",
        ctypes.c_int64,
        ctypes.c_int64,
        ctypes.c_int64,
        ctypes.c_int64,
        ctypes.c_int64
    );
    for values in itertools.permutations([-23, 0, 71]) {
        for mode in range(4) {
            expected = min(values) if mode % 2 == 0 else max(values);
            assert check(*values, mode) == expected;
        }
    }
}

test "float ties retain the first value and NaNs follow ordered comparisons" {
    check = get_func(
        engine(),
        "floating",
        ctypes.c_double,
        ctypes.c_double,
        ctypes.c_double,
        ctypes.c_double,
        ctypes.c_int64
    );
    for values in [
        (0.0, -0.0, 0.0),
        (-0.0, 0.0, -0.0),
        (float("nan"), 2.0, 1.0),
        (2.0, float("nan"), 1.0),
        (2.0, 1.0, float("nan")),
        (float("inf"), 4.5, -float("inf"))
    ] {
        for mode in range(4) {
            expected = min(values) if mode % 2 == 0 else max(values);
            actual = check(*values, mode);
            if math.isnan(expected) {
                assert math.isnan(actual);
            } else {
                assert actual == expected;
                assert math.copysign(1.0, actual) == math.copysign(1.0, expected);
            }
        }
    }
}

test "empty input raises or returns default without reading element zero" {
    assert get_func(engine(), "empty_checks", ctypes.c_bool)();
}

test "PNG predictor idiom lowers without rewriting the caller" {
    assert get_func(engine(), "paeth", ctypes.c_bool)();
}

test "boolean unsigned and singleton lists preserve scalar ordering" {
    assert get_func(engine(), "scalar_checks", ctypes.c_bool)();
}

test "extrema also link and run in a standalone native binary" {
    import tempfile;
    import from pathlib { Path }
    import from tests.support { NATIVE_FIXTURES, native_build, native_run }
    with tempfile.TemporaryDirectory() as directory {
        binary = str(Path(directory) / "minmax");
        native_build(str(Path(NATIVE_FIXTURES) / "minmax.jac"), binary);
        assert "NATIVE MINMAX PASS" in native_run(binary);
    }
}

test "sized scalars and eager defaults preserve values and input order" {
    assert get_func(engine(), "more_scalars", ctypes.c_bool)();
}

test "unsupported keyword forms refuse lowering instead of discarding arguments" {
    import tempfile;
    import from pathlib { Path }
    import from tests.support { native_force_opts }
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.driver.na_coverage {
        na_coverage_begin,
        na_coverage_end
    }
    for expression in [
        "min([1, 2], key=abs)",
        "max([1, 2], key=abs)",
        "min([1, 2], `default='missing')"
    ] {
        with tempfile.TemporaryDirectory() as directory {
            source = Path(directory) / "refuse.jac";
            source.write_text("def probe -> any { return " + expression + "; }");
            prog = JacProgram();
            na_coverage_begin();
            try {
                prog.compile(file_path=str(source), options=native_force_opts());
            } finally {
                coverage = na_coverage_end();
            }
            said = " ".join(
                str(seam) for rec in coverage.values() for seam in (rec["seams"] or [])
            );
            assert "builtin call" in said , f"must refuse {expression}: {said}";
        }
    }
}
