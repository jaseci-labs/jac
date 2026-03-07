"""Tests for the jac test-gen infrastructure.

Tests cover:
  - Spec extraction from a compiled MTIR map
  - Prompt building from a FunctionSpec
  - Test block parsing/validation in code_generator
  - Output file rendering and hash comments
  - Incremental (hash-based) skipping via read_existing_hashes

Note: Code generator LLM calls are tested by monkeypatching litellm.completion.
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
import from byllm.test_gen.prompt_builder { build_test_gen_prompt }
import from byllm.test_gen.code_generator { generate_tests_for_spec, TestGenResult }
import from byllm.test_gen.output_writer { write_test_file, read_existing_hashes }

import byllm.test_gen.code_generator as _cg_mod;

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

test "spec extraction: structured return type yields ClassSpec or EnumSpec detail" {
    prog = JacProgram();
    prog.compile(fixture_path("with_llm_type.jac"));
    specs = extract_specs(JacRuntime.program.mtir_map);

    assert len(specs) > 0, "expected at least one spec from with_llm_type.jac";
    has_complex = any(s.return_type_detail is not None for s in specs);
    assert has_complex, "expected at least one spec with a structured return type detail (ClassSpec/EnumSpec)";
}

# ---------------------------------------------------------------------------
# Prompt Builder Tests
# ---------------------------------------------------------------------------

test "prompt builder: system prompt contains key rules" {
    spec = FunctionSpec(
        qualified_key="test.generate_password",
        name="generate_password",
        semstr="Generates a password with at least 8 characters.",
        params=[],
        return_type_str="str",
        return_type_detail=None
    );
    (system_prompt, user_prompt) = build_test_gen_prompt(spec);

    assert "DETERMINISTIC" in system_prompt, "system prompt must mention DETERMINISTIC";
    assert "assert" in system_prompt.lower(), "system prompt must mention assertions";
    assert "test" in system_prompt.lower(), "system prompt must mention test block syntax";
}

test "prompt builder: user prompt contains function name, semstr, and return type" {
    spec = FunctionSpec(
        qualified_key="test.generate_password",
        name="generate_password",
        semstr="Generates a password with at least 8 characters.",
        params=[],
        return_type_str="str",
        return_type_detail=None
    );
    (system_prompt, user_prompt) = build_test_gen_prompt(spec);

    assert "generate_password" in user_prompt;
    assert "at least 8 characters" in user_prompt;
    assert "str" in user_prompt;
    assert "Parameters: (none)" in user_prompt;
}

test "prompt builder: user prompt lists parameters with semstrs" {
    spec = FunctionSpec(
        qualified_key="test.translate",
        name="translate",
        semstr="Translate text to a target language.",
        params=[
            ParamSpec(name="text", type_str="str", semstr="The text to translate.", nested=None),
            ParamSpec(name="language", type_str="str", semstr="Target language name.", nested=None),
        ],
        return_type_str="str",
        return_type_detail=None
    );
    (_, user_prompt) = build_test_gen_prompt(spec);

    assert "text" in user_prompt;
    assert "The text to translate." in user_prompt;
    assert "language" in user_prompt;
    assert "Target language name." in user_prompt;
}

test "prompt builder: enum return type lists valid members in prompt" {
    spec = FunctionSpec(
        qualified_key="test.get_personality",
        name="get_personality",
        semstr="Detect personality type from a name.",
        params=[ParamSpec(name="name", type_str="str", semstr=None, nested=None)],
        return_type_str="Personality",
        return_type_detail=EnumSpec(
            name="Personality",
            semstr="Personality classification",
            members=[("INTROVERT", None), ("EXTROVERT", None), ("AMBIVERT", None)]
        )
    );
    (_, user_prompt) = build_test_gen_prompt(spec);

    assert "Personality" in user_prompt;
    assert "INTROVERT" in user_prompt;
    assert "EXTROVERT" in user_prompt;
    assert "AMBIVERT" in user_prompt;
}

# ---------------------------------------------------------------------------
# Code Generator Tests (monkeypatched litellm)
# ---------------------------------------------------------------------------

test "code generator: extracts test block from valid LLM response" {
    spec = FunctionSpec(
        qualified_key="test.generate_password",
        name="generate_password",
        semstr="Generates a password with at least 8 characters.",
        params=[],
        return_type_str="str",
        return_type_detail=None
    );

    fake_response_text = 'test "generate_password: length check" {\n    result = generate_password();\n    assert isinstance(result, str);\n    assert len(result) >= 8;\n}';

    fake_choice = unittest.mock.MagicMock();
    fake_choice.message.content = fake_response_text;
    fake_response = unittest.mock.MagicMock();
    fake_response.choices = [fake_choice];

    with unittest.mock.patch.object(_cg_mod.litellm, "completion", return_value=fake_response) {
        result = generate_tests_for_spec(spec, model_name="openai/gpt-4o", temperature=0.2);
    }

    assert result.error is None, f"unexpected error: {result.error}";
    assert result.test_code is not None;
    assert 'test "generate_password: length check"' in result.test_code;
    assert "assert len(result) >= 8" in result.test_code;
}

test "code generator: returns error when no test block found in response" {
    spec = FunctionSpec(
        qualified_key="test.fn",
        name="fn",
        semstr=None,
        params=[],
        return_type_str="str",
        return_type_detail=None
    );

    fake_choice = unittest.mock.MagicMock();
    fake_choice.message.content = "Here is my analysis... unfortunately I cannot generate a test.";
    fake_response = unittest.mock.MagicMock();
    fake_response.choices = [fake_choice];

    with unittest.mock.patch.object(_cg_mod.litellm, "completion", return_value=fake_response) {
        result = generate_tests_for_spec(spec, model_name="openai/gpt-4o");
    }

    assert result.test_code is None;
    assert result.error is not None;
    assert "Could not extract" in result.error;
}

test "code generator: rejects test block containing import statements" {
    spec = FunctionSpec(
        qualified_key="test.fn",
        name="fn",
        semstr=None,
        params=[],
        return_type_str="str",
        return_type_detail=None
    );

    fake_response_text = 'test "fn: check" {\n    import os;\n    result = fn();\n    assert isinstance(result, str);\n}';

    fake_choice = unittest.mock.MagicMock();
    fake_choice.message.content = fake_response_text;
    fake_response = unittest.mock.MagicMock();
    fake_response.choices = [fake_choice];

    with unittest.mock.patch.object(_cg_mod.litellm, "completion", return_value=fake_response) {
        result = generate_tests_for_spec(spec, model_name="openai/gpt-4o");
    }

    assert result.test_code is None;
    assert result.error is not None;
    assert "import" in result.error.lower();
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

    with unittest.mock.patch.object(
        _cg_mod.litellm, "completion", side_effect=Exception("Connection refused")
    ) {
        result = generate_tests_for_spec(spec, model_name="openai/gpt-4o");
    }

    assert result.test_code is None;
    assert result.error is not None;
    assert "LLM call failed" in result.error;
}

# ---------------------------------------------------------------------------
# Output Writer Tests
# ---------------------------------------------------------------------------

test "output writer: generated file contains header, import line, and spec hash" {
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
        assert "import from llm_semstrings { generate_password }" in content, "import line missing";
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
    test_code = 'test "myfunc: basic" {\n    result = myfunc();\n    assert isinstance(result, str);\n}';
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
