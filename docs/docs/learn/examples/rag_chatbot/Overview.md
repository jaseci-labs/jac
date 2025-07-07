# RAG Chatbot Overview

This project demonstrates a modern Retrieval-Augmented Generation (RAG) chatbot built using the Jac programming language, MTLLM, and Jac Cloud. It combines document ingestion, semantic search, and large language models (LLMs) to deliver a conversational AI experience that can answer questions based on your own documents. The latest version uses **Agentic RAG** where the LLM autonomously decides when to retrieve documents or search the web using the ReAct method.

## Key Features

- **Document Upload & Ingestion**: Upload PDF files, which are automatically processed and indexed for semantic search.
- **Retrieval-Augmented Generation**: Combines LLMs with document retrieval for accurate, context-aware answers.
- **Agentic RAG with ReAct**: The LLM decides when to fetch documents or perform web search using specialized tools.
- **Web Search Integration**: Optionally augments responses with real-time web search results.
- **Streamlit Frontend**: User-friendly chat interface for interacting with the bot and uploading documents.
- **API Server**: RESTful endpoints for chat, document upload, and more, powered by Jac Cloud.
- **Session Management**: Maintains chat history and user sessions.

## Technologies Used
- Jac & Jac Cloud & Jac MTLLM
- LangChain, ChromaDB, PyPDF, Streamlit
- OpenAI or local LLMs (Ollama)

## Architecture

- **client.jac**: Implements the Streamlit-based frontend for chat and document upload.
- **server.jac**: Hosts the API, manages sessions, LLM calls, and web search.
- **rag.jac**: Handles document loading, splitting, embedding, and vector search using ChromaDB and LangChain.


=== "Frontend Preview"
    ![RAG Chatbot Frontend](images/chatbot.jpg)

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

---

## How to Run

Install the necessary dependacies
```bash
pip install jaclang jac-cloud jac-streamlit mtllm langchain-openai langchain-community chromadb pypdf
```

To use the Web Search, get a free API key from [Serper](https://serper.dev/).
```bash
export OPENAI_API_KEY=<your-openai-key>
export SERPER_API_KEY=<your-serper-key>
```

To run the server
```bash
jac serve server.jac
```

To run the frontend
```bash
jac streamlit client.jac
```


For full setup instructions and advanced usage, see `Full Guide`.
