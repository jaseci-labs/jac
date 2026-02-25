"""Implementation of MCP Server core."""

import from typing { Any }
import asyncio;
import sys;
import logging;

glob logger = logging.getLogger("jac_mcp");

"""Start the MCP server with configured transport."""
impl JacMcpServer.start -> None {
    asyncio.run(_async_start(self));
}

"""Stop the MCP server gracefully."""
impl JacMcpServer.stop -> None {
    return;
}

"""Internal async server startup."""
async def _async_start(srv: JacMcpServer) -> None {
    import from mcp.server { Server }
    import from mcp.types {
        Resource,
        Tool,
        TextContent,
        Prompt,
        PromptMessage,
        PromptArgument,
        GetPromptResult
    }
    import from jac_mcp.resources { ResourceProvider }
    import from jac_mcp.tools { ToolProvider }
    import from jac_mcp.prompts { PromptProvider }
    import json;

    server = Server("jac-mcp");

    # Initialize providers
    rp = ResourceProvider();
    rp.index_resources();
    tp = ToolProvider();
    pp = PromptProvider();

    @server.list_resources()
    async def handle_list_resources -> list {
        items = rp.list_resources();
        result: list = [];
        for item in items {
            result.append(
                Resource(
                    uri=item["uri"],
                    name=item["name"],
                    description=item.get("description", ""),
                    mimeType=item.get("mimeType", "text/plain")
                )
            );
        }
        return result;
    }

    @server.read_resource()
    async def handle_read_resource(uri: object) -> str {
        uri_str = str(uri);
        content = rp.read_resource(uri_str);
        return content;
    }

    @server.list_tools()
    async def handle_list_tools -> list {
        items = tp.list_tools();
        result: list = [];
        for item in items {
            result.append(
                Tool(
                    name=item["name"],
                    description=item["description"],
                    inputSchema=item.get(
                        "inputSchema", {"type": "object", "properties": {}}
                    )
                )
            );
        }
        return result;
    }

    @server.call_tool()
    async def handle_call_tool(name: str, arguments: dict | None = None) -> list {
        args = arguments or {};
        tool_result = tp.call_tool(name, args);
        return [TextContent(type="text", text=json.dumps(tool_result, indent=2))];
    }

    @server.list_prompts()
    async def handle_list_prompts -> list {
        items = pp.list_prompts();
        result: list = [];
        for item in items {
            prompt_args: list = [];
            for arg in item.get("arguments", []) {
                prompt_args.append(
                    PromptArgument(
                        name=arg["name"],
                        description=arg.get("description", ""),
                        required=arg.get("required", False)
                    )
                );
            }
            result.append(
                Prompt(
                    name=item["name"],
                    description=item["description"],
                    arguments=prompt_args
                )
            );
        }
        return result;
    }

    @server.get_prompt()
    async def handle_get_prompt(
        name: str, arguments: dict | None = None
    ) -> GetPromptResult {
        args = arguments or {};
        prompt_result = pp.get_prompt(name, args);
        messages: list = [];
        for msg in prompt_result.get("messages", []) {
            messages.append(
                PromptMessage(
                    role=msg["role"],
                    content=TextContent(type="text", text=msg["content"])
                )
            );
        }
        return GetPromptResult(
            description=prompt_result.get("description", ""), messages=messages
        );
    }

    # Start transport
    if srv.transport == "stdio" {
        import from mcp.server.stdio { stdio_server }
        async with stdio_server() as (read_stream, write_stream) {
            await server.run(
                read_stream, write_stream, server.create_initialization_options()
            );
        }
    } elif srv.transport == "sse" {
        try {
            import from mcp.server.sse { SseServerTransport }
            import from starlette.applications { Starlette }
            import from starlette.routing { Route }
            import uvicorn;

            sse = SseServerTransport("/messages/");

            async def handle_sse(request: object) -> object {
                async with sse.connect_sse(
                    request.scope, request.receive, request._send
                ) as streams {
                    await server.run(
                        streams[0], streams[1], server.create_initialization_options()
                    );
                }
            }

            starlette_app = Starlette(
                routes=[
                    Route("/sse", endpoint=handle_sse),
                    Route(
                        "/messages/",
                        endpoint=sse.handle_post_message,
                        methods=["POST"]
                    ),

                ]
            );

            config = uvicorn.Config(
                starlette_app, host=srv.host, port=srv.port, log_level="info"
            );
            uvi_srv = uvicorn.Server(config);
            await uvi_srv.serve();
        } except ImportError as e {
            logger.error(f"SSE transport requires uvicorn and starlette: {e}");
            logger.error("Install with: pip install uvicorn starlette");
            sys.exit(1);
        }
    } elif srv.transport == "streamable-http" {
        try {
            import from mcp.server.streamable_http { StreamableHTTPServerTransport }
            import from starlette.applications { Starlette }
            import from starlette.routing { Mount }
            import uvicorn;

            transport_inst = StreamableHTTPServerTransport(
                mcp_endpoint="/mcp", is_json_response_enabled=True
            );

            starlette_app = Starlette(
                routes=[Mount("/mcp", app=transport_inst.handle_request), ]
            );

            config = uvicorn.Config(
                starlette_app, host=srv.host, port=srv.port, log_level="info"
            );
            uvi_srv = uvicorn.Server(config);
            await uvi_srv.serve();
        } except ImportError as e {
            logger.error(
                f"Streamable HTTP transport requires uvicorn and starlette: {e}"
            );
            logger.error("Install with: pip install uvicorn starlette");
            sys.exit(1);
        }
    } else {
        logger.error(f"Unknown transport: {srv.transport}");
        sys.exit(1);
    }
}
