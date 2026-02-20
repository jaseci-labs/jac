# Part 3: RAG & Document Ingestion

Your chatbot remembers conversations, but it can only answer questions the LLM was trained on. This step adds a **FAISS vector store** so the bot can retrieve passages from your own documentation - and surfaces relevant links in a sidebar panel.

**Prerequisites:** Complete [Part 2](part2-persistent-sessions.md) first.

---

## What Changes in Step 3

| Layer | What's new |
|-------|------------|
| Backend | `RagEngine` (FAISS + CrossEncoder); `search_docs` tool; `DocChat` node with `method="ReAct"`; `suggest_docs` walker |
| Frontend | `DocumentationPanel` component; `showDocs` state in `ChatPage`; `docSuggestions` in `useChat`; `getSuggestions` in `jacService` |

Everything from Step 2 (sessions, auth, sidebar) carries over unchanged.

**Project layout:**

```
step-3-doc-ingestion/
├── services/
│   ├── server.jac               # Updated: DocChat + search_docs + suggest_docs
│   ├── server.impl/
│   │   └── docchat.impl.jac     # Session.chat + DocChat.reply bodies
│   ├── rag_engine.py            # RagEngine (FAISS + CrossEncoder reranker)
│   ├── docs/                    # Put your .md / .txt / .rst docs here
│   └── faiss_index/             # Auto-generated on first run
├── hooks/
│   ├── useAuth.cl.jac           # Unchanged
│   └── useChat.cl.jac           # Updated: docSuggestions + getSuggestions call
├── services/
│   └── jacService.cl.jac        # Updated: getSuggestions()
├── components/
│   ├── DocumentationPanel.cl.jac  # NEW
│   ├── Sidebar.cl.jac           # Unchanged
│   ├── ChatMessage.cl.jac       # Unchanged
│   └── ChatInput.cl.jac         # Unchanged
└── pages/
    └── ChatPage.cl.jac          # Updated: showDocs + docsPanel
```

---

## Backend

### RAG Configuration (`jac.toml`)

The new `[config.rag]` block controls all RAG parameters - no code changes needed to tune the index:

```toml
[config]
llm_model         = "gpt-4.1-mini"
github_repo_url   = ""           # optional: clone + index a GitHub repo
github_branch     = "main"
docs_site_url     = ""           # optional: map file paths → hosted URLs

[config.rag]
docs_path            = "services/docs"
faiss_path           = "services/faiss_index"
chunk_size           = 800
chunk_overlap        = 100
similarity_search_k  = 30
reranking_top_n      = 7
reranking_model      = "cross-encoder/ms-marco-MiniLM-L6-v2"
```

### RagEngine + `search_docs` Tool

```jac
import from services.rag_engine { RagEngine }

glob _cfg: dict = _load_project_config();
glob _rag: dict = _cfg.get("rag", {});

glob docs_path: str  = _rag.get("docs_path", "services/docs");
glob faiss_path: str = _rag.get("faiss_path", "services/faiss_index");

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
```

**`RagEngine`** - on first startup, loads all `.md`/`.txt`/`.rst` files from `docs_path`, splits them into chunks, embeds them with OpenAI, builds a FAISS index, and saves it to `faiss_path`. Subsequent starts load the saved index directly (fast).

**`search_docs`** - a plain Python function that wraps `rag_engine.search()`. Declaring it at module level makes it visible to byLLM's tool-calling system.

### DocChat Node - ReAct with Tools

```jac
"""RAG-enabled chat node."""
node DocChat {
    def respond(message: str, chat_history: list[dict]) -> str by llm(
        method="ReAct",
        messages=chat_history,
        stream=True,
        tools=[search_docs]
    );
    can reply with interact entry;
}

sem DocChat.respond = "Agent for answering questions using retrieved document context.";
```

**`method="ReAct"`** - Reasoning + Acting. The LLM emits a scratchpad of Thought / Action / Observation cycles. When it decides it needs information, it calls `search_docs`; the result is fed back as an Observation; it repeats until it can produce a final Answer.

**`tools=[search_docs]`** - byLLM registers `search_docs` as an available tool. The LLM can call it zero or more times per request - general questions bypass retrieval entirely.

### Updated `Session.chat` and `DocChat.reply` (`server.impl/docchat.impl.jac`)

Ability bodies live in `server.impl/docchat.impl.jac`. `Session.chat` now delegates to `DocChat` instead of the old `Chat` node:

```jac
impl Session.chat {
    self.chat_history.append({"role": "user", "content": visitor.message});
    self.updated_at = datetime.now().isoformat();
    visitor.chat_history = self.chat_history;

    visit [-->](?:DocChat) else {
        visit root ++> DocChat();
    }
}

impl DocChat.reply {
    report stream_chunks(
        self.respond(message=visitor.message, chat_history=visitor.chat_history),
        visitor.session_id
    );
}
```

**`visit [-->](?:DocChat) else { ... }`** - visit the first connected `DocChat` node if one exists; otherwise execute the `else` block (create and visit a new one). This is the Jac "visit or create" pattern - more concise than the explicit `if/else` used in Step 2.

### `suggest_docs` Walker

After each bot response, the frontend calls this walker to populate the `DocumentationPanel`:

