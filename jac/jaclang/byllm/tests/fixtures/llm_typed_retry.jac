"""Fixture: typed-output retry exercised through real `by llm()` calls.

MockRawResponse routes text through parse_response (so malformed JSON raises
OutputConversionError and drives the retry like a real model); MockError raises a
non-conversion error; each MockLLM records the prompt it saw per attempt in
seen_prompts. Functions are not called here; tests drive them and inspect each
llm to assert attempt counts and the corrective feedback.
"""

import from jaclang.byllm.lib { MockLLM, MockRawResponse, MockError }

obj Person {
    has name: str,
        age: int;
}

# Malformed JSON first (triggers a retry); valid JSON second.
glob recover_llm = MockLLM(
    model_name="mockllm",
    config={"outputs": [
        MockRawResponse(content="{\"name\": \"Ada\", \"age\":"),
        MockRawResponse(content="{\"name\": \"Ada\", \"age\": 36}")
    ]}
);
def get_person_recovering -> Person by recover_llm();

# Every response malformed; default 3 retries = 4 attempts, all fail -> raises.
glob exhaust_llm = MockLLM(
    model_name="mockllm",
    config={"outputs": [
        MockRawResponse(content="nope-1"),
        MockRawResponse(content="nope-2"),
        MockRawResponse(content="nope-3"),
        MockRawResponse(content="nope-4")
    ]}
);
def get_person_failing -> Person by exhaust_llm();

# Retry cap of 1 (passed as a call param on the by-expression) -> 2 attempts,
# both malformed -> raises. `by llm(...)` kwargs become the model's call_params.
glob limited_llm = MockLLM(
    model_name="mockllm",
    config={"outputs": [
        MockRawResponse(content="bad-1"),
        MockRawResponse(content="bad-2"),
        MockRawResponse(content="bad-3")
    ]}
);
def get_person_limited -> Person by limited_llm(max_output_retries=1);

# A non-conversion error must propagate without any retry.
glob error_llm = MockLLM(
    model_name="mockllm",
    config={"outputs": [
        MockError(error=ValueError("boom")),
        MockRawResponse(content="{\"name\": \"Late\", \"age\": 9}")
    ]}
);
def get_person_erroring -> Person by error_llm();

# A non-empty string for a structured type (MockLLM passthrough) is accepted.
glob passthrough_llm = MockLLM(
    model_name="mockllm",
    config={"outputs": ["Average: 86.75"]}
);
def get_person_passthrough -> Person by passthrough_llm();

# A str return type passes an empty response through without retrying.
glob str_llm = MockLLM(model_name="mockllm", config={"outputs": [""]});
def get_text -> str by str_llm();

# Async structured call: malformed then valid, the async path must also retry.
glob arecover_llm = MockLLM(
    model_name="mockllm",
    config={"outputs": [
        MockRawResponse(content="{\"name\": \"Zoe\", \"age\":"),
        MockRawResponse(content="{\"name\": \"Zoe\", \"age\": 27}")
    ]}
);
async def aget_person_recovering -> Person by arecover_llm();
