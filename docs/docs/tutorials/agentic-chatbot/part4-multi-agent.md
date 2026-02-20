# Part 4: Multi-Agent Agentic Chat

A single `DocChat` node handles all queries through one LLM call. This step replaces it with **four specialist agent nodes** - `RagAgent`, `CodingAgent`, `DebuggerAgent`, and `GreetingAgent`. The LLM decides which agents to visit per request. No explicit routing code; the graph traversal *is* the routing.

**Prerequisites:** Complete [Part 3](part3-rag-docs.md) first.

---

## What Changes in Step 4

| Layer | What's new |
|-------|------------|
| Backend | Four agent nodes; `Session.setup` + `Session.respond` replace `Session.chat`; `visit [-->] by llm()` for LLM-guided fan-out; `gathered_context` accumulator on walker; `impl` files split into `server.impl/` |
| Frontend | **No changes** - identical to Step 3 |

The frontend from Step 3 works without modification. All new behaviour is pure backend.
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  
**Project layout:**

```
step-4-agentic-chat/
├── services/
│   ├── server.jac               # Nodes, walkers, agent definitions
│   ├── server.impl/
│   │   ├── session.impl.jac     # Session.setup + Session.respond bodies
│   │   └── agents.impl.jac      # RagAgent/CodingAgent/DebuggerAgent/GreetingAgent retrieve bodies
│   ├── rag_engine.py
│   └── faiss_index/
└── (all frontend files identical to Step 3)
```

---

## Graph Topology

```
root
└── Session
    ├── RagAgent       - get_relevant_context()    (LLM + search_docs)
    ├── CodingAgent    - write_code()               (LLM + search_docs)
    ├── DebuggerAgent  - find_debugging_tips()      (LLM + search_docs)
    └── GreetingAgent  - (no retrieval)
```

Agent nodes are created **lazily** on the first message to a session and persist as permanent children for the session's lifetime. Every subsequent message reuses the same four nodes.

---

## Execution Sequence Per Request

```
interact → Root          init_session: find or create Session, visit it
interact → Session       setup (entry): append user msg, create agents if absent,
                         visit [-->] by llm() - LLM selects which agents to visit
interact → agent(s)      retrieve: each selected agent calls its LLM method,
                         appends result to visitor.gathered_context
interact ← Session       respond (exit): join gathered_context,
                         call Session.synthesize() (Reason LLM), stream SSE
```

Three LLM calls per request, each with a clear role:

1. `visit [-->] by llm(incl_info={"context": message})` - routing
2. `agent.{method}(message)` - per-agent retrieval with `search_docs` tool
3. `Session.synthesize(...)` - final answer synthesis with full context

---

## Backend

### Updated `Session` Node

```jac
"""Persistent chat session - stores history and owns the four agent nodes."""
node Session {
    has id: str;
    has chat_history: list[dict] = [];
    has created_at: str = "";
    has updated_at: str = "";

    def synthesize(message: str, context: str, chat_history: list[dict]) -> str by llm(
        messages=chat_history,
        stream=True
    );

    can setup   with interact entry;
    can respond with interact exit;
}

sem Session.synthesize = "Final response synthesizer that answers using aggregated documentation context from all agents.";
```

**`can setup with interact entry`** - fires when `interact` first visits the `Session` node.

**`can respond with interact exit`** - fires when `interact` *leaves* the `Session` node (after visiting all selected agents). This is where the final answer is synthesized and streamed.

**`def synthesize(...) by llm()`** - the final-answer LLM method. `messages=chat_history` provides full conversation context; `stream=True` streams the result as SSE chunks.

**`sem Session.synthesize`** - the semantic annotation sets the system prompt for the synthesizer, instructing it to use all gathered context to produce a final answer.

### Four Agent Nodes

