# Part 1: Simple Streaming Chat

Build a minimal LLM-powered chatbot in a single backend file plus a small `server.impl/` file, and a handful of frontend components. One node, one walker, one streaming response - no sessions, no history, no boilerplate.

**Prerequisites:** [Installation](../../quick-guide/install.md) complete, [Hello World](../../quick-guide/hello-world.md) done. An OpenAI API key in a `.env` file.

---

## What You're Building

A full-stack chat UI that streams LLM responses as SSE chunks. The backend is under 90 lines. The frontend is four small files.

```
Browser                     Server
  │── POST /walker/interact ──→ interact walker
  │                              └── visits Chat node
  │                                    └── Chat.respond() by llm(stream=True)
  │←── data: {"type":"chunk","content":"..."} ──┘
  │←── data: {"type":"chunk","content":"..."} ──┘
  │   ... streaming until complete
```

Because there is no authentication and no stable user root, `Chat` is stateless - a new one is created per request. That keeps this step focused on the core streaming pattern.

---

## Project Layout

```
step-1-simple-chat/
├── jac.toml                     # Config: model name, project settings
├── .env                         # OPENAI_API_KEY (copy from .env.example)
├── main.jac                     # Entry point: wires backend + frontend
├── frontend.cl.jac              # Client router
├── pages/
│   └── ChatPage.cl.jac          # Main chat UI with SSE streaming
├── components/
│   ├── ChatMessage.cl.jac       # User/bot message bubble
│   └── ChatInput.cl.jac         # Textarea + Send/Stop button
└── services/
    ├── server.jac               # Node + walker declarations
    └── server.impl/
        └── chat.impl.jac        # Chat.reply ability body
```

---

## Backend

### Configure the LLM

Settings live in `jac.toml` under `[config]`. `server.jac` reads them at startup:

```jac
import from byllm.lib { Model }
import from dotenv { load_dotenv }
import tomllib, os, json;

with entry {
    load_dotenv();   # reads OPENAI_API_KEY from .env
}

glob _cfg: dict = _load_project_config();
glob llm = Model(model_name=_cfg.get("llm_model", "gpt-4.1-mini"));
```

**`with entry`** runs once when the module loads.

**`glob llm`** declares a module-level variable shared by all LLM method calls.

### Streaming Helper

Jac's `report` streams values when given a generator. Because `yield` must be in a top-level function (not nested), we define it at module level:

```jac
def stream_chunks(gen: any) -> any {
    for chunk in gen {
        yield f"data: {json.dumps({'type': 'chunk', 'content': chunk})}\n\n";
    }
}
```

Each chunk is formatted as an SSE `data:` line. The client parses these with the Fetch Streams API.

### Chat Node

```jac
"""Stateless chat node - holds the LLM method only."""
node Chat {
    def respond(message: str) -> str by llm(method="Reason", stream=True);
    can reply with interact entry;
}

sem Chat.respond = "General-purpose conversational agent for answering questions and handling interactions.";
```

**`def respond(...) by llm()`** - no function body. The LLM generates the return value from the function name, parameter names, types, and the `sem` annotation.

**`method="Reason"`** - byLLM reasoning method with an internal scratchpad before answering.

**`stream=True`** - returns a chunk generator instead of a complete string.

**`sem`** - sets the LLM system prompt / persona.

**`can reply with interact entry`** - this ability fires when the `interact` walker enters the node.

### `interact` Walker

```jac
walker :pub interact {
    has message: str;

    can start with Root entry {
        visit here ++> Chat();
    }
}
```

**`walker :pub`** - `:pub` exposes this as a public HTTP POST endpoint at `/walker/interact`.

**`visit here ++> Chat()`** - creates a fresh `Chat` node, connects it to root, and moves the walker to it in one expression.

### Reply Implementation (`server.impl/chat.impl.jac`)

Ability bodies live in a separate `server.impl/` directory, keeping node/walker *declarations* in `server.jac` clean and moving *logic* into dedicated impl files.

```jac
"""Ability implementation for the Chat node."""

impl Chat.reply {
    report stream_chunks(self.respond(visitor.message));
}
```

**`impl`** - provides the body for an ability declared elsewhere. The Jac runtime automatically loads all `.impl.jac` files alongside `server.jac`.

