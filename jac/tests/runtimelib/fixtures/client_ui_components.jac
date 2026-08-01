"""Client UI components module for testing cl imports."""

import from "@jac/runtime" { createState, navigate, }


# Shared state
glob _uiState = createState({"theme": "light"});
glob uiState = _uiState[0];
glob setUiState = _uiState[1];

# UI Component
def:pub Button(label: str) -> JsxElement {
    <button onclick={handleClick}>{label}</button>
}

def:pub handleClick {
    navigate("/clicked");
}

# Another component
def:pub Card(title: str) -> JsxElement {
    <div class="card">
        <h2>{title}</h2>
        <p>Current theme: {uiState["theme"]}</p>
    </div>
}
