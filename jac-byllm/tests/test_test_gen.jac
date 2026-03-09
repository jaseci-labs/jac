"""Tests for the jac test-gen infrastructure.

Tests cover:
  - Spec extraction from a compiled MTIR map
  - Test block generation via generate_tests_for_spec (mocks generate_test_block)
  - Output file rendering and hash comments
  - Incremental (hash-based) skipping via read_existing_hashes
"""

import io;
import os;
import re;
import sys;
import tempfile;
import unittest.mock;
import from pathlib { Path }
import from jaclang { JacRuntime }
import from jaclang { JacRuntimeInterface as Jac }
import from jaclang.jac0core.mtp { FunctionInfo, ClassInfo, EnumInfo, FieldInfo, ParamInfo }
import from jaclang.jac0core.program { JacProgram }

import from byllm.test_gen.spec_extractor {
    extract_specs, FunctionSpec, ParamSpec, ClassSpec, EnumSpec, FieldSpec
}
import from byllm.test_gen.code_generator {
    generate_tests_for_spec, TestGenResult, JacTestBlock
}
import from byllm.test_gen.output_writer { write_test_file, read_existing_hashes }

glob FIXTURE_DIR = os.path.join(os.path.dirname(__file__), "fixtures");

def fixture_path(fixture: str) -> str {
    return os.path.abspath(os.path.join(FIXTURE_DIR, fixture));
}

# ---------------------------------------------------------------------------
# Spec Extraction Tests
# ---------------------------------------------------------------------------

test "spec extraction: finds generate_password and generate_specific_number" {
    prog = JacProgram();
    prog.compile(fixture_path("llm_semstrings.jac"));
    mtir_map = JacRuntime.program.mtir_map;
    specs = extract_specs(mtir_map);

    names = [s.name for s in specs];
    assert "generate_password" in names, f"expected generate_password in {names}";
    assert "generate_specific_number" in names, f"expected generate_specific_number in {names}";
}

test "spec extraction: generate_password has correct semstr and return type" {
    prog = JacProgram();
    prog.compile(fixture_path("llm_semstrings.jac"));
    specs = extract_specs(JacRuntime.program.mtir_map);

    pw_spec = next((s for s in specs if s.name == "generate_password"), None);
    assert pw_spec is not None, "generate_password spec not found";
    assert pw_spec.return_type_str == "str", f"expected 'str', got '{pw_spec.return_type_str}'";
    assert pw_spec.semstr is not None, "expected semstr to be set";
    assert "at least 8 characters" in pw_spec.semstr, "semstr should mention 8 characters";
    assert pw_spec.params == [], f"expected no params, got {pw_spec.params}";
}

test "spec extraction: generate_specific_number has int return type with exact value in semstr" {
    prog = JacProgram();
    prog.compile(fixture_path("llm_semstrings.jac"));
    specs = extract_specs(JacRuntime.program.mtir_map);

    num_spec = next((s for s in specs if s.name == "generate_specific_number"), None);
    assert num_spec is not None, "generate_specific_number spec not found";
    assert num_spec.return_type_str == "int", f"expected 'int', got '{num_spec.return_type_str}'";
    assert "120597" in (num_spec.semstr or ""), "semstr should mention the specific number";
}

test "spec extraction: spec_hash is stable and 16-hex-chars" {
    prog = JacProgram();
    prog.compile(fixture_path("llm_semstrings.jac"));
    specs = extract_specs(JacRuntime.program.mtir_map);

    pw_spec = next((s for s in specs if s.name == "generate_password"), None);
    assert pw_spec is not None;
    h1 = pw_spec.spec_hash();
    h2 = pw_spec.spec_hash();
    assert h1 == h2, "spec_hash must be deterministic";
    assert len(h1) == 16, f"expected 16-char hex hash, got len={len(h1)}: '{h1}'";
    assert re.match(r"^[0-9a-f]{16}$", h1), f"expected hex string, got '{h1}'";
}

