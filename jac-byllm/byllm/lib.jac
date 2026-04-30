"""byLLM Package."""
import from byllm.llm { MockLLM, Model, ModelPool }
import from byllm.mtir { MTIR, MTRuntime }
import from byllm.plugin { JacRuntime }
import from byllm.types {
    Image,
    IterationAction,
    IterationContext,
    Message,
    MessageRole,
    MockToolCall,
    StreamEvent,
    Tool,
    ToolCallResultMsg,
    Video
}
import from byllm.exceptions {
    ByLLMError,
    AuthenticationError,
    RateLimitError,
    ModelNotFoundError,
    OutputConversionError,
    UnknownToolError,
    FinishToolError,
    ConfigurationError,
    McpError
}
import from byllm.mcp { McpClient, McpTool }
import from byllm.telemetry { register_agent_callback }
import from byllm.parallel { dispatch_batch, mark_serialize }

glob by = JacRuntime.by ,
     __all__ = [
         'by',
         'ByLLMError',
         'AuthenticationError',
         'RateLimitError',
         'ModelNotFoundError',
         'OutputConversionError',
         'UnknownToolError',
         'FinishToolError',
         'ConfigurationError',
         'McpError',
         'McpClient',
         'McpTool',
         'Image',
         'IterationAction',
         'IterationContext',
         'Message',
         'MessageRole',
         'MockLLM',
         'MockToolCall',
         'Model',
         'ModelPool',
         'MTIR',
         'MTRuntime',
         'StreamEvent',
         'Tool',
         'ToolCallResultMsg',
         'Video',
         'register_agent_callback',
         'dispatch_batch',
         'mark_serialize'
     ];