```jac
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
            results = rag_engine.vectorstore.similarity_search_with_score(
                self.message, k=10
            );
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

**`walker :pub`** - marks this as a public endpoint so the frontend can call it without authentication.

**`similarity_search_with_score`** - queries the FAISS vector store directly for the top 10 semantically similar chunks. The results are deduplicated by source file (so you get at most one suggestion per document), truncated to 3, and mapped to URLs.

**URL resolution priority** - the walker builds suggestion URLs using a three-level fallback:

1. **`docs_site_url` is set** → strips the `docs_path` prefix, removes the file extension, and appends to the site URL (e.g. `services/docs/api/auth.md` → `https://docs.mysite.com/api/auth`).
2. **`docs_site_url` is empty, `github_repo_url` is set** → builds a GitHub `blob/` URL pointing directly to the source file in the repo (e.g. `https://github.com/org/repo/blob/main/docs/api/auth.md`). Files cloned into `services/docs/github_repo/` have their clone-dir prefix stripped so the path matches the repo root.
3. **Neither is set** → falls back to the raw local file path.

---

## Frontend

### Updated `services/jacService.cl.jac` - Add `getSuggestions`

Everything from Step 2 is unchanged. Add one new function:

```jac
"""Get documentation suggestions for the given message using semantic search."""
async def:pub getSuggestions(message: str, chatHistory: list = []) -> any {
    try {
        response = root spawn suggest_docs(message=message, chat_history=chatHistory);
        result = response.reports[response.reports.length - 1] if response.reports and response.reports.length > 0 else {};
        return {
            "success": result.success or False,
            "suggestions": result.suggestions or [],
            "total": result.total or 0
        };
    } except Exception as e {
        console.error("getSuggestions error:", e);
        return {"success": False, "suggestions": [], "total": 0};
    }
}
```

**`root spawn suggest_docs(...)`** - calls the backend walker. Unlike `interact`, `suggest_docs` is marked `:pub` so it works without a JWT token.

### Updated `hooks/useChat.cl.jac` - Add `docSuggestions`

Two changes from Step 2: a new `docSuggestions` state variable, and a fire-and-forget call after each successful response:

```jac
import from ..services.jacService { ..., getSuggestions }

def:pub useChat() -> any {
    ...
    has docSuggestions: list = [];   # NEW

    ...

    async def handleSendMessage(content: str) -> None {
        ...
        result = await sendMessage(...);

        if result.success {
            # Fire-and-forget - no await; reactive state update when it resolves
            getSuggestions(content.trim(), []).then(lambda res: any -> None {
                if res.success and res.suggestions.length > 0 {
                    docSuggestions = res.suggestions;
                }
            });
        }
        ...
    }

    async def handleNewChat() -> None {
        messages = [];
        docSuggestions = [];   # clear on new chat
        initSession();
    }

    ...

    return {
        ...,
        "docSuggestions": docSuggestions   # exposed to ChatPage
    };
}
```

**`.then(lambda res -> ...)`** - `getSuggestions` is async. Calling `.then()` on the promise lets it complete in the background without blocking the UI update for the bot response.

**`docSuggestions = res.suggestions`** - assigning a `has` variable inside a promise callback still triggers a reactive re-render. The `DocumentationPanel` updates automatically once the suggestions arrive.

### NEW: `components/DocumentationPanel.cl.jac`

```jac
def isEmbeddable(url: str) -> bool {
    noEmbedDomains = ["github.com", "github.io", "google.com", "twitter.com",
                      "x.com", "linkedin.com", "youtube.com", "notion.so"];
    try {
        urlObj = Reflect.construct(URL, [url]);
        hostname = urlObj.hostname;
        for domain in noEmbedDomains {
            if hostname == domain or hostname.endsWith("." + domain) { return False; }
        }
        return True;
    } except Exception { return False; }
}

def:pub DocumentationPanel(
    suggestions: list = [],
    isVisible: bool = True,
    onToggle: any = None
) -> JsxElement | None {
    has viewerUrl: str = "";
    has viewerTitle: str = "";

    if not isVisible { return None; }

    # Clicking a card embeds it in an iframe if the domain allows framing,
    # otherwise opens it in a new tab.
    suggestionCards = suggestions.map(lambda suggestion: any, index: int -> any {
        embeddable = isEmbeddable(suggestion.url);
        return <div key={index}
            onClick={lambda -> None {
                if embeddable { viewerUrl = suggestion.url; viewerTitle = suggestion.title; }
                else { window.open(suggestion.url, "_blank"); }
            }}
            style={{"padding": "14px", "border": "1px solid #374151", "borderRadius": "10px", "cursor": "pointer"}}
        >
            <span style={{"fontSize": "14px", "fontWeight": "600"}}>{suggestion.title}</span>
            <p style={{"fontSize": "11px", "color": "#60a5fa", "fontFamily": "monospace", "margin": "4px 0 0"}}>{suggestion.url}</p>
        </div>;
    });

    viewerSection = (
        <div style={{"display": "flex", "flexDirection": "column", "flex": "1", "minHeight": "0"}}>
            <div style={{"padding": "10px 16px", "borderBottom": "1px solid #374151", "display": "flex", "gap": "8px"}}>
                <button onClick={lambda -> None { viewerUrl = ""; viewerTitle = ""; }}
                    style={{"padding": "6px 12px", "border": "1px solid #374151", "borderRadius": "9999px", "background": "transparent", "color": "#9ca3af", "cursor": "pointer"}}>
                    Back
                </button>
                <button onClick={lambda -> None { window.open(viewerUrl, "_blank"); }}
                    style={{"padding": "6px 12px", "border": "1px solid rgba(59,130,246,0.25)", "borderRadius": "9999px", "background": "rgba(59,130,246,0.08)", "color": "#60a5fa", "cursor": "pointer"}}>
                    Open
                </button>
            </div>
            <div style={{"flex": "1", "minHeight": "0", "overflow": "hidden"}}>
                <iframe src={viewerUrl} title={viewerTitle}
                    sandbox="allow-scripts allow-same-origin allow-popups allow-forms"
                    style={{"width": "100%", "height": "100%", "border": "none", "background": "#fff"}} />
            </div>
        </div>
        if viewerUrl else None
    );

    listSection = (
        <div style={{"flex": "1", "padding": "16px", "overflowY": "auto"}}>
            {(
                <p style={{"color": "#9ca3af", "fontSize": "13px", "textAlign": "center"}}>Send a message to see relevant documentation here.</p>
                if suggestions.length == 0 else None
            )}
            <div style={{"display": "flex", "flexDirection": "column", "gap": "10px"}}>{suggestionCards}</div>
        </div>
        if not viewerUrl else None
    );

    return <div style={{"display": "flex", "flexDirection": "column", "height": "100%", "background": "#141414"}}>
        <div style={{"padding": "14px 16px", "borderBottom": "1px solid #374151", "display": "flex", "alignItems": "center", "justifyContent": "space-between"}}>
            <span style={{"fontSize": "15px", "fontWeight": "600"}}>Documentation</span>
            <button onClick={onToggle} style={{"border": "none", "background": "transparent", "cursor": "pointer", "color": "#9ca3af"}}>✕</button>
        </div>
        {viewerSection}
        {listSection}
    </div>;
}
```