**`visitor`** - the walker currently visiting this node. `visitor.message` is the string the client sent.

**`report generator`** - Jac streams each yielded value as an SSE chunk to the caller.

---

## Frontend

### Entry Point (`main.jac`)

`main.jac` imports the backend nodes and walkers, then wires the React frontend:

```jac
import from services.server { Chat, interact }

cl {
    import from .frontend { app as ClientApp }

    def:pub app() -> JsxElement {
        return <ClientApp />;
    }
}
```

**`cl { ... }`** - a client block embedded in a server file. Code inside runs in the browser.

### Router (`frontend.cl.jac`)

```jac
import from "@jac/runtime" { Router, Routes, Route }
import from .pages.ChatPage { ChatPage }

def:pub app() -> JsxElement {
    return <Router>
        <Routes>
            <Route path="/" element={<ChatPage />} />
        </Routes>
    </Router>;
}
```

Step 1 has a single route - just the chat page, no auth.

### ChatPage (`pages/ChatPage.cl.jac`)

The entire chat UI lives in one component. The two key pieces:

**State and streaming:**

```jac
def:pub ChatPage() -> JsxElement {
    has messages: list = [];
    has isLoading: bool = False;
    ...
    async def handleSend(content: str) -> None {
        # 1. Add user message immediately
        messages = lambda prev: any -> any {
            return prev.concat([{"id": ..., "content": content, "isUser": True}]);
        };
        isLoading = True;

        # 2. Reserve a bot slot (starts empty - "thinking...")
        botId = "bot_" + String(Date.now());
        messages = lambda prev: any -> any {
            return prev.concat([{"id": botId, "content": "", "isUser": False}]);
        };

        # 3. POST to backend and read SSE stream
        response = await fetch("/walker/interact", {
            "method": "POST",
            "headers": {"Content-Type": "application/json"},
            "body": JSON.stringify({"message": content}),
            "signal": abortRef.current.signal
        });

        reader = response.body.getReader();
        ...
        # 4. Parse SSE lines and append each chunk to the bot message
        for part in parts {
            if part.startsWith("data:") {
                data = JSON.parse(part.slice(5).trim());
                if data.type == "chunk" { appendChunk(data.content); }
            }
        }
    }
}
```

**`has messages: list = []`** - reactive state; assigning to `messages` re-renders the component.

The bot message is pre-created with empty content. As chunks arrive, `appendChunk` updates it in-place, making the response appear to stream live.

### ChatMessage Component (`components/ChatMessage.cl.jac`)

```jac
def:pub ChatMessage(message: str, isUser: bool) -> JsxElement {
    if isUser {
        # Right-aligned bubble
        return <div style={{"display": "flex", "justifyContent": "flex-end", ...}}>
            <div style={{"background": "rgba(255,255,255,0.08)", "borderRadius": "18px", ...}}>
                {message}
            </div>
        </div>;
    }
    # Left-aligned bot text - shows "thinking..." while message is empty
    return <div style={{"color": "#d1d5db", ...}}>
        {(message if message else <span style={{"fontStyle": "italic"}}>thinking...</span>)}
    </div>;
}
```

Plain text only in Step 1 - Markdown rendering is added in Step 2.

### ChatInput Component (`components/ChatInput.cl.jac`)

```jac
def:pub ChatInput(
    onSendMessage: any,
    isLoading: bool = False,
    onStop: any = None,
    placeholder: str = "Type a message..."
) -> JsxElement {
    has inputValue: str = "";
    textareaRef = useRef(None);

    # Auto-resize up to 160 px
    useEffect(lambda -> None {
        if textareaRef.current {
            textareaRef.current.style.height = "auto";
            h = textareaRef.current.scrollHeight;
            textareaRef.current.style.height = String(Math.min(h, 160)) + "px";
        }
    }, [inputValue]);
    ...
}
```

- Enter submits; Shift+Enter adds a newline
- While `isLoading`, the button shows "Stop" (red) and triggers `onStop` to abort the fetch via `AbortController`

---

## Run It