```jac
node RagAgent {
    def get_relevant_context(message: str) -> str by llm(tools=[search_docs]);
    can retrieve with interact entry;
}

node CodingAgent {
    def write_code(message: str) -> str by llm(tools=[search_docs]);
    can retrieve with interact entry;
}

node DebuggerAgent {
    def find_debugging_tips(message: str) -> str by llm(tools=[search_docs]);
    can retrieve with interact entry;
}

node GreetingAgent {
    can retrieve with interact entry;
}
```

Each agent has:

- A specialised LLM method (`by llm(tools=[search_docs])`) named for what it does
- A `retrieve` ability that fires when `interact` visits it

**`GreetingAgent`** has no retrieval method - greetings and chitchat need no documentation.

### Updated `interact` Walker

```jac
walker interact {
    has message: str;
    has session_id: str;
    has user_email: str = "";
    has chat_history: list[dict] = [];
    has gathered_context: list[str] = [];

    """Find the matching Session node or create a new one, then visit it."""
    can init_session with Root entry {
        found = [-->(?:Session, id == self.session_id)];
        if found {
            visit found;
        } else {
            now = datetime.now().isoformat();
            visit here ++> Session(
                id=self.session_id,
                chat_history=[],
                created_at=now,
                updated_at=now
            );
        }
    }
}
```

**`has gathered_context: list[str] = []`** - new field. Each agent appends its retrieved context string here as the walker traverses. `Session.respond` then joins them all for the synthesizer.

### `impl Session.setup` - LLM-Guided Fan-Out

```jac
impl Session.setup {
    print(f"Session {self.id} received message: {visitor.message}");
    self.chat_history.append({"role": "user", "content": visitor.message});
    self.updated_at = datetime.now().isoformat();
    visitor.chat_history = self.chat_history;

    # Lazy agent creation - agents persist for the session's lifetime
    if not [-->](?:RagAgent) {
        self ++> RagAgent();
        self ++> CodingAgent();
        self ++> DebuggerAgent();
        self ++> GreetingAgent();
    }

    visit [-->] by llm(incl_info={"context": visitor.message});
}
```

**`if not [-->](?:RagAgent)`** - checks whether any `RagAgent` children exist. On the first message, all four agents are created and connected to the session. Subsequent messages reuse them.

**`visit [-->] by llm(incl_info={"context": visitor.message})`** - the routing call. `[-->]` gives the LLM all children of the current node (the four agents). `by llm()` asks the LLM which subset to visit based on the message. `incl_info` passes additional context (the user message) so the LLM can make an informed selection. The LLM may select one, several, or all agents.

### `impl Session.respond` - Synthesis and Streaming

```jac
impl Session.respond {
    context = "\n\n---\n\n".join(visitor.gathered_context);
    report stream_chunks(
        self.synthesize(
            message=visitor.message,
            context=context,
            chat_history=visitor.chat_history
        ),
        visitor.session_id
    );
}
```

This is the `exit` ability - it runs after the walker has finished visiting all selected agent nodes. `visitor.gathered_context` now contains all retrieved snippets; they're joined with a `---` separator and passed to `Session.synthesize` as a single `context` argument.

**`report stream_chunks(...)`** - the synthesis result is streamed back as SSE chunks, exactly like the earlier steps.

### Agent Retrieve Implementations

```jac
impl RagAgent.retrieve {
    print("RagAgent retrieving context");
    result = self.get_relevant_context(visitor.message);
    visitor.gathered_context.append(result);
}

impl CodingAgent.retrieve {
    print("CodingAgent retrieving context");
    result = self.write_code(f"code examples and implementation for: {visitor.message}");
    visitor.gathered_context.append(result);
}

impl DebuggerAgent.retrieve {
    print("DebuggerAgent retrieving context");
    result = self.find_debugging_tips(f"debugging, errors, and troubleshooting for: {visitor.message}");
    visitor.gathered_context.append(result);
}

impl GreetingAgent.retrieve {
    # No doc retrieval needed for greetings and chitchat.
}
```

Each agent calls its own LLM method (which uses `search_docs` as a tool) and appends the string result to `visitor.gathered_context`. The walker accumulates context as it traverses - order of agents in `gathered_context` follows the order they were visited.

