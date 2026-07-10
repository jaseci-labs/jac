"""LLM abstraction module.

This module provides a LLM class that abstracts LiteLLM and offers
enhanced functionality and interface for language model operations.
"""
import logging;
import from jaclang.byllm._optdeps.loguru { logger }
import os;
import sys;
import json;
import random;
import time;

import from typing { Callable, Generator }
import from jaclang.byllm.mtir { MTRuntime }
import from jaclang.byllm._optdeps.litellm { litellm, _disable_debugging }
import from jaclang.byllm._optdeps.openai { openai, OpenAI, AsyncOpenAI }
import from jaclang.project.capabilities { require_optional }
import from jaclang.byllm.exceptions {
    AuthenticationError,
    OutputConversionError,
    RateLimitError,
    ModelNotFoundError,
    ConfigurationError,
    CompactionNotEffectiveError
}
import from jaclang.byllm.types {
    CompletionResult,
    LiteLLMMessage,
    MockToolCall,
    MockRawResponse,
    MockError,
    StreamEvent,
    Tool,
    ToolCall,
    Message,
    MessageRole,
    IterationAction,
    IterationContext,
    content_preview,
    reroute_tool_images_to_user_message
}
import from jaclang.byllm.config_loader { get_byllm_config }
import from jaclang.byllm.telemetry { _emit_agent_telemetry, _current_invocation_id }
import from jaclang.byllm.parallel {
    dispatch_batch,
    _index_by_identity,
    _PARALLEL_TOOL_HINT
}
import from jaclang.byllm.schema { inject_schema_hint }
import from jaclang.byllm.tool_protocol { inject_tool_hint, recover_tool_calls }

# Load configuration purely from jac.toml
glob _byllm_config = get_byllm_config(),
     _litellm_config = _byllm_config.get_litellm_config(),
     _model_config = _byllm_config.get_model_config(),
     _call_params_config = _byllm_config.get_call_params_config(),
     _streaming_config = _byllm_config.get_streaming_config(),
     _CACHE_CONTROL_EPHEMERAL: dict = {"type": "ephemeral"};

# Configure LiteLLM based on jac.toml settings
# Note: LiteLLM reads this env var directly, so we set it based on config
with entry {
    if _litellm_config['local_cost_map'] {
        os.environ["LITELLM_LOCAL_MODEL_COST_MAP"] = "True";
    }
}

glob DEFAULT_BASE_URL = "http://localhost:4000",
     MODEL_MOCK = "mockllm";

"""Base class for LLM implementations.

Provides the core interface and shared functionality for all LLM connectors.
Subclasses must implement model_call_no_stream and model_call_with_stream
to define how the actual LLM API is called.
"""
obj BaseLLM {
    has model_name: str,
        config: dict = {},
        api_key: str = "",
        call_params: dict[(str, object)] = {},
        ctx_window: int = 0,
        # False for backends without server-side tool calling (in-process
        # llama.cpp): byllm renders the tool protocol into the prompt and
        # recovers tool calls from the reply itself. See `byllm.tool_protocol`.
        supports_native_tools: bool = True,
        _usage_history: list = [];

    def __call__(**kwargs: object) -> BaseLLM;
    def invoke(mt_run: MTRuntime) -> object;
    async def ainvoke(mt_run: MTRuntime) -> object;
    def _resolve_output_attempts(mt_run: MTRuntime) -> int;
    def _resolve_stream_retries(mt_run: MTRuntime) -> int;
    def _should_retry_stream(
        mt_run: MTRuntime, e: Exception, attempt: int, usage_base: int = -1
    ) -> bool;

    def _invoke_typed_retry(mt_run: MTRuntime) -> object;
    async def _ainvoke_typed_retry(mt_run: MTRuntime) -> object;
    def _typed_retry_reset(
        mt_run: MTRuntime,
        base_msgs: list,
        base_scaffolding: list,
        reason: str,
        output: str
    ) -> None;

    def _parse_failure_feedback(attempt: int, max_attempts: int, err: object) -> tuple;
    def _nonconforming_feedback(
        attempt: int, max_attempts: int, mt_run: MTRuntime, result: object
    ) -> tuple;

    def _typed_retry_exhausted(
        attempts: int, cause: object, raw: str
    ) -> OutputConversionError;

    def _structured_output_ok(mt_run: MTRuntime, value: object) -> bool;
    def _typed_retry_feedback(
        mt_run: MTRuntime, reason: str, prev_output: str
    ) -> Message;

    def _invoke_react_loop(mt_run: MTRuntime) -> object;
    def _invoke_react_loop_streaming(
        mt_run: MTRuntime
    ) -> Generator[object, None, None];

    def make_model_params(mt_run: MTRuntime) -> dict;
    def log_info(message: str) -> None;
    def format_prompt(params: dict) -> str;
    def dispatch_no_streaming(mt_run: MTRuntime) -> CompletionResult;
    def dispatch_streaming(mt_run: MTRuntime) -> Generator[str, None, None];
    def dispatch_streaming_with_tools(
        mt_run: MTRuntime, out: list[CompletionResult]
    ) -> Generator[str, None, None];

    async def adispatch_no_streaming(mt_run: MTRuntime) -> CompletionResult;
    async def adispatch_streaming(mt_run: MTRuntime);
    def model_call_no_stream(params: dict) -> dict;
    def model_call_with_stream(params: dict) -> Generator[str, None, None];
    async def model_call_no_stream_async(params: dict) -> dict;
    async def model_call_with_stream_async(params: dict);
    def _stream_final_answer(mt_run: MTRuntime) -> Generator[str, None, None];
    def _force_final_answer(mt_run: MTRuntime) -> object;
    def _attempt_recovery(mt_run: MTRuntime) -> CompletionResult | None;
    def _yield_recovery_result(
        recovery_resp: CompletionResult, iter_count: int, mt_run: MTRuntime
    ) -> Generator[StreamEvent, None, None];

    def _invoke_streaming(mt_run: MTRuntime) -> Generator[StreamEvent, None, None];
    def _invoke_with_handler(mt_run: MTRuntime, on_event: Callable) -> object;
    def _get_ctx_window(call_params: dict) -> int;
    def _resolve_compaction_params(mt_run: MTRuntime) -> dict;
    def _maybe_compact(
        mt_run: MTRuntime, usage: object, just_compacted: bool, cp: dict
    ) -> bool;

    def _emergency_compact_retry(
        mt_run: MTRuntime, just_compacted: bool, cp: dict
    ) -> CompletionResult;

    def _compact_messages(
        mt_run: MTRuntime, keep_recent: int, comp_model: str | None
    ) -> None;
}