??? note "Complete `services/server.jac`"

    ```jac
    """Step 1: Minimal chat backend."""

    import json;
    import os;
    import tomllib;
    import from byllm.lib { Model }
    import from dotenv { load_dotenv }

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
    glob llm = Model(model_name=_cfg.get("llm_model", "gpt-4.1-mini"));

    def stream_chunks(gen: any) -> any {
        for chunk in gen {
            yield f"data: {json.dumps({'type': 'chunk', 'content': chunk})}\n\n";
        }
    }

    """Stateless chat node - holds the LLM method only."""
    node Chat {
        def respond(message: str) -> str by llm(method="Reason", stream=True);
        can reply with interact entry;
    }

    sem Chat.respond = "General-purpose conversational agent for answering questions and handling interactions.";

    """Accept a user message and stream the LLM response back."""
    walker :pub interact {
        has message: str;

        can start with Root entry {
            visit here ++> Chat();
        }
    }
    ```

??? note "Complete `services/server.impl/chat.impl.jac`"

    ```jac
    """Ability implementation for the Chat node."""

    impl Chat.reply {
        report stream_chunks(self.respond(visitor.message));
    }
    ```

??? note "Complete `main.jac`"

    ```jac
    """Step 1: Simple chat - backend entry point."""

    import from services.server { Chat, interact }

    cl {
        import from .frontend { app as ClientApp }

        def:pub app() -> JsxElement {
            return <ClientApp />;
        }
    }
    ```

??? note "Complete `frontend.cl.jac`"

    ```jac
    """Step 1: Simple chat - frontend entry point. Single route: / → ChatPage."""

    import from "@jac/runtime" { Router, Routes, Route }
    import from .pages.ChatPage { ChatPage }

    def:pub app() -> JsxElement {
        return <Router>
            <Routes>
                <Route path="/" element={<ChatPage />} />
            </Routes>
        </Router>;
    }
    ```

??? note "Complete `pages/ChatPage.cl.jac`"

    ```jac
    """Step 1: ChatPage - the entire chat UI in one component."""

    import from react { useRef, useEffect }
    import from ..components.ChatMessage { ChatMessage }
    import from ..components.ChatInput { ChatInput }

    def:pub ChatPage() -> JsxElement {
        has messages: list = [];
        has isLoading: bool = False;

        messagesEndRef = useRef(None);
        abortRef = useRef(None);

        useEffect(lambda -> None {
            if messagesEndRef.current {
                messagesEndRef.current.scrollIntoView({"behavior": "smooth"});
            }
        }, [messages]);

        async def handleSend(content: str) -> None {
            if not content.trim() or isLoading { return; }

            messages = lambda prev: any -> any {
                return prev.concat([{
                    "id": "user_" + String(Date.now()),
                    "content": content,
                    "isUser": True
                }]);
            };

            isLoading = True;

            botId = "bot_" + String(Date.now());
            messages = lambda prev: any -> any {
                return prev.concat([{"id": botId, "content": "", "isUser": False}]);
            };

            def appendChunk(piece: str) -> None {
                messages = lambda prev: any -> any {
                    return prev.map(lambda m: any -> any {
                        if m.id == botId {
                            return {"id": m.id, "content": m.content + piece, "isUser": False};
                        }
                        return m;
                    });
                };
            }

            try {
                abortRef.current = Reflect.construct(AbortController, []);
                response = await fetch("/walker/interact", {
                    "method": "POST",
                    "headers": {"Content-Type": "application/json"},
                    "body": JSON.stringify({"message": content}),
                    "signal": abortRef.current.signal
                });

                reader = response.body.getReader();
                decoder = Reflect.construct(TextDecoder, ["utf-8"]);
                buffer = "";
                doubleNewline = String.fromCharCode(10) + String.fromCharCode(10);

                while True {
                    res = await reader.read();
                    if res.done { break; }
                    buffer += decoder.decode(res.value, {"stream": True});
                    parts = buffer.split(doubleNewline);
                    buffer = parts.pop() or "";
                    for part in parts {
                        if part.startsWith("data:") {
                            try {
                                data = JSON.parse(part.slice(5).trim());
                                if data.type == "chunk" { appendChunk(data.content); }
                            } except Exception { }
                        }
                    }
                }
            } except Exception as e {
                console.error("Chat error:", e);
                appendChunk("[Error: could not get a response. Check your API key and try again.]");
            } finally {
                isLoading = False;
                abortRef.current = None;
            }
        }

        def handleStop() -> None {
            if abortRef.current { abortRef.current.abort(); }
            isLoading = False;
        }

        hasMessages = messages.length > 0;

        welcomeScreen = <div style={{
            "flex": "1", "display": "flex", "flexDirection": "column",
            "alignItems": "center", "justifyContent": "center",
            "gap": "8px", "color": "#9ca3af"
        }}>
            <p style={{"fontSize": "26px", "fontWeight": "600", "color": "#ffffff", "margin": "0"}}>
                How can I help you today?
            </p>
            <p style={{"fontSize": "14px", "margin": "0"}}>
                Type a message below to start chatting.
            </p>
        </div>;

        return <div style={{
            "height": "100vh", "display": "flex", "flexDirection": "column",
            "background": "#141414", "color": "#ffffff",
            "fontFamily": "system-ui, -apple-system, sans-serif"
        }}>
            <div style={{
                "padding": "14px 20px", "borderBottom": "1px solid #374151",
                "fontSize": "18px", "fontWeight": "600"
            }}>
                SimpleChat
            </div>

            <div style={{
                "flex": "1", "overflowY": "auto", "padding": "16px",
                "display": "flex", "flexDirection": "column"
            }}>
                {(welcomeScreen if not hasMessages else None)}
                {messages.map(lambda msg: any -> any {
                    return <ChatMessage key={msg.id} message={msg.content} isUser={msg.isUser} />;
                })}
                <div ref={messagesEndRef} />
            </div>

            <ChatInput onSendMessage={handleSend} isLoading={isLoading} onStop={handleStop} />
        </div>;
    }
    ```

