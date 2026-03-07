"""Implementation of the LLM-based test block generator with jac-mcp tool integration.

The generator runs an agentic loop:
  1. Send spec prompt + jac-mcp tool definitions to the LLM
  2. If the model calls validate_jac or check_syntax, execute via CompilerBridge
  3. Repeat until the model produces a final test block (no tool calls)
  4. Apply local validation (no imports, no by llm())
  5. Return TestGenResult

Tools are backed by jac-mcp's ToolProvider which calls CompilerBridge directly
(no MCP server process needed).
"""

import re;
import json;
import litellm;
import from loguru { logger }
import from byllm.test_gen.spec_extractor { FunctionSpec }
import from byllm.test_gen.prompt_builder { build_test_gen_prompt }

glob _MAX_ITERATIONS: int = 6;

"""Tool schemas passed to the LLM so it can validate the Jac code it writes."""
glob _JAC_TOOLS: list = [
    {
        "type": "function",
        "function": {
            "name": "validate_jac",
            "description": (
                "Validate Jac test code with full type checking. "
                "You MUST call this after drafting a test block to confirm it compiles. "
                "Returns {valid: bool, errors: [...], warnings: [...]}. "
                "If errors are returned, fix the code and call validate_jac again."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "code": {
                        "type": "string",
                        "description": "The Jac test block code to validate"
                    }
                },
                "required": ["code"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "check_syntax",
            "description": "Quick parse-only syntax check (faster, no type checking). Use as a first pass before validate_jac.",
            "parameters": {
                "type": "object",
                "properties": {
                    "code": {
                        "type": "string",
                        "description": "Jac source code to check"
                    }
                },
                "required": ["code"]
            }
        }
    },
];

"""Call a jac-mcp tool by name using ToolProvider (backed by CompilerBridge)."""
def _call_jac_tool(name: str, arguments: dict) -> str {
    import from jac_mcp.tools { ToolProvider }
    result = ToolProvider().call_tool(name, arguments);
    return json.dumps(result, indent=2);
}

"""Build the assistant message dict from a litellm response message."""
def _assistant_message(msg: object) -> dict {
    d: dict = {"role": "assistant"};
    if msg.content {
        d["content"] = msg.content;
    }
    if msg.tool_calls {
        tc_list: list = [];
        for tc in msg.tool_calls {
            tc_list.append({
                "id": tc.id,
                "type": "function",
                "function": {
                    "name": tc.function.name,
                    "arguments": tc.function.arguments
                }
            });
        }
        d["tool_calls"] = tc_list;
    }
    return d;
}

"""Extract the test block (and any leading import lines) from raw LLM output.

Finds the first `test "..." { ... }` block using a balanced-brace scanner so
nested braces inside assertions are handled correctly.  Any `import` statements
on lines immediately before the test keyword (within the same code-fence section)
are prepended so the model can bring in stdlib modules (re, math, etc.).

Returns None if no valid test block is found.
"""
def _extract_test_block(raw: str) -> str | None {
    # Strip markdown code fences if present
    fence_m = re.search(r"```(?:jac)?\n(.*?)```", raw, re.DOTALL);
    body = fence_m.group(1) if fence_m else raw;

    m = re.search(r'test\s+"[^"]*"\s*\{', body);
    if m is None {
        return None;
    }

    # Collect import lines that appear before the test block in the same section
    before = body[:m.start()];
    import_lines: list[str] = [];
    for line in before.splitlines() {
        stripped = line.strip();
        if stripped.startswith("import ") or stripped.startswith("import from ") {
            import_lines.append(stripped);
        }
    }

    brace_start = body.index("{", m.start());
    depth = 0;
    for i in range(brace_start, len(body)) {
        ch = body[i];
        if ch == "{" {
            depth += 1;
        } elif ch == "}" {
            depth -= 1;
            if depth == 0 {
                test_block = body[m.start():i + 1];
                if import_lines {
                    return "\n".join(import_lines) + "\n" + test_block;
                }
                return test_block;
            }
        }
    }
    return None;
}

"""Validate the extracted test block for obvious problems.

Returns (is_valid, warning_message | None).
"""
def _validate_test_block(code: str) -> tuple[bool, str | None] {
    if "by llm(" in code {
        return (False, "Generated test contains by llm() — tests must not call LLMs in assertions");
    }
    if "assert " not in code {
        return (True, "Warning: generated test contains no assert statements");
    }
    return (True, None);
}

impl generate_tests_for_spec(
    spec: FunctionSpec,
    model_name: str = "openai/gpt-4o",
    temperature: float = 0.2,
    error_feedback: str | None = None
) -> TestGenResult {
    (system_prompt, user_prompt) = build_test_gen_prompt(spec);

    logger.debug(f"[test-gen] Generating test for: {spec.qualified_key} using {model_name}");

    messages: list = [
        {"role": "system", "content": system_prompt},
        {"role": "user",   "content": user_prompt},
    ];

    # If we have runtime error feedback from a previous test run, append it so the
    # model knows what to fix before it even starts drafting.
    if error_feedback {
        messages.append({
            "role": "user",
            "content": (
                "A previous version of this test was generated and ran, but FAILED with this error:\n\n"
                f"{error_feedback}\n\n"
                "Fix the test so this error does not occur. "
                "Use check_syntax / validate_jac tools to verify before submitting."
            ),
        });
    }

    for iteration in range(_MAX_ITERATIONS) {
        try {
            response = litellm.completion(
                model=model_name,
                messages=messages,
                temperature=temperature,
                tools=_JAC_TOOLS,
                tool_choice="auto",
            );
        } except Exception as e {
            return TestGenResult(spec=spec, test_code=None, error=f"LLM call failed: {e}");
        }

        choice = response.choices[0];
        msg = choice.message;

        # Append the assistant turn to the conversation
        messages.append(_assistant_message(msg));

        # If the model made tool calls, execute them and continue the loop
        if msg.tool_calls {
            for tc in msg.tool_calls {
                tool_name = tc.function.name;
                try {
                    args = json.loads(tc.function.arguments or "{}");
                } except Exception {
                    args = {};
                }
                logger.debug(f"[test-gen] Tool call: {tool_name}");
                result_str = _call_jac_tool(tool_name, args);
                messages.append({
                    "role": "tool",
                    "tool_call_id": tc.id,
                    "name": tool_name,
                    "content": result_str,
                });
            }
            continue;
        }

        # No tool calls — model has produced its final answer
        raw = msg.content or "";
        test_block = _extract_test_block(raw);
        if test_block is None {
            return TestGenResult(
                spec=spec,
                test_code=None,
                error=f"Could not extract test block from LLM response. Raw output:\n{raw[:500]}"
            );
        }

        (valid, warn_msg) = _validate_test_block(test_block);
        if not valid {
            return TestGenResult(spec=spec, test_code=None, error=warn_msg);
        }
        if warn_msg {
            logger.warning(f"[test-gen] {spec.name}: {warn_msg}");
        }

        logger.debug(f"[test-gen] Successfully generated test for: {spec.qualified_key}");
        return TestGenResult(spec=spec, test_code=test_block, error=None);
    }

    return TestGenResult(
        spec=spec,
        test_code=None,
        error=f"Max iterations ({_MAX_ITERATIONS}) reached without a valid test block"
    );
}
