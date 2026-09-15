"""The JSON HTTP transport rejects requests for a streaming iterator."""
import asyncio;
import from jaclang.byllm.llm { Model }
import from jaclang.byllm.exceptions { ConfigurationError }

test "JSON HTTP transport rejects synchronous streaming" {
    model = Model(model_name="mockllm", config={"http_client": True});
    with testraises(ConfigurationError) {
        model.model_call_with_stream({});
    }
}

test "JSON HTTP transport rejects asynchronous streaming" {
    model = Model(model_name="mockllm", config={"http_client": True});
    async def invoke {
        with testraises(ConfigurationError) {
            await model.model_call_with_stream_async({});
        }
    }
    asyncio.run(invoke());
}