**`isEmbeddable(url)`** - domains like GitHub and Google send `X-Frame-Options: DENY`, so trying to embed them in an `<iframe>` silently fails. This helper detects known non-embeddable domains and opens those URLs in a new tab instead.

**`viewerUrl` / `viewerTitle`** - component-local `has` state that controls which view is shown (suggestion list vs. iframe). Clearing `viewerUrl` returns to the list.

**`sandbox` attribute** - restricts what the embedded iframe can do: allows scripts and same-origin access (needed for navigation), popups, and forms, but blocks dangerous capabilities like top-level navigation.

### Updated `pages/ChatPage.cl.jac` - Add Docs Panel

Two additions to the Step 2 `ChatPage`:

```jac
import from ..components.DocumentationPanel { DocumentationPanel }

def:pub ChatPage() -> JsxElement {
    chat = useChat();
    has showDocs: bool = False;   # NEW

    docsToggleBtn = <button
        onClick={lambda -> None { showDocs = not showDocs; }}
        style={{
            "border": ("1px solid #3b82f6" if showDocs else "1px solid #374151"),
            "background": ("rgba(59,130,246,0.12)" if showDocs else "transparent"),
            "color": ("#3b82f6" if showDocs else "#9ca3af"),
            "borderRadius": "8px", "padding": "6px 12px", "cursor": "pointer",
            "fontSize": "13px", "fontWeight": "500"
        }}
    >
        Docs
    </button>;

    chatArea = <div style={{"flex": "1", "display": "flex", "flexDirection": "column", "minWidth": "0", "borderRight": ("1px solid #374151" if showDocs else "none")}}>
        <div style={{"padding": "14px 20px", "borderBottom": "1px solid #374151", "display": "flex", "alignItems": "center", "justifyContent": "space-between"}}>
            <span style={{"fontSize": "16px", "fontWeight": "600"}}>DocBot</span>
            {docsToggleBtn}
        </div>
        ...
    </div>;

    docsPanel = (
        <div style={{"width": "380px", "flexShrink": "0", "display": "flex", "flexDirection": "column"}}>
            <DocumentationPanel
                suggestions={chat.docSuggestions}
                isVisible={showDocs}
                onToggle={lambda -> None { showDocs = False; }}
            />
        </div>
        if showDocs else None
    );

    return <div style={{"display": "flex", "height": "100vh", ...}}>
        <Sidebar ... />
        <div style={{"width": "260px", "flexShrink": "0"}} />
        {chatArea}
        {docsPanel}
    </div>;
}
```

**`showDocs` toggle** - the "Docs" button in the header flips `showDocs`. When `True`, `docsPanel` renders at 380 px wide on the right; the chat area shrinks to fill the remaining space. The border on the chat area is only added when the panel is open, so there's no orphan line when it's hidden.

---

## Run It

??? note "Complete `jac.toml`"

    ```toml
    [project]
    name = "step-3-doc-ingestion"
    version = "1.0.0"
    description = "Tutorial Step 3: Adds FAISS RAG and DocumentationPanel"
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
    # These settings replace the old services/config/faiss_reranking.json.
    [config.rag]
    docs_path            = "services/docs"        # Directory containing .md / .pdf files to index
    faiss_path           = "services/faiss_index" # Where the FAISS index is persisted
    chunk_size           = 800
    chunk_overlap        = 100
    similarity_search_k  = 30   # Number of candidates retrieved from FAISS before reranking
    reranking_top_n      = 7    # Final results returned after CrossEncoder reranking
    reranking_model      = "cross-encoder/ms-marco-MiniLM-L6-v2"

    [plugins]
    [plugins.client]
    ```