??? note "Complete `components/ChatMessage.cl.jac`"

    ```jac
    """Step 1: ChatMessage - plain-text message bubble."""

    def:pub ChatMessage(message: str, isUser: bool) -> JsxElement {
        if isUser {
            return <div style={{"display": "flex", "justifyContent": "flex-end", "padding": "4px 0"}}>
                <div style={{
                    "background": "rgba(255,255,255,0.08)", "borderRadius": "18px",
                    "padding": "10px 16px", "maxWidth": "75%",
                    "fontSize": "14px", "lineHeight": "1.6",
                    "whiteSpace": "pre-wrap", "color": "#ffffff"
                }}>
                    {message}
                </div>
            </div>;
        }

        return <div style={{
            "padding": "4px 0", "fontSize": "14px",
            "lineHeight": "1.7", "color": "#d1d5db", "whiteSpace": "pre-wrap"
        }}>
            {(message if message else <span style={{"color": "#6b7280", "fontStyle": "italic"}}>thinking...</span>)}
        </div>;
    }
    ```

??? note "Complete `components/ChatInput.cl.jac`"

    ```jac
    """Step 1: ChatInput - plain textarea + Send/Stop button."""

    import from react { useRef, useEffect }

    def:pub ChatInput(
        onSendMessage: any,
        isLoading: bool = False,
        onStop: any = None,
        placeholder: str = "Type a message..."
    ) -> JsxElement {
        has inputValue: str = "";
        textareaRef = useRef(None);

        useEffect(lambda -> None {
            if textareaRef.current {
                textareaRef.current.style.height = "auto";
                h = textareaRef.current.scrollHeight;
                textareaRef.current.style.height = String(Math.min(h, 160)) + "px";
            }
        }, [inputValue]);

        def handleSubmit(e: any) -> None {
            e.preventDefault();
            if inputValue.trim() and not isLoading {
                onSendMessage(inputValue.trim());
                inputValue = "";
            }
        }

        def handleKeyDown(e: any) -> None {
            if e.key == "Enter" and not e.shiftKey {
                e.preventDefault();
                handleSubmit(e);
            }
        }

        buttonLabel = ("Stop" if isLoading else "Send");
        buttonBg = ("#ef4444" if isLoading else "#3b82f6");

        return <div style={{"padding": "12px 16px", "borderTop": "1px solid #374151"}}>
            <form onSubmit={handleSubmit} style={{
                "display": "flex", "gap": "8px",
                "maxWidth": "800px", "margin": "0 auto"
            }}>
                <textarea
                    ref={textareaRef}
                    value={inputValue}
                    onChange={lambda e: any -> None { inputValue = e.target.value; }}
                    onKeyDown={handleKeyDown}
                    placeholder={placeholder}
                    rows={1}
                    style={{
                        "flex": "1", "resize": "none",
                        "background": "#1f2937", "border": "1px solid #374151",
                        "borderRadius": "8px", "color": "#ffffff",
                        "padding": "10px 14px", "fontSize": "14px",
                        "lineHeight": "1.5", "outline": "none",
                        "minHeight": "44px", "maxHeight": "160px",
                        "fontFamily": "system-ui, -apple-system, sans-serif"
                    }}
                />
                <button
                    type={(("button" if isLoading else "submit"))}
                    onClick={(onStop if isLoading else None)}
                    style={{
                        "background": buttonBg, "color": "#ffffff",
                        "border": "none", "borderRadius": "8px",
                        "padding": "0 18px", "fontSize": "14px",
                        "fontWeight": "600", "cursor": "pointer", "minWidth": "70px"
                    }}
                >
                    {buttonLabel}
                </button>
            </form>
        </div>;
    }
    ```

