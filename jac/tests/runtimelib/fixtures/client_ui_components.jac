"""Client UI components module for testing cl imports."""

cl import from "@jac/runtime" { createState, navigate, }

cl {
    # Shared state
    glob _uiState = createState({"theme": "light"});
    glob uiState = _uiState[0];
    glob setUiState = _uiState[1];

    # UI Component
    def: pub Button(label: str) -> JsxElement {
        return <button
            onclick={handleClick}
        >
            {label}
        </button>;
    }

    def: pub handleClick()  -> None {
        navigate("/clicked");
    }

    # Another component
    def: pub Card(title: str) -> JsxElement {
        return <div class="card">
            <h2>
                {title}
            </h2>
            <p>
                Current theme: {uiState["theme"]}
            </p>
        </div>;
    }
}