**`visitor.gathered_context.append(result)`** - writes to the walker's list directly from inside a node ability. The walker carries this list to `Session.respond`.

!!! tip "Specialised prompts"
    `CodingAgent` and `DebuggerAgent` wrap the user message with intent-clarifying prefixes (`"code examples and implementation for: ..."`, `"debugging, errors, and troubleshooting for: ..."`). This gives the ReAct LLM inside those methods a stronger signal about what to search for.

---

## Frontend

The frontend from Step 3 is **unchanged**. The `DocumentationPanel`, `useChat` hook, `jacService`, and all UI components work without modification. The only visible difference from the user's perspective is that answers may feel more accurate for coding and debugging questions - a backend-only improvement.

---

## Run It

??? note "Complete `jac.toml`"

    ```toml
    [project]
    name = "step-4-agentic-chat"
    version = "1.0.0"
    description = "Tutorial Step 4: Multi-agent routing via walker spawn"
    entry-point = "main.jac"

    [dependencies]
    python-dotenv = ">=0.0.0"
    langchain-openai = ">=0.0.0"
    langchain-community = ">=0.0.0"
    langchain-text-splitters = ">=0.0.0"
    faiss-cpu = ">=0.0.0"
    sentence-transformers = ">=0.0.0"
    pypdf = ">=0.0.0"
    numpy = ">=0.0.0"

    [dev-dependencies]
    watchdog = "~=6.0"

    [dependencies.npm]
    jac-client-node = "1.0.4"
    react-markdown = "^9.0.0"
    rehype-highlight = "^7.0.0"
    "highlight.js" = "^11.9.0"
    "@mantine/core" = "^7.15.0"
    "@mantine/hooks" = "^7.15.0"
    "@tabler/icons-react" = "^3.28.0"
    "@emotion/react" = "^11.14.0"

    [dependencies.npm.dev]
    "@jac-client/dev-deps" = "1.0.0"

    [serve]
    base_route_app = "app"

    # ── App configuration ──────────────────────────────────────────────────────────
    # Edit these values to customise the chatbot without touching source code.
    # OPENAI_API_KEY must still be provided via a .env file or environment variable.
    [config]
    chatbot_name   = "DocBot"
    llm_model      = "gpt-4.1-mini"
    docs_site_url  = ""          # Base URL of your hosted docs (used to build suggest_docs links)
    github_repo_url = "https://github.com/jaseci-labs/jaseci"         # Optional: clone + ingest a GitHub repo on first startup
    github_branch   = "main"

    # ── RAG / FAISS configuration ─────────────────────────────────────────────────
    [config.rag]
    docs_path            = "services/docs"
    faiss_path           = "services/faiss_index"
    chunk_size           = 800
    chunk_overlap        = 100
    similarity_search_k  = 30
    reranking_top_n      = 7
    reranking_model      = "cross-encoder/ms-marco-MiniLM-L6-v2"

    [plugins]
    [plugins.client]
    ```

```bash
cd step-4-agentic-chat
cp .env.example .env   # add your OPENAI_API_KEY
jac install            # install Python + npm dependencies
jac start              # start the server
```

Open `http://localhost:8000`. Try a few different message types and watch the server logs:

```
RagAgent retrieving context
CodingAgent retrieving context
```

The LLM selects only the relevant agents for each query - a greeting will show only `GreetingAgent`, a coding question will invoke `CodingAgent` (and likely `RagAgent` too).

!!! tip "Resetting the environment"
    `jac clean` removes data files (e.g. the persisted graph and FAISS index). `jac clean --all` removes compiled files and data too - run `jac install` again afterwards to reinstall dependencies.

!!! tip "Observing routing decisions"
    The `print` statements in each `retrieve` impl log which agents were selected. Add more logging to `Session.setup` to print `visitor.gathered_context` before synthesis.

