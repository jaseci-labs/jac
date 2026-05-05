"""Todo item component for displaying a single todo."""

def:pub TodoItem(
    todo: dict[str, Any],
    onToggle: Callable[([str], None)],
    onDelete: Callable[([str], None)]
) -> JsxElement {
    return
        <div
            style={{
                "display": "flex",
                "alignItems": "center",
                "gap": "0.75rem",
                "padding": "1rem",
                "marginBottom": "0.5rem",
                "backgroundColor": "#f8f9fa",
                "borderRadius": "8px",
                "border": "1px solid #e9ecef"
            }}
        >
            <input
                type="checkbox"
                checked={todo["completed"]}
                onChange={lambda _e: ChangeEvent { onToggle(todo["id"]); }}
                style={{"width": "20px", "height": "20px", "cursor": "pointer"}}
            />
            <span
                style={{
                    "flex": "1",
                    "textDecoration": ("line-through" if todo["completed"] else "none"),
                    "color": ("#888" if todo["completed"] else "#333")
                }}
            >
                {todo["title"]}
            </span>
            <button
                onClick={lambda _e: MouseEvent { onDelete(todo["id"]); }}
                style={{
                    "padding": "0.5rem",
                    "backgroundColor": "transparent",
                    "color": "#dc3545",
                    "border": "none",
                    "cursor": "pointer",
                    "fontSize": "1.2rem"
                }}
            >
                x
            </button>
        </div>;
}
