sem ChatType = """ChatType enum defines the types of chat interactions. ChatType must be one of:
- RAG: For interactions that require document retrieval.
- QA: For interactions that does not require document retrieval, or image-video-related questions.
- IMAGE: For interactions involving image analysis or anything related to images, and follow up questions.
- VIDEO: For interactions involving video analysis or video-related questions.
""";

sem Router.classify = "Classify the message as RAG, QA, or VIDEO. If classification fails, default to QA.";

sem ImageChat.respond_with_image = """Answer the user's message(text) by referring to the provided image. Always refer to the given image, answer relevant to the given image.""";

sem VideoChat.respond_with_video = """Answer the user's message using the provided video and text. Always refer to the given video, answer relevant to the given video.""";

sem RagChat.respond = """Generate a helpful response to the user's message. Use available mcp tool when needed.Use list_mcp_tools to find out what are the available tools. Always pass arguments as a flat dictionary (e.g., {\"query\": \"Your search query\"}), never as a list or schema_dict_wrapper. """;

sem QAChat.respond = """Generate a helpful response to the user's message.""";


impl ImageChat.chat {
    img_path = visitor.file_path;
    response = self.respond_with_image(
        img=Image(img_path),
        text=visitor.message,
        chat_history=visitor.chat_history
    );

    visitor.chat_history.append({"role": "assistant", "content": response});
    self.chat_history = visitor.chat_history;
    visitor.response = response;
    report {"response": response, "chat_history": visitor.chat_history};
}

impl VideoChat.chat {
    video_path = visitor.file_path;
    response = self.respond_with_video(
        video=Video(video_path),
        text=visitor.message,
        chat_history=visitor.chat_history
    );

    visitor.chat_history.append({"role": "assistant", "content": response});
    self.chat_history = visitor.chat_history;
    visitor.response = response;
    report {"response": response, "chat_history": visitor.chat_history};
}


impl RagChat.chat {
    response = self.respond(
        message=visitor.message,
        chat_history=visitor.chat_history,
    );
    visitor.chat_history.append({"role": "assistant", "content": response});
    self.chat_history = visitor.chat_history;
    visitor.response = response;
    report {"response": response, "chat_history": visitor.chat_history};
}

impl QAChat.chat {
    response = self.respond(
        message=visitor.message,
        chat_history=visitor.chat_history,
    );
    visitor.chat_history.append({"role": "assistant", "content": response});
    self.chat_history = visitor.chat_history;
    visitor.response = response;
    report {"response": response, "chat_history": visitor.chat_history};
}

impl upload_file.save_doc {
    upload_dir = os.path.join("uploads", self.session_id);
    if not os.path.exists(upload_dir) {
        os.makedirs(upload_dir);
    }

    file_path = os.path.join(upload_dir, self.file_name);
    data = base64.b64decode(self.file_data.encode('utf-8'));

    with open(file_path, 'wb') as f {
        f.write(data);
    }

    # Only add text-based documents to rag_engine
    lower_name = self.file_name.lower();
    if lower_name.endswith(".pdf") or lower_name.endswith(".txt") {
        rag_engine.add_file(file_path);
    }

    report {
        "status": "uploaded",
        "file_path": file_path,
        "added_to_rag": lower_name.endswith(".pdf") or lower_name.endswith(".txt")
    };
}

"""Get available MCP tool names."""
def list_mcp_tools() -> list[str] {
    return mcp_client.list_mcp_tools();
}

"""Use MCP tool to perform actions.
name must be one of available tools from list_mcp_tools(), do not make up any tool names.

Example input for `use_mcp_tool`:
{"name": "tool_name", "arguments": {"query": "your query"}}
"""
def use_mcp_tool(name: str, arguments: dict[str, str]) -> str {
    return mcp_client.call_mcp_tool(name=name, arguments=arguments);
}
