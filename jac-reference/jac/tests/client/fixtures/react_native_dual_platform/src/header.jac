"""Web variant of the platform header (uses className + CSS)."""


def:pub PlatformHeader(props: any) -> JsxElement {
    <div className="platform-header">
        <h1 className="platform-title">{props.title}</h1>
        <span className="platform-badge">web</span>
    </div>
}
