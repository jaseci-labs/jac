"""Prompt builder for test generation.

Converts a FunctionSpec into a structured prompt pair (system, user)
for use with a code-generation LLM.
"""
import from byllm.test_gen.spec_extractor { FunctionSpec }

"""Build a (system_prompt, user_prompt) pair for test generation.

The system prompt is a constant instruction set.
The user prompt is derived from the FunctionSpec.
"""
def build_test_gen_prompt(spec: FunctionSpec) -> tuple[str, str];
