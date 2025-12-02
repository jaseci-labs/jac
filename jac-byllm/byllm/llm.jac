"""LLM abstraction module.

This module provides a LLM class that abstracts LiteLLM and offers
enhanced functionality and interface for language model operations.
"""

import logging;
import os;
import json;
import random;
import time;

import from typing { Generator }
import from byllm.mtir { MTIR }
import litellm;
import from litellm._logging { _disable_debugging }
import from openai { OpenAI }
import from byllm.types {
    CompletionResult,
    LiteLLMMessage,
    MockToolCall,
    ToolCall,
    Message,
    MessageRole
}
# This will prevent LiteLLM from fetching pricing information from
# the bellow URL every time we import the litellm and use a cached
# local json file. Maybe we we should conditionally enable this.
# https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json
with entry {
    os.environ["LITELLM_LOCAL_MODEL_COST_MAP"] = "True";
}

glob DEFAULT_BASE_URL = "http://localhost:4000";
glob MODEL_MOCK = "mockllm";

glob SYSTEM_PERSONA = """\
This is a task you must complete by returning only the output.
Do not include explanations, code, or extra text—only the result.
""";  # noqa E501


glob INSTRUCTION_TOOL = """
Use the tools provided to reach the goal. Call one tool at a time with \
proper args—no explanations, no narration. Think step by step, invoking tools \
as needed. When done, always call finish_tool(output) to return the final \
output. Only use tools.
""";  # noqa E501


