"""{{name}} - Client-Side UI."""

import from .components.MessageCard { MessageCard }

sv import from endpoints { Message, PostMessage, ListMessages }

def:pub app -> JsxElement {
    has messages: list[Message] = [],
        author: str = "",
        text: str = "";

    # Load existing messages once, when the component first mounts.
    can with entry {
        loadMessages();
    }

    async def loadMessages -> None;
    async def postMessage(e: FormEvent) -> None;

    return
        <div
            style={{
                "maxWidth": "600px",
                "margin": "2rem auto",
                "padding": "0 1rem",
                "fontFamily": "system-ui, -apple-system, sans-serif",
                "color": "#1a1a2e"
            }}
        >
            <h1>{{name}}</h1>
            <p style={{"color": "#666"}}>A tiny full-stack guestbook in Jac.</p>
            <form
                onSubmit={postMessage}
                style={{"display": "flex", "gap": "0.5rem", "marginBottom": "1.5rem"}}
            >
                <input
                    type="text"
                    value={author}
                    onChange={lambda (e: ChangeEvent) { author = e.target.value; }}
                    placeholder="Name"
                    style={{
                        "flex": "1",
                        "padding": "0.6rem",
                        "border": "1px solid #ddd",
                        "borderRadius": "6px"
                    }}
                />
                <input
                    type="text"
                    value={text}
                    onChange={lambda (e: ChangeEvent) { text = e.target.value; }}
                    placeholder="Say something..."
                    style={{
                        "flex": "2",
                        "padding": "0.6rem",
                        "border": "1px solid #ddd",
                        "borderRadius": "6px"
                    }}
                />
                <button
                    type="submit"
                    style={{
                        "padding": "0.6rem 1.2rem",
                        "backgroundColor": "#4CAF50",
                        "color": "white",
                        "border": "none",
                        "borderRadius": "6px",
                        "cursor": "pointer"
                    }}
                >
                    Post
                </button>
            </form>
            {[
                <MessageCard key={idx} author={msg.author} text={msg.text}/>
                for (idx, msg) in enumerate(messages)
            ]}
        </div>;
}
