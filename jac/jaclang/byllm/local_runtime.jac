import json;

glob LOCAL_MODELS: dict[str, dict[str, any]] = {
         "gemma-4-e4b": {
             "repo": "unsloth/gemma-4-E4B-it-GGUF",
             "file": "gemma-4-E4B-it-Q4_K_M.gguf",
             "size_mb": 5000,
             "n_ctx": 8192,
             "description": "Google Gemma 4 E4B (instruction-tuned, Q4_K_M)"
         },
         "gemma-4-e2b": {
             "repo": "unsloth/gemma-4-E2B-it-GGUF",
             "file": "gemma-4-E2B-it-Q4_K_M.gguf",
             "size_mb": 2500,
             "n_ctx": 8192,
             "description": "Google Gemma 4 E2B (smaller, faster)"
         },
         "qwen3.5-4b": {
             "repo": "unsloth/Qwen3.5-4B-GGUF",
             "file": "Qwen3.5-4B-Q4_K_M.gguf",
             "size_mb": 2800,
             "n_ctx": 8192,
             "description": "Alibaba Qwen 3.5 4B (instruction-tuned, Q4_K_M)"
         }
     },
     LOCAL_PREFIX: str = "local:";

def parse_alias(model_name: str) -> str | None;

def list_local_aliases -> list[str];

def wrap_tool_call(tc: dict[str, any]) -> object;

def _flatten_message_content(msg: dict[str, any]) -> dict[str, any];

def _coerce_tool_calls(msg: dict[str, any]) -> dict[str, any];

def normalize_messages(messages: list[dict[str, any]]) -> list[dict[str, any]];

def normalize_response_format(rf: dict[str, any] | None) -> dict[str, any] | None;

def filter_params(params: dict[str, any]) -> dict[str, any];