??? note "Complete `services/server.jac`"

    ```jac
    """Step 4: Agentic chat - LLM-guided multi-agent retrieval with streaming synthesis."""

    import os;
    import json;
    import from byllm.lib { Model }
    import from dotenv { load_dotenv }
    import from datetime { datetime }
    import from services.rag_engine { RagEngine }
    import from jaclang.project.config { get_config }

    with entry {
        load_dotenv();
    }

    glob _jac_config = get_config();
    glob _cfg: dict = _jac_config._raw_data.get("config", {}) if _jac_config else {};
    glob _rag: dict = _cfg.get("rag", {});

    glob docs_path: str  = _rag.get("docs_path", "services/docs");
    glob faiss_path: str = _rag.get("faiss_path", "services/faiss_index");

    glob llm = Model(model_name=_cfg.get("llm_model", "gpt-4.1-mini"));

    glob rag_engine: RagEngine = RagEngine(
        file_path=docs_path,
        faiss_path=faiss_path,
        chunk_size=_rag.get("chunk_size", 800),
        chunk_overlap=_rag.get("chunk_overlap", 100),
        chunk_nos=_rag.get("similarity_search_k", 30),
        top_n=_rag.get("reranking_top_n", 7),
        cross_encoder_model=_rag.get("reranking_model", "cross-encoder/ms-marco-MiniLM-L6-v2"),
        github_repo_url=_cfg.get("github_repo_url", ""),
        github_branch=_cfg.get("github_branch", "main")
    );

    """Search the ingested documentation index and return relevant passages."""
    def search_docs(query: str) -> str {
        return rag_engine.search(query=query);
    }

    """Stream SSE chunks to the client and persist the full response to the session."""
    def:pub stream_chunks(gen: str, session_id: str) -> str {
        full_response = "";
        for chunk in gen {
            full_response += chunk;
            yield f"data: {json.dumps({'type': 'chunk', 'content': chunk})}\n\n";
        }
        all_sessions = [root-->(?:Session)];
        for s in all_sessions {
            if s.id == session_id {
                s.chat_history.append({"role": "assistant", "content": full_response});
                s.updated_at = datetime.now().isoformat();
                break;
            }
        }
    }

    """Persistent chat session - stores history and owns the four agent nodes."""
    node Session {
        has id: str;
        has chat_history: list[dict] = [];
        has created_at: str = "";
        has updated_at: str = "";

        def synthesize(message: str, context: str, chat_history: list[dict]) -> str by llm(
            messages=chat_history,
            stream=True
        );

        can setup   with interact entry;
        can respond with interact exit;
    }

    sem Session.synthesize = "Final response synthesizer that answers using aggregated documentation context from all agents.";

    node RagAgent {
        def get_relevant_context(message: str) -> str by llm(tools=[search_docs]);
        can retrieve with interact entry;
    }

    node CodingAgent {
        def write_code(message: str) -> str by llm(tools=[search_docs]);
        can retrieve with interact entry;
    }

    node DebuggerAgent {
        def find_debugging_tips(message: str) -> str by llm(tools=[search_docs]);
        can retrieve with interact entry;
    }

    node GreetingAgent {
        can retrieve with interact entry;
    }

    walker interact {
        has message: str;
        has session_id: str;
        has user_email: str = "";
        has chat_history: list[dict] = [];
        has gathered_context: list[str] = [];

        """Find the matching Session node or create a new one, then visit it."""
        can init_session with Root entry {
            print(f"Attempting to initialize session {self.session_id}");
            found = [-->(?:Session, id == self.session_id)];
            if found {
                visit found;
            } else {
                now = datetime.now().isoformat();
                visit here ++> Session(
                    id=self.session_id,
                    chat_history=[],
                    created_at=now,
                    updated_at=now
                );
            }
        }
    }

    """Create a new Session node and return its ID."""
    walker new_session {
        has session_id: str = "";

        can create_session with Root entry {
            if not self.session_id {
                import time;
                self.session_id = f"session_{int(time.time())}";
            }
            now = datetime.now().isoformat();
            here ++> Session(id=self.session_id, chat_history=[], created_at=now, updated_at=now);
            report {"session_id": self.session_id, "status": "created", "chat_history": []};
        }
    }

    """Return all sessions for the current user with a first-message preview."""
    walker list_sessions {
        can get_all with Root entry {
            sessions = [];
            for s in [-->(?:Session)] {
                first_msg = "";
                for item in s.chat_history {
                    if item["role"] == "user" { first_msg = item["content"]; break; }
                }
                sessions.append({"id": s.id, "first_message": first_msg, "created_at": s.created_at, "updated_at": s.updated_at});
            }
            report {"sessions": sessions};
        }
    }

    """Return the chat history for a given session ID."""
    walker get_session {
        has session_id: str;

        can get_history with Root entry {
            for s in [-->(?:Session)] {
                if s.id == self.session_id {
                    report {"session_id": s.id, "chat_history": s.chat_history, "found": True};
                    return;
                }
            }
            report {"session_id": self.session_id, "chat_history": [], "found": False};
        }
    }

    """Disconnect and delete a Session node for the current user."""
    walker delete_session {
        has session_id: str;

        can remove with Root entry {
            matches = [-->(?:Session, id == self.session_id)];
            if matches {
                here del--> matches[0];
                del matches[0];
                report {"deleted": True, "session_id": self.session_id};
            } else {
                report {"deleted": False, "session_id": self.session_id};
            }
        }
    }

    """Return up to 3 relevant documentation sections for the current message."""
    walker :pub suggest_docs {
        has message: str;
        has chat_history: list[dict] = [];

        can get_suggestions with Root entry {
            if rag_engine.vectorstore is None {
                report {"success": False, "suggestions": [], "total": 0};
                return;
            }

            try {
                results = rag_engine.vectorstore.similarity_search_with_score(self.message, k=10);
                docs_site_url   = _cfg.get("docs_site_url", "").rstrip("/");
                github_repo_url = _cfg.get("github_repo_url", "").rstrip("/");
                github_branch   = _cfg.get("github_branch", "main");

                # Directory where the GitHub repo was cloned (if used)
                github_clone_dir = os.path.join(docs_path, "github_repo");

                seen_sources = {};
                suggestions = [];
                for (doc, score) in results {
                    source = doc.metadata.get("source", "");
                    if source and source not in seen_sources {
                        seen_sources[source] = True;

                        if docs_site_url {
                            # Explicit docs site configured - build a clean slug URL
                            rel = os.path.relpath(source, docs_path);
                            rel_no_ext = os.path.splitext(rel)[0];
                            url = docs_site_url + "/" + rel_no_ext.replace("\\", "/");
                        } elif github_repo_url and os.path.isabs(source) and source.startswith(os.path.abspath(github_clone_dir)) {
                            # File was cloned from a GitHub repo - build a blob URL
                            rel = os.path.relpath(source, github_clone_dir);
                            url = github_repo_url + "/blob/" + github_branch + "/" + rel.replace("\\", "/");
                        } elif github_repo_url and "github_repo" in source {
                            # Relative path variant - still points inside the clone dir
                            parts = source.split("github_repo" + os.sep, 1);
                            rel = parts[1] if len(parts) > 1 else source;
                            url = github_repo_url + "/blob/" + github_branch + "/" + rel.replace("\\", "/");
                        } elif github_repo_url {
                            # No explicit docs site but a repo is configured - link to repo root
                            rel = os.path.relpath(source, docs_path);
                            url = github_repo_url + "/blob/" + github_branch + "/" + rel.replace("\\", "/");
                        } else {
                            url = source;
                        }

                        basename = os.path.splitext(os.path.basename(source))[0];
                        title = basename.replace("-", " ").replace("_", " ").title();
                        suggestions.append({"url": url, "title": title, "reason": ""});
                        if len(suggestions) >= 3 { break; }
                    }
                }
                report {"success": True, "suggestions": suggestions, "total": len(suggestions)};
            } except Exception as e {
                print(f"suggest_docs error: {e}");
                report {"success": False, "suggestions": [], "total": 0, "error": str(e)};
            }
        }
    }
    ```

