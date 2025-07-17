# Jac MCP Chatbot Full Guide

## 1. Introduction & Overview
This guide will walk you through building a state-of-the-art Retrieval-Augmented Generation (RAG) chatbot using Jac Cloud, Jac-Streamlit, Model Context Protocol (MCP), LangChain, ChromaDB, and modern LLMs. You'll learn to:
- Upload and index your own documents (PDFs)
- Chat with an AI assistant that uses both your documents and LLMs
- Build modular MCP servers for tool management
- Use ReAct pattern for intelligent tool orchestration

## 2. Features & Architecture
- **Document Upload & Ingestion**: Upload PDFs, which are processed and indexed for semantic search.
- **Retrieval-Augmented Generation**: Combines LLMs with document retrieval for context-aware answers.
- **Web Search Integration**: Optionally augments responses with real-time web search results.
- **MCP Server Architecture**: Uses Model Context Protocol for modular, scalable tool management.
- **ReAct Pattern**: Intelligent reasoning and acting with tools using the ReAct methodology.
- **Streamlit Frontend**: User-friendly chat interface.
- **Session Management**: Maintains chat history and user sessions.

**Project Structure:**

- `client.jac`: Streamlit frontend for chat and document upload
- `server.jac`: Jac Cloud API server with session management and ReAct orchestration
- `mcp_server.jac`: MCP server exposing document search and web search tools
- `mcp_client.jac`: Client interface for communicating with MCP servers
- `tools.jac`: RAG engine and web search implementations
- `docs/`: Example PDFs for testing

## 3. Full Source Code

=== "client.jac"
    ```jac linenums="1"
    --8<-- "docs/learn/examples/rag_chatbot/solution/client.jac"
    ```

=== "mcp_server.jac"
    ```jac linenums="1"
    --8<-- "docs/learn/examples/rag_chatbot/solution/mcp_server.jac"
    ```

=== "mcp_client.jac"
    ```jac linenums="1"
    --8<-- "docs/learn/examples/rag_chatbot/solution/mcp_client.jac"
    ```

=== "server.jac"
    ```jac linenums="1"
    --8<-- "docs/learn/examples/rag_chatbot/solution/server.jac"
    ```

=== "tools.jac"
    ```jac linenums="1"
    --8<-- "docs/learn/examples/rag_chatbot/solution/tools.jac"
    ```

## 4. Setup Instructions
1. **Install dependencies** (Python 3.12+ recommended):
   ```bash
   pip install jaclang jac-cloud jac-streamlit mtllm langchain langchain-community langchain-openai langchain-chroma chromadb openai pypdf tiktoken requests mcp[cli] anyio
   ```
