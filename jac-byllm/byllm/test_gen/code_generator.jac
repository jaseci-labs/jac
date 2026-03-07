"""Code generator for test generation.

Calls a configurable LLM (via litellm directly) to generate Jac test blocks
from a FunctionSpec. Uses litellm.completion() rather than by llm() to avoid
circular bootstrapping — test generation is a meta-operation.
"""
import from byllm.test_gen.spec_extractor { FunctionSpec }

"""Result of generating a test block for one function."""
obj TestGenResult {
    has spec: FunctionSpec,
        test_code: str | None,
        error: str | None = None;
}

"""Generate a Jac test block for a single FunctionSpec.

Calls the specified LLM model with the spec prompt and parses the response
to extract a valid test block. Returns TestGenResult with test_code=None
and error set if generation or parsing fails.

Args:
    spec: The function specification to generate tests for.
    model_name: LiteLLM model identifier (e.g. "openai/gpt-4o").
    temperature: Sampling temperature (lower = more deterministic code output).
    error_feedback: Runtime error from a previous test run; triggers a fix iteration.
"""
def generate_tests_for_spec(
    spec: FunctionSpec,
    model_name: str = "openai/gpt-4o",
    temperature: float = 0.2,
    error_feedback: str | None = None
) -> TestGenResult;