test "spec extraction: spec_hash changes when a field type changes" {
    # Build a spec with yod: int, compute hash, change to str, verify hash differs
    spec_int = FunctionSpec(
        qualified_key="mod.fn",
        name="fn",
        semstr="test function",
        params=[],
        return_type_str="Person",
        return_type_detail=ClassSpec(
            name="Person",
            semstr=None,
            fields=[FieldSpec(name="yod", type_str="int", semstr="Year of death")]
        )
    );
    spec_str = FunctionSpec(
        qualified_key="mod.fn",
        name="fn",
        semstr="test function",
        params=[],
        return_type_str="Person",
        return_type_detail=ClassSpec(
            name="Person",
            semstr=None,
            fields=[FieldSpec(name="yod", type_str="str", semstr="Year of death")]
        )
    );
    assert spec_int.spec_hash() != spec_str.spec_hash(), (
        "spec_hash should differ when field type changes from int to str"
    );
}

test "spec extraction: structured return type yields ClassSpec or EnumSpec detail" {
    prog = JacProgram();
    prog.compile(fixture_path("with_llm_type.jac"));
    specs = extract_specs(JacRuntime.program.mtir_map);

    assert len(specs) > 0, "expected at least one spec from with_llm_type.jac";
    has_complex = any(s.return_type_detail is not None for s in specs);
    assert has_complex, "expected at least one spec with a structured return type detail (ClassSpec/EnumSpec)";
}

# ---------------------------------------------------------------------------
# Code Generator Tests (monkeypatched generate_test_block)
# ---------------------------------------------------------------------------

test "code generator: returns test_code from a successful by llm() call" {
    spec = FunctionSpec(
        qualified_key="test.generate_password",
        name="generate_password",
        semstr="Generates a password with at least 8 characters.",
        params=[],
        return_type_str="str",
        return_type_detail=None
    );

    fake_block = JacTestBlock(
        code='test "generate_password: length check" {\n    result = generate_password();\n    assert len(result) >= 8;\n}'
    );

    with unittest.mock.patch(
        "byllm.test_gen.code_generator.generate_test_block",
        return_value=fake_block
    ) {
        result = generate_tests_for_spec(spec, model_name="openai/gpt-4o", temperature=0.2);
    }

    assert result.error is None, f"unexpected error: {result.error}";
    assert result.test_code is not None;
    assert 'test "generate_password: length check"' in result.test_code;
    assert "assert len(result) >= 8" in result.test_code;
}

test "code generator: handles LLM API failure gracefully" {
    spec = FunctionSpec(
        qualified_key="test.fn",
        name="fn",
        semstr=None,
        params=[],
        return_type_str="str",
        return_type_detail=None
    );

    with unittest.mock.patch(
        "byllm.test_gen.code_generator.generate_test_block",
        side_effect=Exception("Connection refused")
    ) {
        result = generate_tests_for_spec(spec, model_name="openai/gpt-4o");
    }

    assert result.test_code is None;
    assert result.error is not None;
    assert "LLM call failed" in result.error;
}

test "code generator: rejects test block containing by llm() calls" {
    spec = FunctionSpec(
        qualified_key="test.fn",
        name="fn",
        semstr=None,
        params=[],
        return_type_str="str",
        return_type_detail=None
    );

    bad_block = JacTestBlock(
        code='test "fn: check" {\n    result = fn();\n    assert (fn() by llm()) == result;\n}'
    );

    with unittest.mock.patch(
        "byllm.test_gen.code_generator.generate_test_block",
        return_value=bad_block
    ) {
        result = generate_tests_for_spec(spec, model_name="openai/gpt-4o");
    }

    assert result.test_code is None;
    assert result.error is not None;
    assert "by llm(" in result.error;
}

test "code generator: error_feedback is forwarded to generate_test_block" {
    spec = FunctionSpec(
        qualified_key="test.fn",
        name="fn",
        semstr=None,
        params=[],
        return_type_str="str",
        return_type_detail=None
    );
    feedback = "NameError: name 're' is not defined";
    fake_block = JacTestBlock(
        code='test "fn: check" {\n    result = fn();\n    assert result;\n}'
    );

    captured_kwargs: list = [];

    def capturing_mock(**kwargs: object) -> JacTestBlock {
        captured_kwargs.append(kwargs);
        return fake_block;
    }

    with unittest.mock.patch(
        "byllm.test_gen.code_generator.generate_test_block",
        side_effect=capturing_mock
    ) {
        generate_tests_for_spec(spec, error_feedback=feedback);
    }

    assert len(captured_kwargs) == 1;
    assert captured_kwargs[0].get("error_feedback") == feedback;
}

