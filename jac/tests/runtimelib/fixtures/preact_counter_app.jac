"""Minimal Preact counter app for framework-backend E2E verification."""

cl def:pub app() -> JsxElement {
    has count: int = 0;

    return <div>
        <p data-testid="count">Count: {count}</p>
        <button data-testid="inc" onClick={lambda e: any { count = count + 1; }}>
            +
        </button>
    </div>;
}