2. **Set environment variables** (for LLMs and web search):
   ```bash
   export OPENAI_API_KEY=<your-openai-key>
   export SERPER_API_KEY=<your-serper-key>
   ```
   Get a free Serper API key at [serper.dev](https://serper.dev/).
3. **Start the MCP server** (in one terminal):
   ```bash
   jac run mcp_server.jac
   ```
4. **Start the Jac Chatbot server** (in another terminal):
   ```bash
   jac serve server.jac
   ```
5. **Run the Streamlit frontend** (in a third terminal):
   ```bash
   jac streamlit client.jac
   ```

## 5. Streamlit Frontend (`client.jac`)
The frontend is built with Jac-Streamlit and handles authentication, PDF upload, and chat with an improved user experience.

**Updated Title and Chat Logic:**
```jac
st.title("Welcome to your Jac MCP Chatbot!");

if prompt := st.chat_input("What is up?") {
    st.session_state.messages.append({"role": "user", "content": prompt});

    with st.chat_message("user") {
        st.markdown(prompt);
    }

    with st.chat_message("assistant") {
        with st.spinner("Thinking...") {
            response = requests.post("http://localhost:8000/walker/interact", ...);
            st.write(response["reports"][0]["response"]);
            st.session_state.messages.append({"role": "assistant", "content": response["reports"][0]["response"]});
        }
    }
}
```
- Updated title to reflect MCP architecture
- Added spinner with "Thinking..." message for better user experience
- Captures user input, sends it to the backend, and displays both user and assistant messages in the chat UI.

**Authentication and Token Handling:**
```jac
response = requests.post(
    f"{INSTANCE_URL}/user/login",
    json={"email": TEST_USER_EMAIL, "password": TEST_USER_PASSWORD}
);
if response.status_code != 200 {
    # Try registering the user if login fails
    response = requests.post(
        f"{INSTANCE_URL}/user/register",
        json={"email": TEST_USER_EMAIL, "password": TEST_USER_PASSWORD}
    );
    ...
}
token = response.json()["token"];
```
- The app tries to log in a test user. If not found, it registers and logs in, then retrieves the token for API calls.

**PDF Upload:**
```jac
uploaded_file = st.file_uploader('Upload PDF');
if uploaded_file {
    file_b64 = base64.b64encode(uploaded_file.read()).decode('utf-8');
    response = requests.post(
        "http://localhost:8000/walker/upload_pdf",
        json={"file_name": uploaded_file.name, "file_data": file_b64},
        headers={"Authorization": f"Bearer {token}"}
    );
    ...
}
```
- Lets users upload PDFs, which are base64-encoded and sent to the backend for processing.

## 6. MCP Server Architecture (`mcp_server.jac`)
The MCP server exposes tools for document search and web search using the Model Context Protocol.

**MCP Server Setup:**
```jac
with entry {
    mcp = FastMCP(name="RAG-MCP", port=8899);
}

@mcp.tool(name="search_docs")
@resolve_hints
async def tool_search_docs(query: str) -> str {
    return rag_engine.search(query);
}

@mcp.tool(name="search_web")
@resolve_hints
async def tool_search_web(query: str) -> str {
    web_search_results = web_search.search(query);
    if not web_search_results {
        return "Mention No results found for the web search";
    }
    return web_search_results;
}
```
- Creates a FastMCP server that exposes document search and web search as tools
- Uses decorators to register async functions as MCP tools
- Runs on port 8899 with streamable-http transport

## 7. MCP Client Interface (`mcp_client.jac`)
The MCP client handles communication with the MCP server.

**MCP Tool Calling:**
```jac
def call_mcp_tool(name: str, arguments:dict) -> str {
    async def _call()  -> str {
        async with streamable_http.streamablehttp_client(MCP_SERVER_URL) as (read, write, _)  {
            async with mcp.ClientSession(read, write) as sess  {
                await sess.initialize();
                result = await sess.call_tool(name=name, arguments=arguments);
                if result.isError {
                    return f"'MCP error: '{result.error.message}";
                }
                if (result.structuredContent and ('result' in result.structuredContent) ) {
                    return result.structuredContent[ 'result' ];
                } if (result.content and (len(result.content) > 0) ) {
                    return result.content[ 0 ].text;
                }
            }
        }
    }
    return anyio.run(_call);
}
```
- Establishes connection to MCP server using streamable HTTP
- Calls tools by name with provided arguments
- Handles both structured content and text responses

## 8. RAG Engine & Web Search (`tools.jac`)
The RAG engine manages document ingestion, chunking, embedding, and retrieval.

The objects `RagEngine` and `WebSearch` are imported as `from rag {RagEngine, WebSearch}` in other files.

**Document Loading and Chunking:**
```jac
def load_documents {
    document_loader = PyPDFDirectoryLoader(self.file_path);
    return document_loader.load();
}
def split_documents(documents: list[Document]) {
    text_splitter = RecursiveCharacterTextSplitter(...);
    return text_splitter.split_documents(documents);
}
```
- Loads all PDFs from the docs directory and splits them into manageable chunks for embedding and retrieval.

**Embedding and Storing:**
```jac
def get_embedding_function {
    embeddings = OpenAIEmbeddings();
    return embeddings;
}
def add_to_chroma(chunks: list[Document]) {
    db = Chroma(persist_directory=self.chroma_path, embedding_function=self.get_embedding_function());
    ...
    db.add_documents(new_chunks, ids=new_chunk_ids);
}
```
- Generates embeddings for each chunk and stores them in ChromaDB, using unique IDs to avoid duplicates.

**Semantic Search:**
```jac
def get_from_chroma(query: str,chunck_nos: int=5) {
    db = Chroma(...);
    results = db.similarity_search_with_score(query,k=chunck_nos);
    return results;
}
```
- Retrieves the most relevant document chunks for a user query using vector similarity search.

## 9. Backend Logic & Session Handling (`server.jac`)
The backend manages sessions, chat history, and coordinates with MCP tools using the ReAct pattern.

**Session Node with ReAct Integration:**
```jac
node Session {
    has id: str;
    has chat_history: list[dict];
    has status: int = 1;

    "Generate a helpful response to the user's message. Use available mcp tool when needed."
    def respond(message:str, chat_history:list[dict]) -> str
        by llm(
            method="ReAct",
            tools=([use_mcp_tool]),
            messages=chat_history,
            max_react_iterations=6
        );
}
```
- Each user session has a unique ID and chat history
- The `respond` method uses ReAct pattern for intelligent tool orchestration
- LLM can reason about which tools to use and when
- Uses the updated `Model` class from mtllm

**MCP Tool Integration:**
```jac
"""Available tools: 'search_docs' or 'search_web' with {"query": "your query"}.

Example:
{"name": "search_docs", "arguments": {"query": "example"}}
"""
def use_mcp_tool(name: str, arguments: dict[str, str]) -> str {
    return mcp_client.call_mcp_tool(name=name, arguments=arguments);
}
```
- Provides clear documentation for available tools
- Bridges the LLM's tool calls to the MCP server
- Allows seamless integration between ReAct and MCP tools

**Chat Walker:**
```jac
walker interact {
    has message: str;
    has session_id: str;

    can init_session with `root entry {
         visit [-->](`?Session)(?id == self.session_id) else {
            session_node = here ++> Session(id=self.session_id, chat_history=[], status=1);
            print("Session Node Created");
            visit session_node;
        }
    }

    can chat with Session entry {
        here.chat_history.append({"role": "user", "content": self.message});
        response = here.respond(
            message=self.message,
            chat_history=here.chat_history,
        );
        here.chat_history.append({"role": "assistant", "content": response});
        report {"response": response};
    }
}
```
- Handles incoming chat messages and manages session creation
- Uses ReAct pattern where the LLM decides which tools to call based on the message
- The LLM can autonomously choose between document search and web search

**PDF Upload Walker:**
```jac
walker upload_pdf {
    has file_name: str;
    has file_data: str;
    ...
    can save_doc with `root entry {
        ...
        rag_engine.add_file(file_path);
        report {"status": "uploaded"};
    }
}
```
- Saves uploaded PDFs to disk and triggers ingestion into the RAG engine.

## 10. Usage Guide
- Open the Streamlit app in your browser.
- Upload one or more PDF files. The backend will process and index them.
- Start chatting! Ask questions about the uploaded documents or general queries.
- The bot will use both your documents and LLMs to answer.

## 11. API Endpoints (selected)
- `POST /user/register` — Register a new user
- `POST /user/login` — Login and receive an access token
- `POST /walker/upload_pdf` — Upload a PDF (requires Bearer token)
- `POST /walker/interact` — Chat endpoint (requires Bearer token)

See `http://localhost:8000/docs` for full Swagger API documentation.

## 12. Advanced Features
- **Web Search**: If enabled and API key is set, the bot can augment answers with real-time web search results.
- **ChromaDB Vector Search**: Efficient semantic search over your documents.
- **Session Management**: Each chat session is tracked for context.
- **MCP Architecture**: Modular tool system using Model Context Protocol.
- **ReAct Pattern**: Intelligent reasoning and acting capabilities.
- **Extensible**: Add new walkers or endpoints in Jac for custom logic.

## 13. Troubleshooting
- Ensure all dependencies are installed and compatible with your Python version.
- Make sure to start the MCP server before the main server.
- If document upload fails, check server logs for errors.
- For LLM/API issues, verify your API keys and environment variables.
- Check that all three services (MCP server, main server, frontend) are running on their respective ports.

---
For a quick overview, see `Overview`.
