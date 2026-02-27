cl import from react { useEffect, useRef }
cl import from ...components.Card.tsx { Card }
sv import from ...main { ping_server, get_server_message, create_todo }

cl {
    def:pub page -> JsxElement {
        has count: int = 0,
            pingResult: str = "",
            serverMessage: str = "",
            lastTodoMessage: str = "";

        can with count entry {
            print("Home count changed: ", count);
        }

        async def handlePing -> None {
            result = root spawn ping_server();
            if result.reports and len(result.reports) > 0 {
                pingResult = result.reports[0][0];
            }
        }

        async def loadServerMessage -> None {
            result = root spawn get_server_message();
            if result.reports and len(result.reports) > 0 {
                serverMessage = result.reports[0][0];
            }
        }

        async def handleCreateSampleTodo -> None {
            result = root spawn create_todo(text="Sample todo from all-in-one app");
            if result.reports and len(result.reports) > 0 {
                todo = result.reports[0][0];
                lastTodoMessage = "Created Todo: " + todo.text;
                print("Created Todo node:", todo);
            }
        }

        async can with entry {
            await loadServerMessage();
        }

        workerRef = useRef(None);
        has message: str = "";

        useEffect(
            lambda -> None { workerRef.current = Reflect.construct(
                Worker, ["/workers/worker.js"]
            );workerRef.current.onmessage = lambda event: any  -> None { print(
                "Message received from worker:", event.data
            );message = event.data;};return (
                lambda -> None { workerRef.current.terminate();}
            ); },
            []
        );
        handleClick = lambda -> None { workerRef.current.postMessage("");};

        return
            <div
                style={{
                    "padding": "2rem",
                    "fontFamily": "system-ui, -apple-system, sans-serif"
                }}
            >
                <h1>
                    🍔 Router + Styling + Assets Demo
                </h1>
                <p>
                    This home page combines
                    {" "}
                    <strong>
                        React Router,
                    </strong>
                    {" "}
                    <strong>
                        pure CSS styling,
                    </strong>
                    {" "}
                    <strong>
                        staticassets
                    </strong>
                    {" "}
                    and
                    {" "}
                    <strong>
                        nested folder imports
                    </strong>
                </p>
                <div className="container">
                    <h2
                        style={{
                            "color": "white",
                            "textShadow": "2px 2px 4px rgba(0,0,0,0.6)"
                        }}
                    >
                        CSS Background Image
                    </h2>
                    <p
                        style={{
                            "color": "white",
                            "maxWidth": "480px",
                            "textShadow": "1px 1px 3px rgba(0,0,0,0.7)"
                        }}
                    >
                        This section uses the burger image as a background via CSS, just like the
                        {" "}
                        <code>
                            asset-serving/css-with-image
                        </code>
                        {" "}
                        example.
                    </p>
                </div>
                <Card
                    title="TypeScript Card Component"
                    description="This card is built with TypeScript and demonstrates type-safe component usage in Jac"
                    variant="highlighted"
                >
                    <p style={{"margin": "0.5rem 0", "color": "#374151"}}>
                        This is a TypeScript component imported and used in Jac code!
                    </p>
                </Card>
                <div className="card">
                    <h3>
                        Direct &lt;img&gt; asset
                    </h3>
                    <img
                        src="/static/assets/burger.png"
                        alt="Burger asset served by Jac"
                        className="burgerImage"
                    />
                    <p style={{"marginTop": "0.75rem", "color": "#555"}}>
                        This image is served from the project
                        {" "}
                        <code>
                            assets/
                        </code>
                        {" "}
                        folder using the
                        {" "}
                        <code>
                            /static/assets/
                        </code>
                        {" "}
                        path.
                    </p>
                </div>
                <div style={{"marginTop": "2rem"}}>
                    <h3>
                        Counter with pure CSS classes
                    </h3>
                    <p>
                        You've clicked the burger
                        {" "}
                        <strong>
                            {count}
                        </strong>
                        {" "}
                        times.
                    </p>
                    <button
                        onClick={lambda e: any  -> None { count = count + 1;}}
                        style={{
                            "padding": "0.6rem 1.4rem",
                            "fontSize": "1rem",
                            "backgroundColor": "#ff6b35",
                            "color": "white",
                            "border": "none",
                            "borderRadius": "6px",
                            "cursor": "pointer",
                            "boxShadow": "0 2px 4px rgba(0,0,0,0.2)"
                        }}
                    >
                        Click the Burger! 🍔
                    </button>
                </div>
                <div style={{"marginTop": "2rem"}}>
                    <h3>
                        Backend Walkers
                    </h3>
                    <p>
                        Basic example walkers:
                        {" "}
                        <code>
                            ping_server
                        </code>
                        {" "}
                        and
                        {" "}
                        <code>
                            get_server_message
                        </code>
                    </p>
                    <button
                        onClick={lambda e: any  -> None { handlePing();}}
                        style={{
                            "padding": "0.5rem 1.2rem",
                            "marginRight": "0.75rem",
                            "backgroundColor": "#3b82f6",
                            "color": "white",
                            "border": "none",
                            "borderRadius": "6px",
                            "cursor": "pointer"
                        }}
                    >
                        Ping Backend
                    </button>
                    <button
                        onClick={lambda e: any  -> None { handleCreateSampleTodo();}}
                        style={{
                            "padding": "0.5rem 1.2rem",
                            "backgroundColor": "#10b981",
                            "color": "white",
                            "border": "none",
                            "borderRadius": "6px",
                            "cursor": "pointer"
                        }}
                    >
                        Create Sample Todo
                    </button>
                    {pingResult
                    and (
                        <span style={{"marginLeft": "0.5rem", "color": "#374151"}}>
                            Result:
                            {" "}
                            <code>
                                {pingResult}
                            </code>
                        </span>
                    )}
                    {serverMessage
                    and (
                        <p style={{"marginTop": "0.75rem", "color": "#374151"}}>
                            Message:
                            {" "}
                            <code>
                                {serverMessage}
                            </code>
                        </p>
                    )}
                    {lastTodoMessage
                    and (
                        <p style={{"marginTop": "0.5rem", "color": "#111827"}}>
                            {lastTodoMessage}
                        </p>
                    )}
                </div>
                <div style={{"marginTop": "2rem"}}>
                    <h3>
                        Web Worker
                    </h3>
                    <p>
                        This demonstrates how to communicate with a
                        {" "}
                        <strong>
                            Python backend worker
                        </strong>
                        {" "}
                        using Web Workers for asynchronous processing.
                    </p>
                    <p
                        style={{
                            "fontSize": "0.9rem",
                            "color": "#666",
                            "marginTop": "0.5rem"
                        }}
                    >
                        File:
                        {" "}
                        <code>
                            worker.py
                        </code>
                        {" "}
                        — Runs in a separate thread to avoid blocking the UI.
                    </p>
                    <button
                        onClick={lambda -> None { handleClick();}}
                        style={{
                            "padding": "0.5rem 1.2rem",
                            "marginRight": "0.75rem",
                            "backgroundColor": "#d73bf6ff",
                            "color": "white",
                            "border": "none",
                            "borderRadius": "6px",
                            "cursor": "pointer"
                        }}
                    >
                        Call Python Worker
                    </button>
                    {message
                    && (
                        <p style={{marginTop: "1rem", fontWeight: "bold"}}>
                            {message}
                        </p>
                    )}
                </div>
            </div>;
    }
}