"""Base class for LLM implementations."""
obj BaseLLM {
    def init(model_name: str, **kwargs: object) -> None {
        self.model_name = model_name;
        self.config = kwargs;
        self.api_key = self.config.get("api_key", "");
        # The parameters for the llm call like temprature, top_k, max_token, etc.
        # This is only applicable for the next call passed from `by llm(**kwargs)`.
        self.call_params: dict[str, object] = {};
    }

    """Construct the call parameters and return self (factory pattern)."""
    def __call__( **kwargs: object)  -> BaseLLM {
        self.call_params = kwargs;
        return self;
    }

    # @property
    # """Get the call parameters for the LLM."""
    # def call_params(self) -> dict[str, object] {
    #     raise NotImplementedError("Subclasses must implement this method.");
    # }
    def invoke(mtir: MTIR) -> object {
        # If streaming without tools, stream immediately
        if mtir.stream and len(mtir.tools) == 0 {
            return self.dispatch_streaming(mtir);
        }

        # Invoke the LLM and handle tool calls (ReAct loop).
        while True {
            resp = self.dispatch_no_streaming(mtir);
            if resp.tool_calls {
                for tool_call in resp.tool_calls {
                    if tool_call.is_finish_call() {
                        # If streaming is enabled, make a new streaming call
                        mtir.add_message(tool_call());
                        # to generate the final answer based on all context
                        if mtir.stream {
                            return self._stream_final_answer(mtir);
                        }
                        return tool_call.get_output();
                    } else {
                        mtir.add_message(tool_call());
                    }
                }
            } else {
                break;
            }
        }
        return resp.output;
    }

    """Prepare the parameters for the LLM call."""
    def make_model_params(mtir: MTIR) -> dict {
        params = {
            "model": self.model_name,
            "api_base": (
                self.config.get("base_url")
                or self.config.get("host")
                or self.config.get("api_base")
            ),
            "messages": mtir.get_msg_list(),
            "tools": mtir.get_tool_list() or None,
            "response_format": mtir.get_output_schema(),
            "temperature": self.call_params.get("temperature", 0.7),
            "max_tokens": self.call_params.get("max_tokens"),

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
    def dispatch_no_streaming(mtir: MTIR) -> CompletionResult {
        # Construct the parameters for the LLM call
        params = self.make_model_params(mtir);

        # Call the LiteLLM API
        log_params = (
            {** params, "api_key": "*" * len(params["api_key"])}
            if params.get("api_key")
            else params
        );
        self.log_info(f"Calling LLM: {self.model_name} with params:\n{log_params}");
        self.api_key = params.get("api_key");
        self.api_base = params.pop("api_base", DEFAULT_BASE_URL);
        response = self.model_call_no_stream(params);

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

            if tool := mtir.get_tool(tool_call.function.name) {
                args_json = json.loads(tool_call.function.arguments);
                args = tool.parse_arguments(args_json);
                tool_calls.append(ToolCall(call_id=tool_call.id, tool=tool, args=args));
            } else {
                raise RuntimeError(
                    f"Attempted to call tool: '{tool_call.function.name}' which was not present."
                ) ;
            }
        }

        return CompletionResult(output=output_value, tool_calls=tool_calls,);
    }

    """Dispatch the LLM call with streaming."""
    def dispatch_streaming(mtir: MTIR) -> Generator[str, None, None] {
        # Construct the parameters for the LLM call
        params = self.make_model_params(mtir);

        # Call the LiteLLM API
        log_params = (
            {** params, "api_key": "*" * len(params["api_key"])}
            if params.get("api_key")
            else params
        );
        self.log_info(f"Calling LLM: {self.model_name} with params:\n{log_params}");
        self.api_key = params.get("api_key");
        self.api_base = params.pop("api_base", DEFAULT_BASE_URL);
        response = self.model_call_with_stream(params);

        for chunk in response {
            if hasattr(chunk, "choices") {
                if chunk.choices and chunk.choices[0].delta {
                    delta = chunk.choices[0].delta;
                    yield delta.content or "";
                }
            }
        }
    }

    """Make a direct model call with the given parameters.
    Get api_key from self.api_key if needed.
    """
    def model_call_no_stream(params: dict) -> dict {
        raise NotImplementedError(
            "Subclasses must implement this method for LLM call with streaming."
        ) ;
    }

    """Make a direct model call with the given parameters.
    Get api_key from self.api_key if needed.
    """
    def model_call_with_stream(params: dict) -> Generator[str, None, None] {
        raise NotImplementedError(
            "Subclasses must implement this method for LLM call with streaming."
        ) ;
    }

    """Stream the final answer after ReAct tool calls complete.

    This creates a new streaming LLM call with all the context from tool calls
    to generate the final answer in real-time streaming mode.

    The difference from _stream_finish_output:
    - This makes a REAL streaming API call to the LLM
    - _stream_finish_output just splits an already-complete string
    """
    def _stream_final_answer(mtir: MTIR) -> Generator[str, None, None] {
        # Add a message instructing the LLM to provide the final answer
        # based on all the tool call results gathered so far
        final_instruction = Message(
            role=MessageRole.USER,
            content="Based on the tool calls and their results above, provide your final answer. ""Be comprehensive and synthesize all the information gathered.",
        );
        mtir.add_message(final_instruction);

        # Remove tools and make a streaming call to get the real-time answer
        # We temporarily clear tools so the LLM just responds with text
        original_tools = mtir.tools;
        mtir.tools = [];

        try {
            # Make the actual streaming call - this is REAL streaming from the LLM!
            yield from self.dispatch_streaming(mtir);
        } finally {
            # Restore tools (though we're done at this point)
            mtir.tools = original_tools;
        }
    }
}

"""LLM Connector for a mock LLM service that simulates responses."""
obj MockLLM(BaseLLM) {
    """Initialize the MockLLM connector."""
    def init(model_name: str, **kwargs: object) -> None {
        super.init(model_name, **kwargs);
    }

    """Dispatch the mock LLM call with the given request."""
    override def dispatch_no_streaming(mtir: MTIR) -> CompletionResult {
        params = self.make_model_params(mtir);
        output = self.config["outputs"].pop(0);  # type: ignore

        if isinstance(output, MockToolCall) {
            self.log_info(
                f"Mock LLM call completed with tool call:\n{output.to_tool_call()}"
            );
            return CompletionResult(output=None, tool_calls=[output.to_tool_call()],);
        }
        self.log_info(
            f"Mock LLM call completed with response:\n{output} with params:\n{params}"
        );
        return CompletionResult(output=output, tool_calls=[],);
    }

    """Dispatch the mock LLM call with the given request."""
    override def dispatch_streaming(mtir: MTIR) -> Generator[str, None, None] {
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

"""A wrapper class that abstracts LiteLLM functionality.

This class provides a simplified and enhanced interface for interacting
with various language models through LiteLLM.
"""
obj Model(BaseLLM) {
    """Initialize the JacLLM instance.
    Args:
        model: The model name to use (e.g., "gpt-3.5-turbo", "claude-3-sonnet-20240229")
        api_key: API key for the model provider
        **kwargs: Additional configuration options
    """
    def init(model_name: str, **kwargs: object) -> None {
        super.init(model_name, **kwargs);
        self.proxy = kwargs.get("proxy", False);
        # When model_name is 'mockllm', delegate to MockLLM behavior
        self._mock_delegate = MockLLM(model_name=model_name, **kwargs)
        if model_name == MODEL_MOCK
        else None;
        if not self._mock_delegate {
            logging.getLogger("httpx").setLevel(logging.WARNING);
            _disable_debugging();
            litellm.drop_params = True;
        }
    }

    """Invoke the LLM, delegating to MockLLM if applicable."""
    override def invoke(mtir: MTIR) -> object {
        if self._mock_delegate {
            return self._mock_delegate.invoke(mtir);
        }
        return super.invoke(mtir);
    }

    def model_call_no_stream(params: dict) -> dict {
        if self.proxy {
            client = OpenAI(base_url=self.chat);
            response = client.chat.completions.create(**params);
        } else {
            response = litellm.completion(**params);
        }
        return response;
    }

    def model_call_with_stream(params: dict) {
        if self.proxy {
            client = OpenAI(base_url=self.api_base, api_key=self.api_key,);
            response = client.chat.completions.create(stream=True, **params);
        } else {
            response = litellm.completion(stream=True, **params);
        }
        return response;
    }
}
# obj MyOpenAIModel(BaseLLM) {
#     """Initialize the MockLLM connector."""
#     def init(model_name: str, **kwargs: object) -> str {
#         super.init(model_name, **kwargs);
#     }

#     def model_call_no_stream(params: dict) -> dict {
#         client = OpenAI(api_key=self.api_key);
#         response = client.chat.completions.create(**params);
#         return response;
#     }

#     def model_call_with_stream(params: dict) {
#         client = OpenAI(api_key=self.api_key);
#         response = client.chat.completions.create(stream=True, **params);
#         return response;
#     }
# }
