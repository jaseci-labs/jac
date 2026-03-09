"""Code generator for test generation using byLLM.

generate_test_block() is a by llm() function. Jac syntax rules are passed as
structured context via incl_info so sems stay minimal semantic descriptions.
Tool validation (validate_jac, check_syntax) via jac-mcp is handled by
byLLM's built-in ReAct loop.
"""
import from byllm.test_gen.spec_extractor { FunctionSpec }

"""Result of generating a test block for one function."""
obj TestGenResult {
    has spec: FunctionSpec,
        test_code: str | None,
        error: str | None = None;
}

"""The generated Jac test block."""
obj JacTestBlock {
    has code: str;
}

sem JacTestBlock.code = "The complete Jac test block code string.";

"""Mandatory Jac syntax rules the LLM must follow when writing test blocks."""
obj JacSyntaxRules {
    has comments: str = "Use `#` for comments — `//` is floor-division in Jac, not a comment",
        variables: str = "Assign with `=`: write `name = value;` — `let` and `var` do not exist in Jac",
        test_names: str = "Test name must be a double-quoted string: test \"name\" { ... } — unquoted names are invalid",
        semicolons: str = "Every statement must end with `;`",
        assertions: str = "For format/date fields use re.match() — never assert an exact value with `==`",
        test_data: str = "Use real famous historical figures (e.g. Albert Einstein, Marie Curie) — never 'John Doe'",
        null_keyword: str = "Use `None` for null values — `null` does not exist in Jac",
        scope: str = "The function under test and all its types are already in scope; `re` is pre-imported",
        workflow: str = "Draft → call check_syntax → fix → call validate_jac → fix → return via finish_tool";
}

glob JAC_RULES: JacSyntaxRules = JacSyntaxRules();

"""Validate Jac code with full type checking via jac-mcp.

Returns JSON: {valid: bool, errors: [...], warnings: [...]}.
Call this after drafting the test block to confirm it compiles. If errors
are returned, fix the code and call again before finalising.
"""
def validate_jac(code: str) -> str;
sem validate_jac = "Validate Jac test code with full type checking. MUST be called after drafting to confirm it compiles. If errors are present, fix and re-call.";
sem validate_jac.code = "The Jac test block code to validate";

"""Quick parse-only syntax check (no type checking) via jac-mcp.

Faster than validate_jac. Use as a first pass when iterating on syntax,
then follow up with validate_jac for full type checking.
"""
def check_syntax(code: str) -> str;
sem check_syntax = "Quick parse-only syntax check. Use as fast first pass before validate_jac.";
sem check_syntax.code = "The Jac source code to check for syntax errors";

"""Generate a Jac test block for a single by llm() function."""
def generate_test_block(
    function_name: str,
    semantic_description: str | None,
    parameters: str,
    return_type: str,
    fields_spec: str,
    error_feedback: str | None = None
) -> JacTestBlock by llm(
    tools=[validate_jac, check_syntax],
    incl_info={"jac_syntax_rules": JAC_RULES},
    reason=True,
    temperature=0.2,
    max_react_iterations=8
);

sem generate_test_block = "Generate a syntactically valid Jac test block that verifies a by llm() function. Follow all rules in jac_syntax_rules exactly.";
sem generate_test_block.function_name = "Name of the Jac function to test — call it inside the test block";
sem generate_test_block.semantic_description = "What the function does, from its semstr — use this to understand what to assert";
sem generate_test_block.parameters = "The function's parameters with types and semantics — use real famous historical figures for name/person fields";
sem generate_test_block.return_type = "Return type of the function (e.g. str, Person, list[Task])";
sem generate_test_block.fields_spec = "Fields with types and semantic constraints — lines tagged [ASSERT THIS] must each become an assertion";
sem generate_test_block.error_feedback = "A previous run failed with this error — fix it before returning";

"""Generate a Jac test block for a single FunctionSpec.

Converts the FunctionSpec into semantic string inputs for generate_test_block()
and calls it via the byLLM ReAct loop. Temporarily patches the global LLM model
to honour the model_name parameter.

Returns TestGenResult with test_code=None and error set if generation fails.
"""
def generate_tests_for_spec(
    spec: FunctionSpec,
    model_name: str = "openai/gpt-4o",
    temperature: float = 0.2,
    error_feedback: str | None = None,
    source_dir: str = "",
    max_retries: int = 3
) -> TestGenResult;
