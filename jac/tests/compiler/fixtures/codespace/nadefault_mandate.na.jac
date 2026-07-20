obj Widget {
    has size: int = 0;

    def render -> str {
        return "ok";
    }
}

def build -> str {
    w = new(Widget, 5);
    return w.render();
}

with entry {
    print("built:", build());
}