??? note "Complete `services/server.impl/session.impl.jac`"

    ```jac
    """Ability implementations for the Session node.

    setup  (entry) - appends the user message, lazily creates agent children,
                     then fans out via `visit [-->] by llm()`.
    respond (exit) - joins gathered_context from all visited agents, calls
                     Session.synthesize once, and streams SSE chunks back.
    """

    impl Session.setup {
        print(f"Session {self.id} received message: {visitor.message}");
        self.chat_history.append({"role": "user", "content": visitor.message});
        self.updated_at = datetime.now().isoformat();
        visitor.chat_history = self.chat_history;

        if not [-->](?:RagAgent) {
            self ++> RagAgent();
            self ++> CodingAgent();
            self ++> DebuggerAgent();
            self ++> GreetingAgent();
        }

        visit [-->] by llm(incl_info={"context": visitor.message});
    }

    impl Session.respond {
        context = "\n\n---\n\n".join(visitor.gathered_context);
        report stream_chunks(
            self.synthesize(
                message=visitor.message,
                context=context,
                chat_history=visitor.chat_history
            ),
            visitor.session_id
        );
    }
    ```

??? note "Complete `services/server.impl/agents.impl.jac`"

    ```jac
    """Ability implementations for the agent retrieval nodes.

    Each `retrieve` ability is triggered when the interact walker visits that agent
    node. The agent calls its specialised LLM method (which uses search_docs as a
    tool) and appends the result to visitor.gathered_context for Session.respond
    to aggregate.

    GreetingAgent has no retrieval - greetings need no doc context.
    """

    impl RagAgent.retrieve {
        print("RagAgent retrieving context");
        result = self.get_relevant_context(visitor.message);
        visitor.gathered_context.append(result);
    }

    impl CodingAgent.retrieve {
        print("CodingAgent retrieving context");
        result = self.write_code(f"code examples and implementation for: {visitor.message}");
        visitor.gathered_context.append(result);
    }

    impl DebuggerAgent.retrieve {
        print("DebuggerAgent retrieving context");
        result = self.find_debugging_tips(f"debugging, errors, and troubleshooting for: {visitor.message}");
        visitor.gathered_context.append(result);
    }

    impl GreetingAgent.retrieve {
        # No doc retrieval needed for greetings and chitchat.
    }
    ```

