glob FRAMES: list[dict[str, str]] = [
    {"name": "Preact", "src": "/demos/preact/", "note": "re-renders, on its own runtime"},
    {"name": "Solid", "src": "/demos/solid/", "note": "fine-grained: the component runs once"},
];

def:pub UiLibraries -> JsxElement;
