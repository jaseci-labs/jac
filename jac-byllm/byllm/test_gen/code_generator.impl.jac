"""Implementation of the byLLM-based test block generator.

validate_jac and check_syntax are thin wrappers over jac-mcp's CompilerBridge.
generate_tests_for_spec converts a FunctionSpec into the string parameters that
generate_test_block() (a by llm() function) consumes.
"""

import re;
import json;
import from loguru { logger }
import from byllm.test_gen.spec_extractor {
    FunctionSpec, ClassSpec, EnumSpec, FieldSpec, ParamSpec
}

"""Check for known Jac anti-patterns that validate_jac may not catch in snippets.

Returns a human-readable error string if any issue is found, else None.
"""
def _check_jac_syntax(code: str) -> str | None {
    errors: list[str] = [];
    # // is not a comment in Jac (it's floor-division); catches JS-style comments
    if re.search(r"//", code) {
        errors.append("Contains `//` — NOT a Jac comment. Use `#` for comments.");
    }
    # `let` is not a keyword in Jac
    if re.search(r"\blet\b", code) {
        errors.append("Contains `let` — NOT valid Jac. Write `name = value;` without `let`.");
    }
    # `var` is not a keyword in Jac
    if re.search(r"\bvar\b", code) {
        errors.append("Contains `var` — NOT valid Jac. Write `name = value;` without `var`.");
    }
    # `null` is not valid Jac — use `None`
    if re.search(r"\bnull\b", code) {
        errors.append("Contains `null` — NOT valid Jac. Use `None` instead.");
    }
    # Test name must be a quoted string literal
    if re.search(r'\btest\s+[^"\'{]', code) {
        errors.append("Test name must be a quoted string: `test \"name\" {` not `test name {`.");
    }
    if errors {
        return "\n".join(errors);
    }
    return None;
}

"""Validate Jac code via jac-mcp CompilerBridge (full type check)."""
impl validate_jac(code: str) -> str {
    import from jac_mcp.tools { ToolProvider }
    result = ToolProvider().call_tool("validate_jac", {"code": code});
    return json.dumps(result);
}

"""Quick parse-only syntax check via jac-mcp CompilerBridge."""
impl check_syntax(code: str) -> str {
    import from jac_mcp.tools { ToolProvider }
    result = ToolProvider().call_tool("check_syntax", {"code": code});
    return json.dumps(result);
}

"""Format a single field as a line for fields_spec, tagging semstrs as assertion targets."""
def _field_line(f: FieldSpec) -> str {
    if f.semstr {
        return f"  {f.name}: {f.type_str}\n    [ASSERT THIS] {f.semstr}";
    }
    return f"  {f.name}: {f.type_str}";
}

"""Format parameters into a human-readable string for the parameters argument."""
def _fmt_params(params: list[ParamSpec]) -> str {
    if not params {
        return "(none)";
    }
    lines: list[str] = [];
    for p in params {
        sem = f" — {p.semstr}" if p.semstr else "";
        lines.append(f"  {p.name}: {p.type_str}{sem}");
        if isinstance(p.nested, ClassSpec) {
            ctor_args = ", ".join(f"{f.name}=..." for f in p.nested.fields);
            lines.append(f"    (construct as: {p.nested.name}({ctor_args}))");
            for f in p.nested.fields {
                lines.append("  " + _field_line(f));
            }
        } elif isinstance(p.nested, EnumSpec) {
            members = ", ".join(m[0] for m in p.nested.members);
            lines.append(f"    (enum values: {members})");
        }
    }
    return "\n".join(lines);
}

"""Format return type detail into the fields_spec string."""
def _fmt_fields(spec: FunctionSpec) -> str {
    detail = spec.return_type_detail;
    if isinstance(detail, ClassSpec) {
        lines: list[str] = [f"Object type: {detail.name}"];
        if detail.semstr {
            lines.append(f"  Class description: {detail.semstr}");
        }
        for f in detail.fields {
            lines.append(_field_line(f));
        }
        return "\n".join(lines);
    }
    if isinstance(detail, EnumSpec) {
        lines: list[str] = [f"Enum type: {detail.name}"];
        if detail.semstr {
            lines.append(f"  {detail.semstr}");
        }
        for (mname, msem) in detail.members {
            msem_str = f" — {msem}" if msem else "";
            lines.append(f"  {mname}{msem_str}");
        }
        return "\n".join(lines);
    }
    return "(primitive — assert the value directly from the semantic description)";
}

"""Write code to a temp .jac file and run `jac check --parse-only`.

Returns compiler error text on failure, or None if the code is syntactically valid.
Parse-only mode catches all syntax errors (missing semicolons, wrong assignment
syntax, bad object literals, etc.) without requiring type context.
"""
def _jac_check_snippet(code: str, source_dir: str = "") -> str | None {
    import os;
    import tempfile;
    import subprocess;
    content = f"import re;\n\n{code}\n";
    fd = None;
    tmp_path = None;
    try {
        (fd, tmp_path) = tempfile.mkstemp(suffix=".jac", dir=source_dir or None);
        os.write(fd, content.encode());
        os.close(fd);
        fd = None;
        proc = subprocess.run(
            ["jac", "check", "-p", tmp_path],
            capture_output=True,
            text=True
        );
        if proc.returncode == 0 {
            return None;
        }
        return (proc.stdout + "\n" + proc.stderr).strip() or "jac check --parse-only failed";
    } finally {
        if fd is not None {
            os.close(fd);
        }
        if tmp_path is not None and os.path.exists(tmp_path) {
            os.unlink(tmp_path);
        }
    }
}

