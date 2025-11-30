"""Client UI components module for testing cl imports."""

cl import from jac:client_runtime { createState, navigate, }

cl {
    # Shared state
    let [uiState, setUiState] = createState({"theme": "light"});

    # UI Component
    def Button(label: str) -> any {
        return <button
            onclick={handleClick}
        >
            {label}
        </button>;
    }

    def handleClick()  -> None {
        navigate("/clicked");
    }

    # Another component
    def Card(title: str) -> any {
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
