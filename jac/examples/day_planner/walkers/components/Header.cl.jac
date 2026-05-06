"""App header with title, subtitle, and sign-out button."""

def:pub Header(onLogout: Any) -> JsxElement {
    return
        <div class="header">
            <div>
                <h1>AI Day Planner</h1>
                <p class="subtitle">Task management with AI-powered meal planning</p>
            </div>
            <button class="btn-signout" onClick={onLogout}>Sign Out</button>
        </div>;
}