# ---------------------------------------------------------------------------
# Output Writer Tests
# ---------------------------------------------------------------------------

test "output writer: generated file contains header, import re, and spec hash" {
    spec = FunctionSpec(
        qualified_key="llm_semstrings.generate_password",
        name="generate_password",
        semstr="Generates a password.",
        params=[],
        return_type_str="str",
        return_type_detail=None
    );
    test_code = 'test "generate_password: length" {\n    result = generate_password();\n    assert len(result) >= 8;\n}';
    results = [TestGenResult(spec=spec, test_code=test_code, error=None)];

    with tempfile.NamedTemporaryFile(suffix=".jac", delete=False, mode="w") as f {
        output_path = f.name;
    }
    try {
        write_test_file(results, "/fake/path/llm_semstrings.jac", output_path);
        content = Path(output_path).read_text();

        assert "AUTO-GENERATED" in content, "header comment missing";
        assert "llm_semstrings.jac" in content, "source filename missing";
        assert "spec_hash:generate_password:" in content, "spec hash comment missing";
        assert "import re;" in content, "import re; should be in generated header";
        assert 'test "generate_password: length"' in content, "test block missing";
    } finally {
        os.unlink(output_path);
    }
}

test "output writer: read_existing_hashes parses spec hash comments correctly" {
    spec = FunctionSpec(
        qualified_key="mod.myfunc",
        name="myfunc",
        semstr="Does something.",
        params=[],
        return_type_str="str",
        return_type_detail=None
    );
    expected_hash = spec.spec_hash();
    test_code = 'test "myfunc: basic" {\n    result = myfunc();\n    assert result;\n}';
    results = [TestGenResult(spec=spec, test_code=test_code, error=None)];

    with tempfile.NamedTemporaryFile(suffix=".jac", delete=False, mode="w") as f {
        output_path = f.name;
    }
    try {
        write_test_file(results, "/fake/path/mod.jac", output_path);
        hashes = read_existing_hashes(output_path);

        assert "myfunc" in hashes, f"expected 'myfunc' key in {hashes}";
        assert hashes["myfunc"] == expected_hash, (
            f"hash mismatch: expected {expected_hash}, got {hashes.get('myfunc')}"
        );
    } finally {
        os.unlink(output_path);
    }
}

test "output writer: failed results noted in header, not as test blocks" {
    spec_ok = FunctionSpec(
        qualified_key="mod.ok_fn",
        name="ok_fn",
        semstr=None,
        params=[],
        return_type_str="str",
        return_type_detail=None
    );
    spec_fail = FunctionSpec(
        qualified_key="mod.fail_fn",
        name="fail_fn",
        semstr=None,
        params=[],
        return_type_str="str",
        return_type_detail=None
    );
    results = [
        TestGenResult(spec=spec_ok, test_code='test "ok_fn" { result = ok_fn(); assert result; }', error=None),
        TestGenResult(spec=spec_fail, test_code=None, error="LLM call failed: timeout"),
    ];

    with tempfile.NamedTemporaryFile(suffix=".jac", delete=False, mode="w") as f {
        output_path = f.name;
    }
    try {
        write_test_file(results, "/fake/path/mod.jac", output_path);
        content = Path(output_path).read_text();

        assert "fail_fn" in content, "failed function should appear in header note";
        assert "LLM call failed: timeout" in content, "error message should appear in header";
        assert 'test "ok_fn"' in content, "successful test block should be present";
        assert 'test "fail_fn"' not in content, "failed function must not appear as test block";
    } finally {
        os.unlink(output_path);
    }
}

test "output writer: read_existing_hashes returns empty dict for missing file" {
    hashes = read_existing_hashes("/nonexistent/path/that/does/not/exist.jac");
    assert hashes == {}, f"expected empty dict, got {hashes}";
}