impl generate_tests_for_spec(
    spec: FunctionSpec,
    model_name: str = "openai/gpt-4o",
    temperature: float = 0.2,
    error_feedback: str | None = None,
    source_dir: str = "",
    max_retries: int = 3
) -> TestGenResult {
    import from byllm.llm { Model }
    import from byllm.plugin { JacRuntime }

    logger.debug(f"[test-gen] Generating test for: {spec.qualified_key} using {model_name}");

    # Temporarily patch the global LLM to use the requested model + temperature.
    orig_model = getattr(JacRuntime, "_cached_default_llm", None);
    JacRuntime._cached_default_llm = Model(model_name=model_name)(temperature=temperature);

    try {
        feedback: str | None = error_feedback;

        for attempt in range(max_retries) {
            # --- Generate ---
            try {
                param_sig = ", ".join(p.name for p in spec.params);
                if spec.parent_class {
                    fn_name_hint = (
                        f"{spec.name} (method on {spec.parent_class} — "
                        f"first write `receiver = {spec.parent_class}();` then call EXACTLY: "
                        f"receiver.{spec.name}({param_sig}) "
                        f"with ONLY these {len(spec.params)} argument(s) — no extras)"
                    );
                } else {
                    fn_name_hint = (
                        f"{spec.name} (call EXACTLY as: {spec.name}({param_sig}) "
                        f"with ONLY these {len(spec.params)} argument(s) — no extras)"
                    );
                }
                result: JacTestBlock = generate_test_block(
                    function_name=fn_name_hint,
                    semantic_description=spec.semstr,
                    parameters=_fmt_params(spec.params),
                    return_type=spec.return_type_str,
                    fields_spec=_fmt_fields(spec),
                    error_feedback=feedback
                );
            } except Exception as e {
                return TestGenResult(spec=spec, test_code=None, error=f"LLM call failed: {e}");
            }

            code = result.code if result else None;
            if not code {
                feedback = "Returned an empty test block. Write a non-empty test block.";
                continue;
            }

            if "by llm(" in code {
                feedback = "The test block must not contain `by llm()` calls. Remove them and rewrite.";
                continue;
            }

            # --- Step 1: deterministic anti-pattern check ---
            # Catches JS/TS patterns (// comments, let, var, unquoted test name) that
            # validate_jac may silently accept when validating a snippet in isolation.
            syntax_err = _check_jac_syntax(code);
            if syntax_err {
                logger.warning(
                    f"[test-gen] {spec.name}: anti-pattern check failed (attempt {attempt + 1}/"
                    f"{max_retries}): {syntax_err}"
                );
                feedback = (
                    f"The code violates Jac syntax rules:\n{syntax_err}\n\n"
                    "Fix ALL issues before returning. See the syntax rules in the code field description."
                );
                continue;
            }

            # --- Step 2: parse-only jac check on a temp file ---
            # Catches syntax errors (missing semicolons, wrong assignment syntax, bad object
            # literals, etc.) that validate_jac misses when validating a standalone snippet.
            parse_err = _jac_check_snippet(code, source_dir=source_dir);
            if parse_err {
                logger.warning(
                    f"[test-gen] {spec.name}: jac check -p failed (attempt {attempt + 1}/"
                    f"{max_retries}):\n{parse_err}"
                );
                feedback = (
                    f"jac check (parse-only) rejected the code with syntax errors:\n{parse_err}\n\n"
                    "Fix ALL syntax errors. Remember:\n"
                    "- Assign with `=`: write `name = \"Albert Einstein\";` not `name: \"Albert Einstein\"`\n"
                    "- Every statement ends with `;`\n"
                    "- Object instantiation is `Person(full_name=..., dod=...)` not `Person { ... }`\n"
                    "- Use `re.match(r\"\\d{2}/\\d{2}/\\d{4}\", result.field)` not `regex_match(...)`"
                );
                continue;
            }

            # Check format-constrained fields are asserted with re.match, not ==
            if isinstance(spec.return_type_detail, ClassSpec) and re.search(r"==\s*['\"][\d/\-:T]+['\"]", code) {
                format_fields = [
                    f.name for f in spec.return_type_detail.fields
                    if f.semstr and ("format" in f.semstr.lower() or "/" in f.semstr or "-" in f.semstr)
                ];
                if format_fields {
                    feedback = (
                        f"You used `==` to assert an exact date/format value for field(s): {format_fields}. "
                        "For [ASSERT THIS] fields with a format constraint (e.g. MM/DD/YYYY), "
                        "ALWAYS use re.match() to check the structure — never assert an exact value. "
                        "Also use a real famous person (e.g. 'Albert Einstein') so the LLM returns known biographical data."
                    );
                    continue;
                }
            }

            # --- Step 3: full compiler validation ---
            # Call validate_jac directly — do not rely on the model having used it voluntarily.
            val_result = json.loads(validate_jac(code));
            if not val_result.get("valid", False) {
                errors = val_result.get("errors", []);
                error_text = "\n".join(str(e) for e in errors);
                logger.warning(
                    f"[test-gen] {spec.name}: validate_jac failed (attempt {attempt + 1}/"
                    f"{max_retries}):\n{error_text}"
                );
                feedback = f"validate_jac rejected the code:\n{error_text}";
                continue;
            }

            # Validation passed
            if "assert " not in code {
                logger.warning(f"[test-gen] {spec.name}: generated test has no assert statements");
            }
            logger.debug(f"[test-gen] Successfully generated test for: {spec.qualified_key}");
            return TestGenResult(spec=spec, test_code=code, error=None);
        }

        return TestGenResult(
            spec=spec,
            test_code=None,
            error=f"Failed to produce a valid test after {max_retries} attempts. "
                  f"Last feedback: {feedback}"
        );
    } finally {
        JacRuntime._cached_default_llm = orig_model;
    }
}