??? note "Complete `jac.toml`"

    ```toml
    [project]
    name = "step-1-simple-chat"
    version = "1.0.0"
    description = "Tutorial Step 1: Simple chat - no auth, no sessions, one LLM call"
    entry-point = "main.jac"

    [dependencies]
    python-dotenv = ">=0.0.0"

    [dev-dependencies]
    watchdog = "~=6.0"

    [dependencies.npm]
    jac-client-node = "1.0.4"

    [dependencies.npm.dev]
    "@jac-client/dev-deps" = "1.0.0"

    [serve]
    base_route_app = "app"

    # ── App configuration ──────────────────────────────────────────────────────────
    # Edit these values to customise the chatbot without touching source code.
    # OPENAI_API_KEY must still be provided via a .env file or environment variable.
    [config]
    chatbot_name = "SimpleChat"
    llm_model    = "gpt-4.1-mini"

    [plugins.client]
    ```

```bash
cd step-1-simple-chat
cp .env.example .env   # add your OPENAI_API_KEY
jac install            # install Python + npm dependencies
jac start              # start the server
```

Open [http://localhost:8000](http://localhost:8000). Type a message - the response streams in token by token.

!!! tip "Resetting the environment"
    `jac clean` removes data files (e.g. the persisted graph). `jac clean --all` removes compiled files and data too - run `jac install` again afterwards to reinstall dependencies.

!!! warning "Common issue"
    If you see "Address already in use", use `--port 3001` to pick a different port.

---

## What You Learned

**Backend:**

- **`node`** - a graph vertex that holds data and abilities
- **`def respond(...) by llm()`** - LLM-generated function; no body needed
- **`method="Reason"`** - reasoning scratchpad before producing the answer
- **`stream=True`** - returns a chunk generator instead of a complete string
- **`sem`** - semantic annotation used as the LLM system prompt
- **`walker :pub`** - public walker exposed as an HTTP POST endpoint
- **`can X with Y entry`** - ability that fires when walker `Y` enters this node
- **`visit here ++> Node()`** - create a node, connect it, move the walker
- **`impl Node.ability`** - provide an ability body outside the node definition, in a separate `server.impl/*.impl.jac` file
- **`visitor`** - the walker currently visiting a node
- **`report generator`** - stream yielded values as SSE to the client

**Frontend:**

- **`cl { ... }`** - client block in a server file; code runs in the browser
- **`has field = value`** - reactive state; assignment triggers re-render
- **`fetch + ReadableStream`** - how the client reads the SSE stream chunk by chunk
- **`AbortController`** - cancels the in-flight request when Stop is pressed
- **`appendChunk`** - updates the bot message in-place as chunks arrive

---

## Next Step

The chatbot forgets everything between messages. In [Part 2](part2-persistent-sessions.md), you'll add a `Session` node that persists conversation history in the graph, add login/register pages, and give each user their own isolated conversation data.