```bash
cd step-3-doc-ingestion
cp .env.example .env   # add your OPENAI_API_KEY
jac install            # install Python + npm dependencies (includes FAISS and sentence-transformers)
```

Put your documentation files (`.md`, `.txt`, `.rst`) inside `services/docs/`, then:

```bash
jac start              # start the server (first run builds the FAISS index)
```

The first run builds the FAISS index - this takes a few seconds depending on how many docs you have. Subsequent starts load from disk.

!!! tip "Resetting the environment"
    `jac clean` removes data files (e.g. the persisted graph and FAISS index). `jac clean --all` removes compiled files and data too - run `jac install` again afterwards to reinstall dependencies.

Open `http://localhost:8000`, click the **Docs** button in the header, and ask a question about your documentation. The panel will populate with relevant links after each response.

!!! tip "GitHub repo ingestion"
    Set `github_repo_url` in `jac.toml [config]` to automatically clone and index a public repo on first startup. The repo's Markdown and text files are included in the same FAISS index as your local docs.

!!! warning "Index out of date?"
    Delete the `services/faiss_index/` directory and restart - the engine will rebuild from scratch.

??? note "Complete `services/server.jac`"

    ```jac
    """Step 3: Chat backend with document ingestion and RAG."""

    import os;
    import json;
    import tomllib;
    import from byllm.lib { Model }
    import from dotenv { load_dotenv }
    import from datetime { datetime }
    import from services.rag_engine { RagEngine }

    with entry {
        load_dotenv();
    }

    def _load_project_config() -> dict {
        try {
            toml_path = os.path.join(os.path.dirname(__file__), "..", "jac.toml");
            with open(toml_path, "rb") as f {
                return tomllib.load(f).get("config", {});
            }
        } except Exception as e {
            print(f"Warning: could not load jac.toml config: {e}");
            return {};
        }
    }

    glob _cfg: dict = _load_project_config();
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

    """Persistent chat session - stores the full conversation history."""
    node Session {
        has id: str;
        has chat_history: list[dict] = [];
        has created_at: str = "";
        has updated_at: str = "";

        can chat with interact entry;
    }

    """RAG-enabled chat node - LLM calls search_docs when it needs doc context."""
    node DocChat {
        def respond(message: str, chat_history: list[dict]) -> str by llm(
            method="ReAct",
            messages=chat_history,
            stream=True,
            tools=[search_docs]
        );
        can reply with interact entry;
    }

    sem DocChat.respond = "Agent for answering questions using retrieved document context.";

    def:pub stream_chunks(gen: any, session_id: str) -> any {
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

    """Main chat walker: resolves the session, then delegates to the DocChat node."""
    walker interact {
        has message: str;
        has session_id: str;
        has chat_history: list[dict] = [];

        can init_session with Root entry {
            all_sessions = [-->(?:Session)];
            found = None;
            for s in all_sessions {
                if s.id == self.session_id { found = s; break; }
            }
            if found {
                visit found;
            } else {
                now = datetime.now().isoformat();
                visit here ++> Session(id=self.session_id, chat_history=[], created_at=now, updated_at=now);
            }
        }
    }

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

??? note "Complete `services/server.impl/docchat.impl.jac`"

    ```jac
    """Ability implementations for Session and DocChat nodes."""

    impl Session.chat {
        self.chat_history.append({"role": "user", "content": visitor.message});
        self.updated_at = datetime.now().isoformat();
        visitor.chat_history = self.chat_history;

        # Find or create the shared DocChat node (persisted under root)
        visit [-->](?:DocChat) else {
            visit root ++> DocChat();
        }
    }

    impl DocChat.reply {
        report stream_chunks(
            self.respond(message=visitor.message, chat_history=visitor.chat_history),
            visitor.session_id
        );
    }
    ```

??? note "Complete `services/jacService.cl.jac`"

    ```jac
    """Step 3: Client-side service layer - inherits Step 2 plus getSuggestions()."""

    def:pub generateSessionId() -> str {
        return "session_" + String(Date.now()) + "_" + Math.random().toString(36).substring(2, 9);
    }

    async def:pub createSession(sessionId: str = "") -> any {
        if not sessionId { sessionId = generateSessionId(); }
        try {
            response = root spawn new_session(session_id=sessionId);
            result = response.reports[response.reports.length - 1] if response.reports and response.reports.length > 0 else {};
            return {"success": True, "session_id": result.session_id or sessionId, "chat_history": result.chat_history or []};
        } except Exception as e { return {"success": False, "error": String(e), "session_id": sessionId}; }
    }

    async def:pub getSession(sessionId: str) -> any {
        try {
            response = root spawn get_session(session_id=sessionId);
            result = response.reports[response.reports.length - 1] if response.reports and response.reports.length > 0 else {};
            return {"success": True, "session_id": sessionId, "chat_history": result.chat_history or [], "found": result.found or False};
        } except Exception as e { return {"success": False, "error": String(e), "chat_history": [], "found": False}; }
    }

    async def:pub listSessions() -> any {
        try {
            response = root spawn list_sessions();
            result = response.reports[response.reports.length - 1] if response.reports and response.reports.length > 0 else {};
            return {"success": True, "sessions": result.sessions or []};
        } except Exception as e { return {"success": False, "error": String(e), "sessions": []}; }
    }

    async def:pub deleteSession(sessionId: str) -> any {
        try {
            response = root spawn delete_session(session_id=sessionId);
            result = response.reports[response.reports.length - 1] if response.reports and response.reports.length > 0 else {};
            return {"success": True, "deleted": result.deleted or False};
        } except Exception as e { return {"success": False, "error": String(e), "deleted": False}; }
    }

    """Get documentation suggestions using semantic search."""
    async def:pub getSuggestions(message: str, chatHistory: list = []) -> any {
        try {
            response = root spawn suggest_docs(message=message, chat_history=chatHistory);
            result = response.reports[response.reports.length - 1] if response.reports and response.reports.length > 0 else {};
            return {"success": result.success or False, "suggestions": result.suggestions or [], "total": result.total or 0};
        } except Exception as e {
            console.error("getSuggestions error:", e);
            return {"success": False, "suggestions": [], "total": 0};
        }
    }

    """Send a message and stream the response back via SSE."""
    async def:pub sendMessage(
        message: str, sessionId: str, userEmail: str = "",
        onChunk: any = None, abortSignal: any = None
    ) -> any {
        try {
            token = localStorage.getItem("jac_token");
            response = await fetch("/walker/interact", {
                "method": "POST",
                "headers": {"Content-Type": "application/json", "Authorization": ("Bearer " + token if token else "")},
                "body": JSON.stringify({"message": message, "session_id": sessionId, "user_email": userEmail}),
                "signal": abortSignal
            });
            reader = response.body.getReader();
            decoder = Reflect.construct(TextDecoder, ["utf-8"]);
            buffer = "";
            doubleNewline = String.fromCharCode(10) + String.fromCharCode(10);
            while True {
                read_result = await reader.read();
                if read_result.done { break; }
                buffer += decoder.decode(read_result.value, {"stream": True});
                events = buffer.split(doubleNewline);
                buffer = events.pop() or "";
                for event in events {
                    if not event.startsWith("data:") { continue; }
                    try {
                        parsed = JSON.parse(event.replace("data:", "").trim());
                        if parsed.type == "chunk" and onChunk { onChunk(parsed.content); }
                    } except Exception { }
                }
            }
            return {"success": True};
        } except Exception as e {
            if e.name == "AbortError" { return {"success": False, "aborted": True}; }
            return {"success": False, "error": String(e)};
        }
    }
    ```

??? note "Complete `hooks/useChat.cl.jac`"

    ```jac
    """Step 3: useChat - adds docSuggestions state and getSuggestions() call."""

    import from react { useRef, useEffect }
    import from "@jac/runtime" { jacIsLoggedIn }
    import from ..services.jacService { getSession, listSessions, deleteSession, sendMessage, generateSessionId, getSuggestions }
    import from ..hooks.useAuth { getUsernameFromToken }

    def:pub useChat() -> any {
        has messages: list = [];
        has sessionId: str = "";
        has isLoading: bool = False;
        has chatSessions: list = [];
        has docSuggestions: list = [];

        messagesEndRef = useRef(None);
        abortControllerRef = useRef(None);
        prevMessageCountRef = useRef(0);
        isAuthenticated = jacIsLoggedIn();

        useEffect(lambda -> None {
            currentCount = messages.length;
            if currentCount > prevMessageCountRef.current {
                if messagesEndRef.current {
                    messagesEndRef.current.scrollIntoView({"behavior": "smooth"});
                }
            }
            prevMessageCountRef.current = currentCount;
        }, [messages]);

        useEffect(lambda -> None {
            async def loadSessions() -> None {
                result = await listSessions();
                if result.success {
                    chatSessions = result.sessions.map(lambda s: any -> any {
                        title = (s.first_message.substring(0, 50) + ("..." if s.first_message.length > 50 else "")) if s.first_message else "New Chat";
                        return {"id": s.id, "title": title, "createdAt": s.created_at};
                    });
                }
            }
            loadSessions();
            initSession();
        }, []);

        def initSession() -> None {
            sessionId = generateSessionId();
        }

        async def handleSendMessage(content: str) -> None {
            if not content.trim() or isLoading { return; }
            isFirstMessage = messages.filter(lambda m: any -> bool { return m.isUser; }).length == 0;
            isLoading = True;
            messages = lambda prev: any -> any {
                return prev.concat([{"id": "user_" + String(Date.now()), "content": content.trim(), "isUser": True, "timestamp": Date()}]);
            };
            if isFirstMessage { updateSessionTitle(content.trim()); }
            botId = "bot_" + String(Date.now());
            messages = lambda prev: any -> any {
                return prev.concat([{"id": botId, "content": "", "isUser": False, "timestamp": Date()}]);
            };
            def onChunk(chunk: str) -> None {
                isLoading = False;
                messages = lambda prev: any -> any {
                    return prev.map(lambda m: any -> any {
                        if m.id == botId { return {"id": m.id, "content": m.content + chunk, "isUser": False, "timestamp": m.timestamp}; }
                        return m;
                    });
                };
            }
            try {
                abortControllerRef.current = Reflect.construct(AbortController, []);
                userEmail = (getUsernameFromToken() if isAuthenticated else "");
                result = await sendMessage(content.trim(), sessionId, userEmail, onChunk, abortControllerRef.current.signal);
                if result.success {
                    getSuggestions(content.trim(), []).then(lambda res: any -> None {
                        if res.success and res.suggestions.length > 0 {
                            docSuggestions = res.suggestions;
                        }
                    });
                } else {
                    if result.aborted {
                        messages = lambda prev: any -> any { return prev.filter(lambda m: any -> bool { return m.id != botId; }); };
                    } else {
                        messages = lambda prev: any -> any {
                            return prev.map(lambda m: any -> any {
                                if m.id == botId { return {"id": m.id, "content": "Sorry, something went wrong.", "isUser": False, "timestamp": m.timestamp}; }
                                return m;
                            });
                        };
                    }
                }
                abortControllerRef.current = None;
            } except Exception as e {
                console.error("Send error:", e);
                isLoading = False;
            }
        }

        def updateSessionTitle(firstMessage: str) -> None {
            title = firstMessage.substring(0, 50) + (("..." if firstMessage.length > 50 else ""));
            idx = chatSessions.findIndex(lambda s: any -> bool { return s.id == sessionId; });
            if idx >= 0 {
                chatSessions = lambda prev: any -> any {
                    return prev.map(lambda s: any, i: int -> any {
                        return ({"id": s.id, "title": title, "createdAt": s.createdAt} if i == idx else s);
                    });
                };
            } else {
                newSession = {"id": sessionId, "title": title, "createdAt": String(Date.now())};
                chatSessions = lambda prev: any -> any { return [newSession].concat(prev); };
            }
        }

        async def handleNewChat() -> None {
            messages = [];
            docSuggestions = [];
            initSession();
        }

        async def handleLoadSession(loadId: str) -> None {
            isLoading = True;
            try {
                result = await getSession(loadId);
                if result.success and result.found {
                    sessionId = loadId;
                    newMessages = [];
                    lastUserMessage = "";
                    for item in result.chat_history {
                        newMessages.push({"id": "msg_" + String(Date.now()) + "_" + String(Math.random()), "content": item.content, "isUser": item.role == "user", "timestamp": Date()});
                        if item.role == "user" { lastUserMessage = item.content; }
                    }
                    messages = lambda prev: any -> any { return newMessages; };
                    docSuggestions = [];
                    if lastUserMessage {
                        getSuggestions(lastUserMessage, []).then(lambda res: any -> None {
                            if res.success and res.suggestions.length > 0 { docSuggestions = res.suggestions; }
                        });
                    }
                }
            } except Exception as e { console.error("Load session error:", e); }
            finally { isLoading = False; }
        }

        async def handleDeleteSession(deleteId: str) -> None {
            await deleteSession(deleteId);
            chatSessions = lambda prev: any -> any { return prev.filter(lambda s: any -> bool { return s.id != deleteId; }); };
            if deleteId == sessionId { handleNewChat(); }
        }

        def handleStopGeneration() -> None {
            if abortControllerRef.current {
                try { abortControllerRef.current.abort(); } except Exception { }
                abortControllerRef.current = None;
            }
            isLoading = False;
        }

        return {
            "messages": messages, "sessionId": sessionId,
            "isLoading": isLoading, "chatSessions": chatSessions,
            "docSuggestions": docSuggestions, "messagesEndRef": messagesEndRef,
            "handleSendMessage": handleSendMessage, "handleNewChat": handleNewChat,
            "handleLoadSession": handleLoadSession, "handleDeleteSession": handleDeleteSession,
            "handleStopGeneration": handleStopGeneration
        };
    }
    ```

??? note "Complete `components/DocumentationPanel.cl.jac`"

    ```jac
    """Step 3: DocumentationPanel - displays RAG-powered doc suggestions."""

    def isEmbeddable(url: str) -> bool {
        noEmbedDomains = [
            "github.com", "github.io", "google.com", "google.co",
            "twitter.com", "x.com", "linkedin.com", "facebook.com",
            "instagram.com", "reddit.com", "youtube.com", "notion.so"
        ];
        try {
            urlObj = Reflect.construct(URL, [url]);
            hostname = urlObj.hostname;
            for domain in noEmbedDomains {
                if hostname == domain or hostname.endsWith("." + domain) { return False; }
            }
            return True;
        } except Exception { return False; }
    }

    def:pub DocumentationPanel(
        suggestions: list = [],
        isVisible: bool = True,
        onToggle: any = None
    ) -> JsxElement | None {
        has viewerUrl: str = "";
        has viewerTitle: str = "";

        BG = "#141414"; BORDER = "#374151"; TEXT = "#ffffff"; MUTED = "#9ca3af"; ACCENT = "#3b82f6";

        if not isVisible { return None; }

        bookIcon = <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={ACCENT} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"></path>
            <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"></path>
        </svg>;

        arrowLeftIcon = <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <line x1="19" x2="5" y1="12" y2="12"></line>
            <polyline points="12 19 5 12 12 5"></polyline>
        </svg>;

        externalLinkIcon = <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"></path>
            <polyline points="15 3 21 3 21 9"></polyline>
            <line x1="10" x2="21" y1="14" y2="3"></line>
        </svg>;

        chevronRightIcon = <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={MUTED} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="m9 18 6-6-6-6"></path>
        </svg>;

        closeIcon = <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={MUTED} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <line x1="18" x2="6" y1="6" y2="18"></line>
            <line x1="6" x2="18" y1="6" y2="18"></line>
        </svg>;

        header = <div style={{"padding": "14px 16px", "borderBottom": "1px solid " + BORDER, "display": "flex", "alignItems": "center", "justifyContent": "space-between"}}>
            <div style={{"display": "flex", "alignItems": "center", "gap": "8px"}}>
                {bookIcon}
                <span style={{"fontSize": "15px", "fontWeight": "600", "color": TEXT}}>Documentation</span>
            </div>
            <button onClick={onToggle}
                style={{"display": "flex", "alignItems": "center", "justifyContent": "center", "width": "28px", "height": "28px", "border": "none", "borderRadius": "6px", "background": "transparent", "cursor": "pointer"}}
                onMouseEnter={lambda e: any -> None { e.currentTarget.style.background = "#374151"; }}
                onMouseLeave={lambda e: any -> None { e.currentTarget.style.background = "transparent"; }}
            >
                {closeIcon}
            </button>
        </div>;

        viewerSection = (
            <div style={{"display": "flex", "flexDirection": "column", "flex": "1", "minHeight": "0"}}>
                <div style={{"padding": "10px 16px", "borderBottom": "1px solid " + BORDER, "display": "flex", "alignItems": "center", "justifyContent": "space-between", "gap": "8px"}}>
                    <button onClick={lambda -> None { viewerUrl = ""; viewerTitle = ""; }}
                        style={{"display": "flex", "alignItems": "center", "gap": "6px", "padding": "6px 12px", "border": "1px solid " + BORDER, "borderRadius": "9999px", "background": "transparent", "color": MUTED, "cursor": "pointer", "fontSize": "13px"}}>
                        {arrowLeftIcon}{"Back"}
                    </button>
                    <button onClick={lambda -> None { window.open(viewerUrl, "_blank"); }}
                        style={{"display": "flex", "alignItems": "center", "gap": "6px", "padding": "6px 12px", "border": "1px solid rgba(59,130,246,0.25)", "borderRadius": "9999px", "background": "rgba(59,130,246,0.08)", "color": "#60a5fa", "cursor": "pointer", "fontSize": "13px"}}>
                        {externalLinkIcon}{"Open"}
                    </button>
                </div>
                <div style={{"flex": "1", "minHeight": "0", "overflow": "hidden"}}>
                    <iframe src={viewerUrl} title={viewerTitle}
                        sandbox="allow-scripts allow-same-origin allow-popups allow-forms"
                        style={{"width": "100%", "height": "100%", "border": "none", "display": "block", "background": "#fff"}} />
                </div>
            </div>
            if viewerUrl else None
        );

        emptyState = <div style={{"flex": "1", "display": "flex", "alignItems": "center", "justifyContent": "center"}}>
            <p style={{"color": MUTED, "fontSize": "13px", "textAlign": "center", "lineHeight": "1.6"}}>Send a message to see relevant documentation here.</p>
        </div>;

        suggestionCards = suggestions.map(lambda suggestion: any, index: int -> any {
            embeddable = isEmbeddable(suggestion.url);
            return <div key={index}
                onClick={lambda -> None {
                    if embeddable { viewerUrl = suggestion.url; viewerTitle = suggestion.title; }
                    else { window.open(suggestion.url, "_blank"); }
                }}
                style={{"padding": "14px", "background": "linear-gradient(to bottom right, #1e1e1e, #252525)", "border": "1px solid " + BORDER, "borderRadius": "10px", "cursor": "pointer", "transition": "border-color 0.2s"}}
                onMouseEnter={lambda e: any -> None { e.currentTarget.style.borderColor = "rgba(59,130,246,0.4)"; }}
                onMouseLeave={lambda e: any -> None { e.currentTarget.style.borderColor = BORDER; }}
            >
                <div style={{"display": "flex", "alignItems": "center", "justifyContent": "space-between", "marginBottom": "6px"}}>
                    <span style={{"fontSize": "14px", "fontWeight": "600", "color": TEXT}}>{suggestion.title}</span>
                    {(externalLinkIcon if not embeddable else chevronRightIcon)}
                </div>
                <p style={{"fontSize": "11px", "color": "#60a5fa", "fontFamily": "monospace", "margin": "0", "overflow": "hidden", "textOverflow": "ellipsis", "whiteSpace": "nowrap"}}>
                    {suggestion.url}
                </p>
            </div>;
        });

        listSection = (
            <div style={{"flex": "1", "padding": "16px", "overflowY": "auto"}}>
                <h3 style={{"fontSize": "13px", "fontWeight": "600", "color": MUTED, "textTransform": "uppercase", "letterSpacing": "0.06em", "marginBottom": "12px"}}>
                    {(("Relevant Docs" if suggestions.length > 0 else ""))}
                </h3>
                {(emptyState if suggestions.length == 0 else None)}
                <div style={{"display": "flex", "flexDirection": "column", "gap": "10px"}}>{suggestionCards}</div>
            </div>
            if not viewerUrl else None
        );

        return <div style={{"display": "flex", "flexDirection": "column", "height": "100%", "width": "100%", "background": BG}}>
            {header}
            {viewerSection}
            {listSection}
        </div>;
    }
    ```

??? note "Complete `pages/ChatPage.cl.jac`"

    ```jac
    """Step 3: ChatPage - adds a toggleable DocumentationPanel on the right."""

    import from react { useEffect }
    import from "@jac/runtime" { jacIsLoggedIn }
    import from ..hooks.useChat { useChat }
    import from ..components.ChatMessage { ChatMessage }
    import from ..components.ChatInput { ChatInput }
    import from ..components.Sidebar { Sidebar }
    import from ..components.DocumentationPanel { DocumentationPanel }

    def:pub ChatPage() -> JsxElement {
        chat = useChat();
        has showDocs: bool = False;

        BG = "#141414"; BORDER = "#374151"; TEXT = "#ffffff"; MUTED = "#9ca3af"; ACCENT = "#3b82f6";

        hasMessages = chat.messages.length > 0;

        bookIcon = <svg xmlns="http://www.w3.org/2000/svg" width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"></path>
            <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"></path>
        </svg>;

        welcomeScreen = <div style={{"flex": "1", "display": "flex", "flexDirection": "column", "alignItems": "center", "justifyContent": "center", "gap": "8px"}}>
            <p style={{"fontSize": "26px", "fontWeight": "600", "color": TEXT, "margin": "0"}}>How can I help you today?</p>
            <p style={{"fontSize": "14px", "margin": "0", "color": MUTED}}>
                {(("Your conversations are saved. Ask me anything and I'll search the docs." if jacIsLoggedIn() else "Sign in to save your chat history."))}
            </p>
        </div>;

        docsToggleBtn = <button
            onClick={lambda -> None { showDocs = not showDocs; }}
            style={{
                "display": "flex", "alignItems": "center", "gap": "6px",
                "padding": "6px 12px",
                "border": ("1px solid " + ACCENT if showDocs else "1px solid " + BORDER),
                "borderRadius": "8px",
                "background": ("rgba(59,130,246,0.12)" if showDocs else "transparent"),
                "color": (ACCENT if showDocs else MUTED),
                "cursor": "pointer", "fontSize": "13px", "fontWeight": "500", "transition": "all 0.2s"
            }}
        >
            {bookIcon}{"Docs"}
        </button>;

        chatArea = <div style={{"flex": "1", "display": "flex", "flexDirection": "column", "minWidth": "0", "borderRight": ("1px solid " + BORDER if showDocs else "none")}}>
            <div style={{"padding": "14px 20px", "borderBottom": "1px solid " + BORDER, "display": "flex", "alignItems": "center", "justifyContent": "space-between"}}>
                <span style={{"fontSize": "16px", "fontWeight": "600"}}>DocBot</span>
                {docsToggleBtn}
            </div>
            <div style={{"flex": "1", "overflowY": "auto", "padding": "16px", "display": "flex", "flexDirection": "column"}}>
                {(welcomeScreen if not hasMessages else None)}
                {chat.messages.map(lambda msg: any -> any {
                    return <ChatMessage key={msg.id} message={msg.content} isUser={msg.isUser} />;
                })}
                <div ref={chat.messagesEndRef} />
            </div>
            <ChatInput onSendMessage={chat.handleSendMessage} isLoading={chat.isLoading} onStop={chat.handleStopGeneration} />
        </div>;

        docsPanel = (
            <div style={{"width": "380px", "flexShrink": "0", "display": "flex", "flexDirection": "column"}}>
                <DocumentationPanel
                    suggestions={chat.docSuggestions}
                    isVisible={showDocs}
                    onToggle={lambda -> None { showDocs = False; }}
                />
            </div>
            if showDocs else None
        );

        return <div style={{"display": "flex", "height": "100vh", "background": BG, "color": TEXT, "fontFamily": "system-ui, -apple-system, sans-serif"}}>
            <Sidebar
                chatSessions={chat.chatSessions}
                currentSessionId={chat.sessionId}
                onNewChat={chat.handleNewChat}
                onLoadSession={chat.handleLoadSession}
                onDeleteSession={chat.handleDeleteSession}
            />
            <div style={{"width": "260px", "flexShrink": "0"}} />
            {chatArea}
            {docsPanel}
        </div>;
    }
    ```

---

## What You Learned

**Backend:**

- **`RagEngine`** - FAISS vector store with CrossEncoder reranking; builds on first run, loads from disk on restart
- **`method="ReAct"`** - Reasoning + Acting; LLM emits Thought/Action/Observation cycles and calls tools when it needs information
- **`tools=[search_docs]`** - byLLM tool registration; the LLM calls zero or more tools per request autonomously
- **`visit [-->](?:DocChat) else { ... }`** - "visit or create" pattern; more concise than the explicit `if/else` in Step 2
- **`walker :pub`** on `suggest_docs` - public endpoint, no auth required

**Frontend:**

- **`getSuggestions(...).then(lambda res -> ...)`** - fire-and-forget async call; reactive state updates when the promise resolves without blocking the UI
- **`isEmbeddable(url)`** - detect domains that block iframing and open them in a new tab instead
- **`showDocs` + conditional panel** - the 380 px panel is conditionally rendered; the chat area fills remaining flex space automatically

---

## Next Step

The `DocChat` node handles all query types through one LLM call. In [Part 4](part4-multi-agent.md) you'll replace it with four specialist agent nodes - `RagAgent`, `CodingAgent`, `DebuggerAgent`, and `GreetingAgent` - and let the LLM choose which agents to visit per request using `visit [-->] by llm()`.