"""Mock LLM connector that simulates responses for testing.

Useful for unit testing and development without making real API calls.
Configure outputs via the 'outputs' kwarg to control mock responses.
"""
obj MockLLM(BaseLLM) {
    # Text of the prompt (joined message contents) seen on each dispatch, in
    # order. Lets tests assert how many times the model was called and what the
    # retry loop fed back between attempts.
    has seen_prompts: list = [];

    def postinit -> None;
    override def dispatch_no_streaming(mt_run: MTRuntime) -> CompletionResult;
    override async def adispatch_no_streaming(mt_run: MTRuntime) -> CompletionResult;
    override def dispatch_streaming(mt_run: MTRuntime) -> Generator[str, None, None];
}

"""Local LLM connector backed by llama.cpp via `llama-cpp-python`.

Activated by `Model("local:<alias>")`. Weights are pulled lazily
through `byllm.model_cache` and the in-process `Llama` instance is
built on first call to keep plugin import cheap.
"""
obj LocalLLM(BaseLLM) {
    has alias: str = "",
        spec: dict = {},
        _llama: object = None;

    def postinit -> None;
    def _ensure_llama -> object;
    override def model_call_no_stream(params: dict) -> dict;
    override def model_call_with_stream(params: dict) -> Generator[object, None, None];
    override def _get_ctx_window(call_params: dict) -> int;
}

"""Pool of LLM models with fallback and load-balancing via LiteLLM Router.

Strategies: 'fallback' (ordered), 'simple-shuffle' (random pick per call),
'cost-based-routing' (cheapest first), 'latency-based-routing' (fastest first),
'least-busy' (least concurrent load), 'usage-based-routing' (least used first).
"""
obj ModelPool(BaseLLM) {
    has model_name: str = "pool-model",
        models: list[BaseLLM] = [],
        strategy: str | None = None,
        num_retries: int | None = None,
        timeout: float | None = None,
        _router: object = None,
        _fallback_model_names: list = [];

    def postinit -> None;
    override def model_call_no_stream(params: dict) -> dict;
    override def model_call_with_stream(params: dict) -> Generator[str, None, None];
    override def _get_ctx_window(call_params: dict) -> int;
}

"""Primary LLM connector that abstracts LiteLLM functionality

Provides a unified interface for interacting with various language models
(OpenAI, Anthropic, etc.) through LiteLLM. Supports both direct API calls
and proxy-based routing. Delegates to MockLLM when model_name is
'mockllm', and to LocalLLM (in-process llama.cpp) when model_name starts
with 'local:'.
"""
obj Model(BaseLLM) {
    has proxy: bool = False,
        http_client: bool = False,
        _mock_delegate: MockLLM | None = None,
        _local_delegate: BaseLLM | None = None,
        _async_proxy_client: AsyncOpenAI | None = None;

    def postinit -> None;
    override def invoke(mt_run: MTRuntime) -> object;
    def _raise_mapped_provider_error(e: Exception) -> None;
    def model_call_no_stream(params: dict) -> dict;
    async def model_call_no_stream_async(params: dict) -> dict;
    def model_call_with_stream(params: dict);
    async def model_call_with_stream_async(params: dict);
    def model_call_http(
        url: str, token: str, payload: dict, ca_bundle: str | bool
    ) -> object;

    async def model_call_http_async(
        url: str, token: str, payload: dict, ca_bundle: str | bool
    ) -> object;
}
