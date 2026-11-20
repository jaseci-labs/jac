import from "@jac/runtime" { Link }

glob _COLS: list[dict[str, any]] = [
    {
        "title": "Language",
        "links": [
            {"label": "Documentation", "href": "/docs/latest"},
            {"label": "Playground", "href": "https://playground.jaseci.org"},
            {"label": "Install guide", "href": "/docs/latest/quick-guide/install"},
        ],
    },
    {
        "title": "Community",
        "links": [
            {"label": "GitHub", "href": "https://github.com/jaseci-labs/jac"},
            {"label": "Discord", "href": "https://discord.gg/6j3QNdtcN6"},
            {"label": "This is Jac (demo)", "href": "https://github.com/jaseci-labs/this_is_jac"},
        ],
    },
    {
        "title": "Research",
        "links": [
            {"label": "Object-Spatial Programming", "href": "https://arxiv.org/abs/2503.15812"},
            {"label": "Meaning-Typed Programming", "href": "https://arxiv.org/abs/2405.08965"},
            {"label": "The ninja book", "href": "https://doi.org/10.5281/zenodo.21464040"},
        ],
    },
];

def:pub Footer -> JsxElement;
