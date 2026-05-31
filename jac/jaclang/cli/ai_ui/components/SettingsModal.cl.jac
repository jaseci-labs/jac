"""Settings modal: pick the model and supply the API key / endpoint live.

A fully controlled dialog (the parent owns every field value and the editable
state, mirroring the composer's `draft` pattern), so opening it just fills the
fields from the server's current settings. Applying rebuilds the model in the
running session -- nothing is written to disk. Auto-opened by the app when the
active model needs an API key it does not have.
"""

def:pub SettingsModal(
    model: str,
    apiKeySet: bool,
    keyDraft: str,
    baseUrl: str,
    temp: str,
    nctx: str,
    presets: list[str],
    modelSource: str,
    needsKey: bool,
    keyEnv: str,
    error: str,
    busy: bool,
    onModel: Callable[[str], None],
    onKey: Callable[[str], None],
    onBaseUrl: Callable[[str], None],
    onTemp: Callable[[str], None],
    onNctx: Callable[[str], None],
    onApply: Callable[[], None],
    onClose: Callable[[], None]
) -> JsxElement {
    keyLabel = ("API key (" + keyEnv + ")") if keyEnv else "API key";
    keyPlaceholder = "•••••••• set — leave blank to keep" if apiKeySet else "sk-…";
    return
        <div className="modal-overlay" onClick={lambda { onClose(); }}>
            <div className="modal" onClick={lambda e: any { e.stopPropagation(); }}>
                <div className="modal-head">
                    <span>Settings</span>
                    <span className="spacer"/>
                    <button className="modal-x" onClick={lambda { onClose(); }}>
                        ×
                    </button>
                </div>
                <div className="modal-body">
                    {<div className="modal-note">
                        This model needs an API key{(" (" + keyEnv + ")")
                            if keyEnv
                            else ""} before it can run. Add one below.
                    </div>
                        if needsKey
                        else <span/>}
                    <div className="field">
                        <label>Model</label>
                        <input
                            className="input"
                            value={model}
                            placeholder="anthropic/claude-opus-4-7"
                            onChange={lambda e: ChangeEvent { onModel(
                                e.target.value
                            ); }}
                        />
                        <div className="preset-row">
                            {[
                                <button
                                    className="preset"
                                    key={p}
                                    onClick={lambda { onModel(p); }}
                                >
                                    {p}
                                </button> for p in presets
                            ]}
                        </div>
                        {<div className="field-hint">source: {modelSource}</div>
                            if modelSource
                            else <span/>}
                    </div>
                    <div className="field">
                        <label>{keyLabel}</label>
                        <input
                            className="input"
                            type="password"
                            value={keyDraft}
                            placeholder={keyPlaceholder}
                            onChange={lambda e: ChangeEvent { onKey(e.target.value); }}
                        />
                    </div>
                    <div className="field">
                        <label>Base URL (optional)</label>
                        <input
                            className="input"
                            value={baseUrl}
                            placeholder="https://… (custom endpoint or proxy)"
                            onChange={lambda e: ChangeEvent { onBaseUrl(
                                e.target.value
                            ); }}
                        />
                    </div>
                    <div className="field-row">
                        <div className="field">
                            <label>Temperature</label>
                            <input
                                className="input"
                                value={temp}
                                placeholder="default"
                                onChange={lambda e: ChangeEvent { onTemp(
                                    e.target.value
                                ); }}
                            />
                        </div>
                        <div className="field">
                            <label>Context (n_ctx)</label>
                            <input
                                className="input"
                                value={nctx}
                                placeholder="0 = model default"
                                onChange={lambda e: ChangeEvent { onNctx(
                                    e.target.value
                                ); }}
                            />
                        </div>
                    </div>
                    {<div className="modal-err">{error}</div> if error else <span/>}
                </div>
                <div className="modal-foot">
                    <button className="btn ghost" onClick={lambda { onClose(); }}>
                        Cancel
                    </button>
                    <button
                        className="btn"
                        disabled={busy}
                        onClick={lambda { onApply(); }}
                    >
                        {"Applying…" if busy else "Apply"}
                    </button>
                </div>
            </div>
        </div>;
}
