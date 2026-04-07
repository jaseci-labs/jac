cl import "./global.css";

cl def:pub app() -> JsxElement {
    has count: int = 0;

    return <div className="splash-root">
        <div className="splash-logos">
            <a href="https://vite.dev" target="_blank">
                <img
                    src="/static/assets/vite_logo.png"
                    className="splash-logo splash-logo-vite"
                    alt="Vite logo"
                />
            </a>
            <a href="https://jaseci.org" target="_blank">
                <img
                    src="/static/assets/jaseci_logo.png"
                    className="splash-logo splash-logo-jaseci"
                    alt="Jaseci logo"
                />
            </a>
        </div>

        <h1 className="splash-title">Vite + Jac</h1>

        <div className="splash-card">
            <button
                className="splash-btn"
                onClick={lambda -> None { count = count + 1; }}
            >
                {"count is " + (count.toString())}
            </button>
            <p className="splash-hint">
                Edit <code>main.jac</code> and  save to test HMR
            </p>
        </div>

        <p className="splash-footer">
            Click on the Vite and Jaseci logos to learn more
        </p>
    </div>;
}
