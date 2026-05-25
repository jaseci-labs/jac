"""First-run welcome banner for Little X."""

def:pub WelcomeBanner(onDismiss: Callable[[], None]) -> JsxElement {
    return
        <div className="lx-welcome-banner">
            <div className="lx-welcome-content">
                <div className="lx-welcome-title">Welcome to LITTLE-X</div>
                <div className="lx-welcome-tips">
                    <span className="lx-welcome-tip">
                        {"Post a thought to get started"}
                    </span>
                    <span className="lx-welcome-tip">
                        {"Use #hashtags to join trending topics"}
                    </span>
                    <span className="lx-welcome-tip">
                        {"Explore and follow people in Explore"}
                    </span>
                </div>
            </div>
            <button className="lx-welcome-dismiss" onClick={lambda { onDismiss(); }}>
                {"Got it"}
            </button>
        </div>;
}
