"""LLM abstraction module.

This module provides a LLM class that abstracts LiteLLM and offers
enhanced functionality and interface for language model operations.
"""
import logging;
import from loguru { logger }
import os;
import sys;
import json;
import random;
import time;

import from typing { Generator }
import from byllm.mtir { MTRuntime }
import litellm;
import from litellm._logging { _disable_debugging }
import from openai { OpenAI }
import openai;
import from byllm.exceptions {
    AuthenticationError,
    OutputConversionError,
    RateLimitError,
    ModelNotFoundError,
    UnknownToolError,
    ConfigurationError,
    CompactionNotEffectiveError
}
import from byllm.types {
    CompletionResult,
    LiteLLMMessage,
    MockToolCall,
    StreamEvent,
    ToolCall,
    Message,
    MessageRole,
    IterationAction,
    IterationContext
}
import from byllm.config_loader { get_byllm_config }
import from byllm.telemetry { _emit_agent_telemetry, _current_invocation_id }
import from byllm.parallel { dispatch_batch, _index_by_identity, _PARALLEL_TOOL_HINT }

# Load configuration purely from jac.toml
glob _byllm_config = get_byllm_config(),
     _litellm_config = _byllm_config.get_litellm_config(),
     _model_config = _byllm_config.get_model_config(),
     _call_params_config = _byllm_config.get_call_params_config(),
     _parallel_config = _byllm_config.get_parallel_config(),
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
        _usage_history: list = [];

    def __call__(**kwargs: object) -> BaseLLM;
    def invoke(mt_run: MTRuntime) -> object;
    def _invoke_react_loop(mt_run: MTRuntime) -> object;
    def _invoke_react_loop_streaming(
        mt_run: MTRuntime
    ) -> Generator[object, None, None];

    def make_model_params(mt_run: MTRuntime) -> dict;
    def log_info(message: str) -> None;
    def format_prompt(params: dict) -> str;
    def dispatch_no_streaming(mt_run: MTRuntime) -> CompletionResult;
    def dispatch_streaming(mt_run: MTRuntime) -> Generator[str, None, None];
    def model_call_no_stream(params: dict) -> dict;
    def model_call_with_stream(params: dict) -> Generator[str, None, None];
    def _stream_final_answer(mt_run: MTRuntime) -> Generator[str, None, None];
    def _force_final_answer(mt_run: MTRuntime) -> object;
    def _attempt_recovery(mt_run: MTRuntime) -> CompletionResult | None;
    def _yield_recovery_result(
        recovery_resp: CompletionResult, iter_count: int, mt_run: MTRuntime
    ) -> Generator[StreamEvent, None, None];

    def _invoke_streaming(mt_run: MTRuntime) -> Generator[StreamEvent, None, None];
    def _get_ctx_window(call_params: dict) -> int;
    def _resolve_compaction_params(mt_run: MTRuntime) -> dict;
    def _compact_messages(
        mt_run: MTRuntime, keep_recent: int, comp_model: str | None
    ) -> None;
}

"""Mock LLM connector that simulates responses for testing.

Useful for unit testing and development without making real API calls.
Configure outputs via the 'outputs' kwarg to control mock responses.
"""
obj MockLLM(BaseLLM) {
    def postinit -> None;
    override def dispatch_no_streaming(mt_run: MTRuntime) -> CompletionResult;
    override def dispatch_streaming(mt_run: MTRuntime) -> Generator[str, None, None];
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
and proxy-based routing. Automatically delegates to MockLLM when model_name
is 'mockllm'.
"""
obj Model(BaseLLM) {
    has proxy: bool = False,
        http_client: bool = False,
        _mock_delegate: MockLLM | None = None;

    def postinit -> None;
    override def invoke(mt_run: MTRuntime) -> object;
    def model_call_no_stream(params: dict) -> dict;
    def model_call_with_stream(params: dict);
    def model_call_http(
        url: str, token: str, payload: dict, ca_bundle: str | bool
    ) -> object;
}
