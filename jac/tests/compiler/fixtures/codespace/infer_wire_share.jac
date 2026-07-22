"""Markerless mixed module for boundary auto-share: a server node crossing to
the inferred client side gets wire codecs in the JS bundle, while an obj
pulled native by an extern seed stays out of it."""

import from fakelib { def fl_init(w: i32, h: i32) -> None;  def fl_tick -> f32;  }

node Todo {
    has text: str;
}

obj Particle {
    has x: float = 0.0;
}

def step -> float {
    p = Particle(x=1.0);
    return p.x + fl_tick();
}

def:pub add_todo(text: str) -> Todo {
    t = root ++> Todo(text=text);
    return t[0];
}

def:pub app -> JsxElement {
    has todos: list[Todo] = [];

    async can with entry {
        t = await add_todo("hi");
        todos = [t];
    }

    return <div>{for t in todos { <p>{t.text}</p> }}</div>;
}
