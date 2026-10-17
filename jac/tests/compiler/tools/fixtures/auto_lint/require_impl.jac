import math;

def scale(v: int, factor: int = 2) -> int {
    # moved with the body
    return v * factor;
}

async def fetch(key: str) -> str {
    return key;
}

def declared(x: int) -> int;

def overloaded(x: int) -> int {
    return x;
}

def overloaded(x: str) -> str {
    return x;
}

node Point {
    has x: int = 0,
        y: int = 0;

    def norm -> float {
        def square(v: int) -> int {
            return v * v;
        }
        return math.sqrt(square(self.x) + square(self.y));
    }

    def postinit {
        self.x = abs(self.x);
    }
}

walker Visitor {
    can on_point with Point entry {
        report here.x;
    }
}

def Badge(label: str) -> JsxElement {
    return <span>{label}</span>;
}

impl declared(x: int) -> int {
    return x + 1;
}

with entry {
    scale(Point(x=3, y=4).x);
}
