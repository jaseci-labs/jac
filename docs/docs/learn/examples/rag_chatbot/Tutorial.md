# RAG Chatbot Full Guide

## 1. Introduction & Overview
This guide will walk you through building a state-of-the-art Retrieval-Augmented Generation (RAG) chatbot using Jac Cloud, Jac-Streamlit, LangChain, ChromaDB, and modern LLMs. You’ll learn to:
- Upload and index your own documents (PDFs)
- Chat with an AI assistant that uses both your documents and LLMs
- Add advanced dialogue routing for smarter conversations

## 2. Features & Architecture
- **Document Upload & Ingestion**: Upload PDFs, which are processed and indexed for semantic search.
- **Retrieval-Augmented Generation**: Combines LLMs with document retrieval for context-aware answers.
- **Web Search Integration**: Optionally augments responses with real-time web search results.
- **Streamlit Frontend**: User-friendly chat interface.
- **Dialogue Routing**: Classifies queries and routes them to the best model (RAG or QA).
- **Session Management**: Maintains chat history and user sessions.

**Project Structure:**
- `client.jac`: Streamlit frontend for chat and document upload
- `server.jac`: Jac Cloud API server, session, LLM, and web search logic
- `rag.jac`: RAG engine for document loading, splitting, embedding, and vector search
- `docs/`: Example PDFs for testing

## 3. Full Source Code

=== "client.jac"
    ```jac linenums="1"
    --8<-- "docs/learn/examples/rag_chatbot/solution/client.jac"
    ```

=== "rag.jac"
    ```jac linenums="1"
    --8<-- "docs/learn/examples/rag_chatbot/solution/rag.jac"
    ```

=== "server.jac"
    ```jac linenums="1"
    --8<-- "docs/learn/examples/rag_chatbot/solution/server.jac"
    ```

## 4. Setup Instructions
1. **Install dependencies** (Python 3.12+ recommended):
   ```bash
   pip install jaclang jac-cloud jac-streamlit mtllm langchain-openai langchain-community chromadb pypdf
   ```
2. **Set environment variables** (for LLMs and web search):
   ```bash
   export OPENAI_API_KEY=<your-openai-key>
   export SERPER_API_KEY=<your-serper-key>
   ```
   Get a free Serper API key at [serper.dev](https://serper.dev/).
3. **Start the Jac Chatbot server**:
   ```bash
   jac serve server.jac
   ```
4. **Run the Streamlit frontend**:
   ```bash
   jac run client.jac
   ```

## 4. Streamlit Frontend (`client.jac`)
The frontend is built with Jac-Streamlit and handles authentication, PDF upload, and chat. Here’s how it works:

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

**Chat Logic:**
```jac
if prompt := st.chat_input("What is up?") {
    st.session_state.messages.append({"role": "user", "content": prompt});
    ...
    response = requests.post("http://localhost:8000/walker/interact", ...);
    ...
    st.session_state.messages.append({"role": "assistant", "content": response["reports"][0]["response"]});
}
```
- Captures user input, sends it to the backend, and displays both user and assistant messages in the chat UI.

## 5. RAG Engine (`rag.jac`)
The RAG engine manages document ingestion, chunking, embedding, and retrieval.

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

## 6. Backend Logic & Session Handling (`server.jac`)
The backend manages sessions, chat history, and combines RAG and LLM responses.

**Session Node:**
```jac
node Session {
    has id: str;
    has chat_history: list[dict];
    ...
    def respond(message:str, chat_history:list[dict]) -> str
        by llm(method="ReAct", tools=[search_docs, search_web]);
}
```
- Each user session has a unique ID and chat history. The `respond` method uses an LLM to generate answers, optionally using context from documents and web search.

**Chat Walker:**
```jac
walker interact {
    has message: str;
    has session_id: str;
    ...
    can chat with Session entry {
        here.chat_history.append({"role": "user", "content": self.message});
        response = here.respond(
            message=self.message,
            chat_history=here.chat_history
        );
        here.chat_history.append({"role": "assistant", "content": response});
        report {"response": response};
    }
}
```
- Handles incoming chat messages, retrieves relevant docs and web results, and generates a response using the LLM.
- Handles incoming messages and lets the LLM use tools to search docs or the web when needed, producing a final answer.

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

## 7. Usage Guide
- Open the Streamlit app in your browser.
- Upload one or more PDF files. The backend will process and index them.
- Start chatting! Ask questions about the uploaded documents or general queries.
- The bot will use both your documents and LLMs to answer.

## 8. API Endpoints (selected)
- `POST /user/register` — Register a new user
- `POST /user/login` — Login and receive an access token
- `POST /walker/upload_pdf` — Upload a PDF (requires Bearer token)
- `POST /walker/interact` — Chat endpoint (requires Bearer token)

See `http://localhost:8000/docs` for full Swagger API documentation.

## 9. Advanced Features
- **Web Search**: If enabled and API key is set, the bot can augment answers with real-time web search results.
- **ChromaDB Vector Search**: Efficient semantic search over your documents.
- **Session Management**: Each chat session is tracked for context.
- **Extensible**: Add new walkers or endpoints in Jac for custom logic.

## 10. Troubleshooting
- Ensure all dependencies are installed and compatible with your Python version.
- If document upload fails, check server logs for errors.
- For LLM/API issues, verify your API keys and environment variables.

---
For a quick overview, see `Overview`.
