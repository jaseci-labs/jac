"""Implementation of the prompt builder for test generation."""

import from byllm.test_gen.spec_extractor {
    FunctionSpec, ParamSpec, ClassSpec, EnumSpec, FieldSpec
}

glob _SYSTEM_PROMPT = """\
You are a test engineer writing Jac test blocks. Jac is a language that looks like Python \
but requires semicolons at the end of statements and uses braces for blocks.

You have access to two tools:
- validate_jac(code): full type-check — call this after drafting your test block to confirm it compiles
- check_syntax(code): quick parse-only check — use as a fast first pass

WORKFLOW:
1. Draft the test block.
2. Call check_syntax to catch any obvious syntax mistakes.
3. Fix errors, then call validate_jac for full type checking.
4. Fix any remaining errors.
5. Output ONLY the final test block (no explanation).

JAC SYNTAX RULES:
- Statements end with semicolons: `result = fn();`
- Blocks use braces: `test "name" { ... }`
- The function under test and all its types ARE ALREADY IN SCOPE — do NOT import them
- `re` is pre-imported in the test file; use it freely
- For other stdlib modules (math, datetime, etc.) add `import math;` INSIDE the test block body
- Variables are assigned without type annotation: `x = foo();`
- Assertions: `assert condition, "message";`
- Built-ins available: isinstance(), len(), any(), all(), hasattr(), type()
- Construct types with keyword args: `obj = TypeName(field=value);`

CRITICAL — WHAT TO TEST:
Do NOT write trivial assertions that test nothing meaningful:
  ✗  assert hasattr(result, "name")        # useless — fields always exist on returned objects

INSTEAD, assert the SEMANTIC constraints stated in the field's semantic description (semstr):
  ✓  semstr "Year of Death ... YYYY" → assert 1000 < result.yod < 2100;
  ✓  semstr "at least 8 characters" → assert len(result) >= 8;
  ✓  semstr "returns exactly 120597" → assert result == 120597;
  ✓  semstr "format MM/DD/YYYY" → assert re.match(r"\\d{2}/\\d{2}/\\d{4}", result.field);
  ✓  semstr "one of INTROVERT, EXTROVERT, AMBIVERT" → assert result.personality in [...];
  ✓  semstr "non-empty name" → assert len(result.full_name) > 0;
  ✓  semstr "positive integer" → assert result.count > 0;

RULES:
1. Read EVERY field's semantic description and derive a real constraint assertion from it.
2. For enum fields: assert value in [EnumName.MEMBER, ...] using the listed valid members.
3. For string fields with a described format: use re.match() or re.fullmatch().
4. For numeric fields with a described meaning (year, age, count): assert a plausible range.
5. For string fields with length constraints: assert len(field) operator value.
6. Call the function with concrete representative arguments — choose values likely to trigger \
   the described behavior (e.g., a real famous person's name for a "person info" function).
7. Every assertion MUST be DETERMINISTIC code — no LLM calls inside the test.
8. If a semstr has no clear constraint, assert the field is non-None/non-empty as a minimum.
""";

"""Format a single field line for the prompt, emphasising the semstr as the test target."""
def _field_line(f: FieldSpec) -> str {
    if f.semstr {
        # Put the semantic description on its own line so the model treats it as a test spec
        return f"    {f.name}: {f.type_str}\n      [ASSERT THIS] semantic spec: \"{f.semstr}\"";
    }
    return f"    {f.name}: {f.type_str}";
}

"""Format the return type section of the user prompt."""
def _format_return_type(spec: FunctionSpec) -> str {
    lines: list[str] = [f"Return type: {spec.return_type_str}"];
    detail = spec.return_type_detail;
    if isinstance(detail, ClassSpec) {
        lines.append(f"  (object — {detail.name})");
        if detail.semstr {
            lines.append(f"  Class description: {detail.semstr}");
        }
        if detail.fields {
            lines.append("  Fields:");
            for f in detail.fields {
                lines.append(_field_line(f));
            }
        }
    } elif isinstance(detail, EnumSpec) {
        lines.append(f"  (enum — {detail.name})");
        if detail.semstr {
            lines.append(f"  Enum description: {detail.semstr}");
        }
        if detail.members {
            lines.append("  Valid members:");
            for (mname, msem) in detail.members {
                msem_str = f" — {msem}" if msem else "";
                lines.append(f"    {mname}{msem_str}");
            }
        }
    }
    return "\n".join(lines);
}

"""Format the parameters section of the user prompt."""
def _format_params(params: list[ParamSpec]) -> str {
    if not params {
        return "Parameters: (none)";
    }
    lines: list[str] = ["Parameters:"];
    for p in params {
        sem = f" — {p.semstr}" if p.semstr else "";
        lines.append(f"  {p.name}: {p.type_str}{sem}");
        if isinstance(p.nested, ClassSpec) {
            lines.append(f"    (object — {p.nested.name})");
            for f in p.nested.fields {
                lines.append("  " + _field_line(f));
            }
        } elif isinstance(p.nested, EnumSpec) {
            lines.append(f"    (enum — valid values: {', '.join(m[0] for m in p.nested.members)})");
        }
    }
    return "\n".join(lines);
}

impl build_test_gen_prompt(spec: FunctionSpec) -> tuple[str, str] {
    semstr_section = spec.semstr if spec.semstr else "(no semantic description provided)";
    user_prompt = "\n".join([
        f"Function: {spec.name}",
        "",
        "Semantic description:",
        *[f"  {line}" for line in semstr_section.splitlines()],
        "",
        _format_params(spec.params),
        "",
        _format_return_type(spec),
        "",
        "Write the Jac test block now:",
    ]);
    return (_SYSTEM_PROMPT, user_prompt);
}
