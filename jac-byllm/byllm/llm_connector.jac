"""LLM Connector for Litellm, MockLLM, Proxy server, etc.

This module provides an abstract base class for LLM connectors and concrete implementations
for different LLM services. It includes methods for dispatching requests and handling responses.
"""
import from __future__ { annotations }

# flake8: noqa: E402

import json;
import logging;
import os;
import random;
import time;
import from abc { ABC, abstractmethod }
import from typing { Generator, override }
import from dataclasses { field }
import litellm;
import from litellm._logging { _disable_debugging }
import from openai { OpenAI }
import from byllm.mtir { MTIR }
import from byllm.types { CompletionResult, LiteLLMMessage, MockToolCall, ToolCall }

# This will prevent LiteLLM from fetching pricing information from
# the bellow URL every time we import the litellm and use a cached
# local json file. Maybe we should conditionally enable this.
# https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json

with entry{
    os.environ["LITELLM_LOCAL_MODEL_COST_MAP"] = "True";
}

glob DEFAULT_BASE_URL = "http://localhost:4000";
glob MODEL_MOCK = "mockllm";

obj LLMConnector(ABC) {
    """Abstract base class for LLM connectors."""
    has model_name: str;
    has config: dict[str, object];

    def postinit() {
        # This is only applicable for the next call passed from `by llm(**kwargs)`.
        self.call_params: dict[str, object] = {};
    }

    static
    def for_model(model_name: str, **kwargs: object) -> LLMConnector {
        if model_name.lower().strip() == MODEL_MOCK {
            return MockLLMConnector(model_name=model_name, config=kwargs);
        }
        if kwargs.get("proxy_url") {
            kwargs["base_url"] = kwargs.pop("proxy_url");
            return LiteLLMConnector(proxy=True, model_name=model_name, config=kwargs);
        }
        return LiteLLMConnector(proxy=False, model_name=model_name, config=kwargs);
    }

    def make_model_params(mtir: MTIR) -> dict {
        params = {
            "model": self.model_name,
            "api_base": (
                self.config.get("base_url")
                or self.config.get("host")
                or self.config.get("api_base")
            ),
            "api_key": self.config.get("api_key"),
            "messages": mtir.get_msg_list(),
            "tools": mtir.get_tool_list() or None,
            "response_format": mtir.get_output_schema(),
            "temperature": self.call_params.get("temperature", 0.7),
            "max_tokens": self.call_params.get("max_tokens"),
            # "top_k": self.call_params.get("top_k", 50),
            # "top_p": self.call_params.get("top_p", 0.9),

        };
        return params;
    }

    """Log a message to the console."""
    def log_info(message: str) -> None {
        # FIXME: The logger.info will not always log so for now I'm printing to stdout
        # remove and log properly.
        if bool(self.config.get("verbose", False)) {
            print(message);
        }
    }

    """Dispatch the LLM call without streaming."""
    @abstractmethod
    def dispatch_no_streaming(mtir: MTIR) -> CompletionResult {
        raise NotImplementedError() ;
    }

    """Dispatch the LLM call with streaming."""
    @abstractmethod
    def dispatch_streaming(mtir: MTIR) -> Generator[str, None, None] {
        raise NotImplementedError() ;
    }
}


# -----------------------------------------------------------------------------
# Mock LLM Connector
# -----------------------------------------------------------------------------

"""LLM Connector for a mock LLM service that simulates responses."""
obj MockLLMConnector(LLMConnector) {

    """Dispatch the mock LLM call with the given request."""
    override
    def dispatch_no_streaming(mtir: MTIR) -> CompletionResult {
        output = self.config["outputs"].pop(0);  # type: ignore

        if isinstance(output, MockToolCall) {
            self.log_info(
                f"Mock LLM call completed with tool call:\n{output.to_tool_call()}"
            );
            return CompletionResult(output=None, tool_calls=[output.to_tool_call()],);
        }

        self.log_info(f"Mock LLM call completed with response:\n{output}");

        return CompletionResult(output=output, tool_calls=[],);
    }

    """Dispatch the mock LLM call with the given request."""
    override
    def dispatch_streaming(mtir: MTIR) -> Generator[str, None, None] {
        output = self.config["outputs"].pop(0);  # type: ignore
        if mtir.stream {
            while output {
                chunk_len = random.randint(3, 10);
                yield output[:chunk_len];  # Simulate token chunk
                time.sleep(random.uniform(0.01, 0.05));  # Simulate network delay
                output = output[chunk_len:];
            }
        }
    }
}

# -----------------------------------------------------------------------------
# LiteLLM Connector
# -----------------------------------------------------------------------------


"""LLM Connector for LiteLLM, a lightweight wrapper around OpenAI API."""
obj LiteLLMConnector(LLMConnector) {

    has proxy: bool;

    def postinit() {
        super.postinit();

        # Every litellm call will be logged to the tty and that pollutes the output.
        # When there is a by llm() call in the jaclang.
        logging.getLogger("httpx").setLevel(logging.WARNING);
        _disable_debugging();
        litellm.drop_params = True;
    }

    """Dispatch the LLM call without streaming."""
    override
    def dispatch_no_streaming(mtir: MTIR) -> CompletionResult {
        # Construct the parameters for the LLM call
        params = self.make_model_params(mtir);

        # Call the LiteLLM API
        self.log_info(f"Calling LLM: {self.model_name} with params:\n{params}");
        if self.proxy {
            client = OpenAI(
                base_url=params.pop("api_base", "htpp://localhost:4000"),
                api_key=params.pop("api_key"),
            );
            response = client.chat.completions.create(**params);
        } else {
            response = litellm.completion(**params);
        }

        # Output format:
        # https://docs.litellm.ai/docs/#response-format-openai-format
        #
        # TODO: Handle stream output (type ignoring stream response)
        message: LiteLLMMessage = response.choices[0].message;  # type: ignore
        mtir.add_message(message);
        output_content: str = message.content or "";  # type: ignore
        self.log_info(f"LLM call completed with response:\n{output_content}");
        output_value = mtir.parse_response(output_content);

        tool_calls: list[ToolCall] = [];
        for tool_call in message.tool_calls or [] {  # type: ignore
            if tool := mtir.get_tool(tool_call["function"]["name"]) {
                args_json = json.loads(tool_call["function"]["arguments"]);
                args = tool.parse_arguments(args_json);
                tool_calls.append(
                    ToolCall(call_id=tool_call["id"], tool=tool, args=args)
                );
            } else {
                raise RuntimeError(
                    f"Attempted to call tool: '{tool_call['function']['name']}' which was not present."
                ) ;
            }
        }

        return CompletionResult(output=output_value, tool_calls=tool_calls,);
    }

    """Dispatch the LLM call with streaming."""
    override
    def dispatch_streaming(mtir: MTIR) -> Generator[str, None, None] {
        # Construct the parameters for the LLM call
        params = self.make_model_params(mtir);

        # Call the LiteLLM API
        self.log_info(f"Calling LLM: {self.model_name} with params:\n{params}");
        if self.proxy {
            client = OpenAI(
                base_url=params.pop("api_base"), api_key=params.pop("api_key"),
            );
            # Call the LiteLLM API
            response = client.chat.completions.create(**params, stream=True);
        } else {
            response = litellm.completion(**params, stream=True);  # type: ignore
        }
        for chunk in response {
            if chunk.choices and chunk.choices[0].delta {
                delta = chunk.choices[0].delta;
                yield delta.content or "";
            }
        }
    }
}