---

## What You Learned

**Backend:**

- **`can setup with interact entry` / `can respond with interact exit`** - entry and exit abilities on the same node bracket the entire subgraph traversal; `setup` fires before agents, `respond` fires after
- **`visit [-->] by llm(incl_info={...})`** - LLM-guided fan-out; the model selects which child nodes to visit from the list passed via `[-->]`; `incl_info` provides extra context for the routing decision
- **`has gathered_context: list[str] = []`** - accumulator pattern; each visited agent appends to the walker's list, building up context as the traversal proceeds
- **`if not [-->](?:RagAgent)`** - lazy node creation check; agents are created once per session, not per request
- **`server.impl/` directory** - ability bodies can live in separate `.impl.jac` files for cleaner organisation; `impl NodeName.ability { ... }` is the syntax
- **Three-LLM-call pipeline** - routing → per-agent retrieval → synthesis; each call has a clear, bounded role

**Frontend:** No changes - the multi-agent backend is a drop-in replacement for `DocChat`. All streaming, sessions, and the documentation panel work identically.

---

## Series Complete

You've built a full agentic RAG chatbot in four incremental steps:

| Step | What you added |
|------|----------------|
| [Part 1](part1-simple-chat.md) | Streaming LLM chat - one node, one walker |
| [Part 2](part2-persistent-sessions.md) | Persistent sessions, auth, Markdown UI |
| [Part 3](part3-rag-docs.md) | FAISS vector store, ReAct tool use, doc suggestions panel |
| **Part 4** | LLM-guided multi-agent routing, specialist retrievers, entry/exit abilities |

To take this further: add more specialist agents, tune the FAISS index, or extend `Session.synthesize` with citations drawn from `gathered_context`.
